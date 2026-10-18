const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const crypto = require("crypto");
const { getAuth } = require("firebase-admin/auth");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage, getDownloadURL } = require("firebase-admin/storage");

setGlobalOptions({ maxInstances: 10 });

// Set with: firebase functions:secrets:set OPENAI_API_KEY
// Never hardcoded here, and never sent to the client — the app only ever
// calls extractRcCardFields below, which holds the key server-side.
const openAiApiKey = defineSecret("OPENAI_API_KEY");

// Local SMS gateway for phone OTPs (replaces Firebase's own SMS, which is
// unreliable to Pakistani carriers). Key: firebase functions:secrets:set SMS_API_KEY
// URL/sender: set in functions/.env (see .env.example).
const smsApiKey = defineSecret("SMS_API_KEY");
const smsApiUrl = defineString("SMS_API_URL");
const smsSenderId = defineString("SMS_SENDER_ID");

// The one number that gets the admin side. Changing it shuts the old admin
// out on their next request (see claimAdminRole / isAdminRequest).
const adminPhone = defineString("ADMIN_PHONE", { default: "+923079618674" });

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/** { uid, phone } of the account that last claimed the admin role. */
const ADMIN_CONFIG = db.collection("config").doc("admin");

const SAFETY_LOG_DAYS = 365;

/** A shared location, if the visitor allowed it: { lat, lng, accuracy }. */
function locationFrom(value) {
  const lat = Number(value?.lat);
  const lng = Number(value?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  const accuracy = Number(value?.accuracy);
  return { lat, lng, accuracy: Number.isFinite(accuracy) ? Math.round(accuracy) : null };
}

/**
 * The safety log: evidence for the police if a sticker is used to harass
 * or stalk an owner. Server-only (no client can read it) and kept for
 * SAFETY_LOG_DAYS via the `expireAt` TTL. Never fails the request it
 * records.
 */
async function logSafetyEvent(type, details, request) {
  try {
    const raw = request?.rawRequest;
    const forwarded = String(raw?.headers?.["x-forwarded-for"] || "").split(",")[0].trim();
    await db.collection("activityLog").add({
      type,
      ...details,
      ip: forwarded || raw?.ip || null,
      userAgent: raw?.headers?.["user-agent"] || null,
      uid: request?.auth?.uid || null,
      phone: request?.auth?.token?.phone_number || null,
      genuineApp: Boolean(request?.app),
      at: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(Date.now() + SAFETY_LOG_DAYS * 24 * 3600 * 1000),
    });
  } catch (e) {
    logger.error("logSafetyEvent failed", e);
  }
}

/**
 * FR-05/FR-06: pushes a notification to a vehicle's owner the moment a
 * scanner sends them a message from the public Scan Contact Page (FR-04).
 * Owner replies aren't pushed anywhere — the scanner is an anonymous web
 * visitor with no app install and no registered device.
 */
exports.onNewChatMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;
    const { conversationId } = event.params;

    // Web messages are logged by postScannerMessage (with IP); these are
    // the app's own, written straight to Firestore.
    if (!message.loggedByServer) {
      await logSafetyEvent("app_message", {
        conversationId,
        sender: message.sender || null,
        kind: message.kind || "text",
        text: message.text || null,
      }, null);
    }
    if (message.sender !== "scanner") return;

    const conversationSnap = await db.collection("conversations").doc(conversationId).get();
    const conversation = conversationSnap.data();
    if (!conversation) return;

    const ownerUid = conversation.ownerUid;
    if (!ownerUid) return;

    const ownerSnap = await db.collection("users").doc(ownerUid).get();
    const tokens = ownerSnap.data()?.fcmTokens;
    if (!Array.isArray(tokens) || tokens.length === 0) {
      logger.info(`No FCM tokens for owner ${ownerUid}; skipping push for ${conversationId}.`);
      return;
    }

    const scannerName = conversation.scannerName || "Anonymous";
    const plateNumber = conversation.plateNumber || "your vehicle";
    const text = typeof message.text === "string" ? message.text : "";
    const body =
      { voice: "🎤 Voice message", image: "📷 Photo", video: "🎥 Video" }[message.kind] || text;

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: `${scannerName} messaged you about ${plateNumber}`,
        body,
      },
      data: {
        type: "chat_message",
        conversationId,
        plateNumber,
        scannerName,
        colorName: conversation.colorName || "",
      },
      android: {
        priority: "high",
        notification: {
          // Must match MainActivity.MESSAGES_CHANNEL_ID and the manifest's
          // default_notification_channel_id. Naming it explicitly means the
          // push does not depend on the client's default being configured.
          channelId: "parktag_messages",
          sound: "default",
          // A text plus photos sent together replace one another instead
          // of stacking up as separate notifications.
          tag: conversationId,
        },
      },
      apns: { payload: { aps: { sound: "default", "thread-id": conversationId } } },
    });

    // A token stops being valid when the app is uninstalled or its
    // notification permission is revoked — drop those so this list doesn't
    // grow forever and keep retrying dead tokens.
    const staleTokens = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code;
      if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
        staleTokens.push(tokens[index]);
      }
    });
    if (staleTokens.length > 0) {
      await db.collection("users").doc(ownerUid).update({
        fcmTokens: FieldValue.arrayRemove(...staleTokens),
      });
    }

    logger.info(
      `Push for ${conversationId}: ${response.successCount} sent, ${response.failureCount} failed, ` +
        `${staleTokens.length} stale tokens removed.`,
    );
  },
);

/**
 * Sends one notification to every device of `uid`, dropping tokens that
 * are no longer registered. `data` values must be strings.
 */
async function pushToUser(uid, { title, body, data }) {
  if (!uid) return;
  const userSnap = await db.collection("users").doc(uid).get();
  const tokens = userSnap.data()?.fcmTokens;
  if (!Array.isArray(tokens) || tokens.length === 0) {
    logger.info(`pushToUser: no FCM tokens for ${uid}.`);
    return;
  }
  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { priority: "high", notification: { channelId: "parktag_messages", sound: "default" } },
    apns: { payload: { aps: { sound: "default" } } },
  });
  const staleTokens = tokens.filter((_, i) => {
    const code = response.responses[i].error?.code;
    return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token";
  });
  if (staleTokens.length > 0) {
    await db.collection("users").doc(uid).update({ fcmTokens: FieldValue.arrayRemove(...staleTokens) });
  }
  const failureCodes = response.responses.filter((r) => r.error).map((r) => r.error.code);
  logger.info(
    `pushToUser ${uid}: ${response.successCount} sent, ${staleTokens.length} stale removed` +
      (failureCodes.length ? `, failures: ${failureCodes.join(", ")}` : "") + ".",
  );
}

const ORDER_STATUS_TEXT = {
  review: ["Payment under review", "We're checking your payment."],
  confirmed: ["Confirmed", "Payment received — your order is confirmed."],
  printing: ["Printing", "Your QR stickers are being printed."],
  shipped: ["Shipped", "On the way to your address."],
  rejected: ["Payment rejected", "We could not confirm your payment."],
  cancelled: ["Cancelled", "This order was cancelled."],
};

const rupees = (n) => `Rs ${Number(n || 0).toLocaleString("en-US")}`;

/** A new sticker order alerts the admin; tapping it opens that order. */
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data?.data();
  if (!order) return;
  const admin = await ADMIN_CONFIG.get();
  const quantity = order.quantity || 0;
  await pushToUser(admin.data()?.uid, {
    title: `New order #${event.params.orderId}`,
    body: `${order.customerName} · ${quantity} sticker${quantity === 1 ? "" : "s"} · ${rupees(order.total)} via ${order.payment?.method || "payment"}`,
    data: { type: "order", orderId: event.params.orderId, audience: "admin" },
  });
});

/**
 * A status change (or a new note) tells the customer, using the admin's
 * note when there is one; tapping it opens their order.
 */
exports.onOrderUpdated = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === after.status && before.note === after.note) return;
  const [label, defaultText] = ORDER_STATUS_TEXT[after.status] || ["Updated", "Your order was updated."];
  await pushToUser(after.uid, {
    title: `Order #${event.params.orderId}: ${label}`,
    body: after.note || defaultText,
    data: { type: "order", orderId: event.params.orderId, audience: "customer" },
  });
});

/**
 * FR-09: called once, right after a resident signs in, with the anonymous
 * `scannerId` browser/device token pulled off a tapped scan link (see
 * DeepLinkService — the public Scan Contact Page's own URL, registered as
 * an App Link/Universal Link). Every conversation that identity took part
 * in (as a scanner messaging some other car's owner) gets stamped with
 * this resident's uid, so it surfaces in their app inbox's "Sent" section
 * from then on.
 *
 * Runs server-side (not a client Firestore write) because the scanner side
 * of a conversation has no auth token to satisfy a security rule with —
 * this callable is the trusted, auth-gated door for that one write.
 */
exports.linkScannerIdentity = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in to link a scanner identity.");
  }

  const scannerId = request.data?.scannerId;
  if (!scannerId || typeof scannerId !== "string") {
    throw new HttpsError("invalid-argument", "scannerId is required.");
  }

  const matches = await db.collection("conversations").where("scannerId", "==", scannerId).get();
  if (matches.empty) {
    return { linkedCount: 0 };
  }

  const batch = db.batch();
  let linkedCount = 0;
  matches.forEach((doc) => {
    // Idempotent: skip anything already linked (possibly to a different
    // uid, e.g. a shared/reset device — never overwrite an existing link).
    if (doc.data().scannerUid) return;
    batch.update(doc.ref, { scannerUid: uid });
    linkedCount += 1;
  });
  await batch.commit();

  logger.info(`Linked ${linkedCount} conversation(s) for scannerId ${scannerId} to uid ${uid}.`);
  return { linkedCount };
});

/**
 * The authoritative door for an *authenticated* app user (native QR scan
 * inside the app, or an App Link/Universal Link opened into a signed-in
 * app) to start a chat with a vehicle's owner.
 *
 * The client never supplies (or is trusted for) the owner's identity —
 * only a `vehicleId`. Everything else — who owns it, whether it still
 * exists, the plate/colour shown in the chat header — is resolved here
 * from Firestore via the Admin SDK, which bypasses client security rules
 * entirely. This is deliberately NOT a client-side Firestore write: a
 * signed-in scanner has no rule that would let them safely claim
 * `scannerUid` for themselves and validate the vehicle in one atomic step
 * from the client, so that responsibility lives here instead.
 *
 * Conversation id is deterministic — `{vehicleId}_{scannerUid}` — so two
 * scans (or a scan followed by a deep-link open) by the same signed-in
 * resident against the same vehicle always resolve to the same chat room
 * rather than creating a duplicate one. A Firestore transaction guards the
 * create-if-absent step against a race between two near-simultaneous calls.
 */
exports.resolveVehicleAndOpenChat = onCall(async (request) => {
  const scannerUid = request.auth?.uid;
  if (!scannerUid) {
    throw new HttpsError("unauthenticated", "Sign in to start a chat.");
  }

  const vehicleId = request.data?.vehicleId;
  if (!vehicleId || typeof vehicleId !== "string") {
    throw new HttpsError("invalid-argument", "vehicleId is required.");
  }

  const vehicleSnap = await db.collection("vehicles").doc(vehicleId).get();
  const vehicle = vehicleSnap.data();
  if (!vehicle) {
    throw new HttpsError("not-found", "This QR code doesn't match a ParkTag vehicle.");
  }

  const ownerUid = vehicle.ownerUid;
  if (!ownerUid || typeof ownerUid !== "string") {
    throw new HttpsError("failed-precondition", "This vehicle has no registered owner.");
  }
  if (ownerUid === scannerUid) {
    throw new HttpsError("failed-precondition", "This is your own vehicle — nothing to message.");
  }

  const scannerSnap = await db.collection("users").doc(scannerUid).get();
  const scannerName = scannerSnap.data()?.name || "A MoveMe resident";

  // FR-09: this scan may be a continuation of a conversation this person
  // already started anonymously from the public web page, before they had
  // an account. That conversation is keyed by the browser's random
  // scannerId, so when the deep link carries one, adopt that document
  // instead of creating a parallel empty chat under the new uid — that is
  // what "restores" the web conversation in the app, with its history.
  //
  // Only an UNCLAIMED conversation (or one already claimed by this same
  // uid) may be adopted. A scannerId belonging to someone else's browser
  // must never let this caller take over their chat.
  const anonymousScannerId = request.data?.scannerId;
  let conversationId = `${vehicleId}_${scannerUid}`;

  if (anonymousScannerId && typeof anonymousScannerId === "string") {
    const anonymousId = `${vehicleId}_${anonymousScannerId}`;
    const anonymousSnap = await db.collection("conversations").doc(anonymousId).get();
    const anonymous = anonymousSnap.data();
    const claimedBySomeoneElse =
      anonymous?.scannerUid && anonymous.scannerUid !== scannerUid;

    if (anonymous && anonymous.vehicleId === vehicleId && !claimedBySomeoneElse) {
      conversationId = anonymousId;
      logger.info(
        `Adopting anonymous conversation ${anonymousId} for uid ${scannerUid}.`,
      );
    }
  }

  const conversationRef = db.collection("conversations").doc(conversationId);

  // All reads before any writes — required for a Firestore transaction.
  const conversation = await db.runTransaction(async (tx) => {
    const existing = await tx.get(conversationRef);
    if (existing.exists) {
      const data = existing.data();
      // Claim an adopted anonymous conversation for this account, which is
      // what makes it appear under "Sent" and lets them reply as
      // themselves rather than as an anonymous web visitor.
      if (!data.scannerUid) {
        tx.update(conversationRef, { scannerUid, scannerName });
        return { ...data, scannerUid, scannerName };
      }
      return data;
    }

    const data = {
      vehicleId,
      ownerUid,
      ownerName: vehicle.ownerName || "A MoveMe resident",
      scannerId: scannerUid,
      scannerUid,
      scannerName,
      plateNumber: vehicle.plateNumber || "",
      colorName: vehicle.colorName || "",
      resolved: false,
      unreadForOwner: false,
      unreadForScanner: false,
      unreadCountForOwner: 0,
      unreadCountForScanner: 0,
      lastMessagePreview: "",
      lastMessageAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    };
    tx.set(conversationRef, data);
    return data;
  });

  logger.info(`resolveVehicleAndOpenChat: ${scannerUid} -> ${conversationId} (vehicle ${vehicleId}).`);
  await logSafetyEvent("in_app_scan", { vehicleId, conversationId, ownerUid }, request);

  return {
    conversationId,
    ownerName: conversation.ownerName || "A MoveMe resident",
    plateNumber: conversation.plateNumber || "",
    colorName: conversation.colorName || "",
    resolved: conversation.resolved || false,
  };
});

const RC_CARD_FIELD_KEYS = [
  "make",
  "makerName",
  "plateNumber",
  "color",
  "dateOfRegistration",
  "engineNumber",
  "chassisNumber",
  "address",
  "mrzLine1",
  "mrzLine2",
  "mrzLine3",
];

// Structured outputs: OpenAI guarantees the reply matches this schema, so
// there is no free-form JSON to mis-key. Strict mode requires every key to
// be listed in `required`; unreadable fields come back as "".
const RC_CARD_SCHEMA = {
  name: "rc_card_fields",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: RC_CARD_FIELD_KEYS,
    properties: Object.fromEntries(RC_CARD_FIELD_KEYS.map((k) => [k, { type: "string" }])),
  },
};

const RC_CARD_PROMPT =
  "You are reading a Punjab Excise & Taxation vehicle registration smart card " +
  "(front and/or back photo). Copy each value EXACTLY as printed directly " +
  "BELOW its label. Never infer, reorder or swap values between fields.\n\n" +
  "Field rules:\n" +
  '- "make": the value printed directly BELOW the label "Make" (exactly the ' +
  'word "Make", NOT "Maker Name"). It is the vehicle MODEL, usually with ' +
  'digits, e.g. "US 70", "CD 70", "CG 125", "YBR 125", "COROLLA GLI".\n' +
  '- "makerName": the value printed directly BELOW the label "Maker Name". It ' +
  'is the MANUFACTURER, e.g. "UNITED", "HONDA", "SUZUKI", "YAMAHA", ' +
  '"ROAD PRINCE", "TOYOTA".\n' +
  '  On this card "Make" sits directly ABOVE "Maker Name" on the back side. ' +
  "The two labels are different; do not merge or swap them.\n" +
  '- "plateNumber": the "Reg No" value, e.g. "ANJ 5947".\n' +
  '- "color": below "Colour".\n' +
  '- "dateOfRegistration": below "Date of Reg.", formatted like "14 Sep 2022".\n' +
  '- "engineNumber": below "Engine No".\n' +
  '- "chassisNumber": below "Chasis No" / "Chassis No".\n' +
  '- "address": below "Address".\n' +
  '- "mrzLine1", "mrzLine2", "mrzLine3": the three machine-readable lines at ' +
  'the bottom of the back side (full of "<" characters), copied character ' +
  "for character.\n\n" +
  'Use "" for any field that is not visible. Return JSON only.';

/**
 * FR-02.1: reads the RC card's front/back photos with OpenAI's GPT-4o
 * vision model and returns best-effort structured fields to pre-fill the
 * Add Vehicle form.
 *
 * Runs server-side, not from the client, for one reason: the OpenAI API
 * key. An API key bundled inside a mobile app can always be extracted from
 * the installed binary, so it is kept here instead, in Secret Manager
 * (`openAiApiKey`) — the client only ever sends photos and gets fields
 * back, never the key itself.
 */
exports.extractRcCardFields = onCall(
  { secrets: [openAiApiKey], timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to scan a card.");
    }

    const { frontImageBase64, backImageBase64 } = request.data || {};
    if (!frontImageBase64 && !backImageBase64) {
      throw new HttpsError("invalid-argument", "At least one image is required.");
    }

    const imageParts = [frontImageBase64, backImageBase64]
      .filter((b64) => typeof b64 === "string" && b64.length > 0)
      .map((b64) => ({
        type: "image_url",
        image_url: { url: `data:image/jpeg;base64,${b64}`, detail: "high" },
      }));

    let response;
    try {
      response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openAiApiKey.value()}`,
        },
        body: JSON.stringify({
          model: "gpt-4o",
          messages: [
            {
              role: "user",
              content: [{ type: "text", text: RC_CARD_PROMPT }, ...imageParts],
            },
          ],
          response_format: { type: "json_schema", json_schema: RC_CARD_SCHEMA },
          max_tokens: 700,
          temperature: 0,
        }),
      });
    } catch (err) {
      logger.error(`extractRcCardFields: OpenAI request failed: ${err}`);
      throw new HttpsError("unavailable", "Could not reach the scanning service. Please try again.");
    }

    if (!response.ok) {
      const errText = await response.text();
      logger.error(`extractRcCardFields: OpenAI returned ${response.status}: ${errText}`);
      throw new HttpsError("internal", "Could not read the card. Please try again.");
    }

    const payload = await response.json();
    const content = payload.choices?.[0]?.message?.content;
    if (!content) {
      logger.error("extractRcCardFields: no content in OpenAI response.");
      throw new HttpsError("internal", "Could not read the card. Please try again.");
    }

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (err) {
      logger.error(`extractRcCardFields: could not parse OpenAI JSON: ${content}`);
      throw new HttpsError("internal", "Could not read the card. Please try again.");
    }

    const result = {};
    for (const key of RC_CARD_FIELD_KEYS) {
      const value = parsed[key];
      result[key] = typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
    }

    logger.info(`extractRcCardFields: extracted fields for uid ${request.auth.uid}.`);
    return result;
  }
);


// ---------------------------------------------------------------------------
// Phone OTP via local SMS gateway + Firebase custom token sign-in.
// ---------------------------------------------------------------------------

const OTP_TTL_MS = 5 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const OTP_MAX_SENDS_PER_HOUR = 5;
const PK_MOBILE = /^\+923\d{9}$/;

const hashOtp = (phone, code) =>
  crypto.createHash("sha256").update(`${phone}:${code}`).digest("hex");

/** Fills SMS_API_URL's {key} {to} {sender} {message} placeholders. */
async function sendSms(phone, message) {
  const url = smsApiUrl
    .value()
    .replace("{key}", encodeURIComponent(smsApiKey.value()))
    .replace("{to}", encodeURIComponent(phone.replace("+", "")))
    .replace("{sender}", encodeURIComponent(smsSenderId.value()))
    .replace("{message}", encodeURIComponent(message));
  const response = await fetch(url);
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`SMS gateway returned ${response.status}: ${body}`);
  }
  logger.info(`sendSms: gateway response ${response.status}: ${body.slice(0, 200)}`);
}

/** Sends a 6-digit code to a +92 mobile number. No sign-in required. */
exports.requestPhoneOtp = onCall({ secrets: [smsApiKey] }, async (request) => {
  const phone = String(request.data?.phone || "");
  if (!PK_MOBILE.test(phone)) {
    throw new HttpsError("invalid-argument", "Enter a valid Pakistani mobile number.");
  }

  const ref = db.collection("phone_otps").doc(phone);
  const now = Date.now();
  const code = String(crypto.randomInt(0, 1000000)).padStart(6, "0");

  await db.runTransaction(async (tx) => {
    const prev = (await tx.get(ref)).data() || {};
    if (prev.lastSentAt && now - prev.lastSentAt < OTP_RESEND_COOLDOWN_MS) {
      throw new HttpsError("resource-exhausted", "Please wait a minute before requesting another code.");
    }
    const windowStart = prev.windowStart && now - prev.windowStart < 3600000 ? prev.windowStart : now;
    const sends = windowStart === prev.windowStart ? (prev.sends || 0) + 1 : 1;
    if (sends > OTP_MAX_SENDS_PER_HOUR) {
      throw new HttpsError("resource-exhausted", "Too many codes requested. Please try again in an hour.");
    }
    tx.set(ref, {
      hash: hashOtp(phone, code),
      expiresAt: now + OTP_TTL_MS,
      attempts: 0,
      lastSentAt: now,
      windowStart,
      sends,
    });
  });

  try {
    await sendSms(phone, `Your MoveMe verification code is ${code}. It expires in 5 minutes.`);
  } catch (err) {
    logger.error(`requestPhoneOtp: SMS send failed for ${phone}: ${err}`);
    await ref.update({ hash: FieldValue.delete() });
    throw new HttpsError("unavailable", "Could not send the code. Please try again.");
  }
  return { ok: true };
});

/** Checks the code and returns a Firebase custom token for that phone. */
exports.verifyPhoneOtp = onCall(async (request) => {
  const phone = String(request.data?.phone || "");
  const code = String(request.data?.code || "");
  if (!PK_MOBILE.test(phone) || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Invalid phone number or code.");
  }

  const ref = db.collection("phone_otps").doc(phone);
  const ok = await db.runTransaction(async (tx) => {
    const otp = (await tx.get(ref)).data();
    if (!otp?.hash || Date.now() > otp.expiresAt) {
      throw new HttpsError("deadline-exceeded", "This code has expired. Request a new one.");
    }
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new HttpsError("resource-exhausted", "Too many wrong attempts. Request a new code.");
    }
    const match = crypto.timingSafeEqual(Buffer.from(otp.hash), Buffer.from(hashOtp(phone, code)));
    tx.update(ref, match ? { hash: FieldValue.delete() } : { attempts: otp.attempts + 1 });
    return match;
  });
  if (!ok) throw new HttpsError("permission-denied", "The code is incorrect.");

  // Reuse the existing Firebase user for this number so their uid (and all
  // their Firestore data) stays the same; create one on first sign-up.
  const auth = getAuth();
  let uid;
  try {
    uid = (await auth.getUserByPhoneNumber(phone)).uid;
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    uid = (await auth.createUser({ phoneNumber: phone })).uid;
  }
  return { token: await auth.createCustomToken(uid) };
});

const SCANNER_ID = /^[A-Za-z0-9]{16,64}$/;

/** The public scan page records each visit (and location, if shared). */
exports.logActivity = onCall(async (request) => {
  const vehicleId = String(request.data?.vehicleId || "").slice(0, 40);
  const scannerId = String(request.data?.scannerId || "").slice(0, 64);
  if (!vehicleId) throw new HttpsError("invalid-argument", "Which vehicle?");
  await logSafetyEvent("scan_page_visit", {
    vehicleId,
    scannerId,
    location: locationFrom(request.data?.location),
  }, request);
  return { ok: true };
});
const ATTACHMENT_KINDS = ["voice", "image", "video"];
const PREVIEW = { voice: "🎤 Voice message", image: "📷 Photo", video: "🎥 Video" };

/**
 * The only way the public scan page sends a message. Looks the owner up
 * from the vehicle itself (never trusts the page), creates this visitor's
 * conversation on first contact, and appends the text and any attachments
 * — which must already be uploaded inside this conversation's own
 * `scanner/` Storage folder.
 */
exports.postScannerMessage = onCall({ timeoutSeconds: 60 }, async (request) => {
  const data = request.data || {};
  const vehicleId = String(data.vehicleId || "");
  const scannerId = String(data.scannerId || "");
  const scannerName = String(data.scannerName || "").trim().slice(0, 40);
  const text = String(data.text || "").trim().slice(0, 1000);
  const attachments = Array.isArray(data.attachments) ? data.attachments.slice(0, 5) : [];

  if (!/^[A-Za-z0-9]{10,40}$/.test(vehicleId) || !SCANNER_ID.test(scannerId)) {
    throw new HttpsError("invalid-argument", "This link is not valid.");
  }
  if (!text && attachments.length === 0) {
    throw new HttpsError("invalid-argument", "Write a message or add a photo, video or voice note.");
  }

  const vehicleSnap = await db.collection("vehicles").doc(vehicleId).get();
  const vehicle = vehicleSnap.data();
  if (!vehicle?.ownerUid) {
    throw new HttpsError("not-found", "The sticker may be damaged, or the vehicle was removed from MoveMe.");
  }

  const conversationId = `${vehicleId}_${scannerId}`;
  const folder = `conversations/${conversationId}/scanner/`;
  const bucket = getStorage().bucket();
  const media = [];
  for (const a of attachments) {
    const kind = String(a?.kind || "");
    const path = String(a?.path || "");
    if (!ATTACHMENT_KINDS.includes(kind) || !path.startsWith(folder) || path.includes("..")) {
      throw new HttpsError("invalid-argument", "An attachment is not part of this chat.");
    }
    const file = bucket.file(path);
    const [exists] = await file.exists();
    if (!exists) throw new HttpsError("invalid-argument", "An attachment did not finish uploading.");
    const url = await getDownloadURL(file);
    const seconds = Math.max(0, Math.min(120, Math.round(Number(a?.durationSeconds) || 0)));
    media.push({ kind, url, seconds });
  }

  const conversationRef = db.collection("conversations").doc(conversationId);
  const existing = await conversationRef.get();
  const messageCount = media.length + (text ? 1 : 0);
  const last = text || PREVIEW[media[media.length - 1].kind];
  const batch = db.batch();
  batch.set(conversationRef, {
    vehicleId,
    scannerId,
    ownerUid: vehicle.ownerUid,
    plateNumber: vehicle.plateNumber || "",
    colorName: vehicle.colorName || "",
    ...(scannerName || !existing.exists ? { scannerName: scannerName || "Anonymous" } : {}),
    lastMessagePreview: last,
    lastMessageAt: FieldValue.serverTimestamp(),
    unreadForOwner: true,
    unreadForScanner: false,
    unreadCountForOwner: FieldValue.increment(messageCount),
    unreadCountForScanner: 0,
    resolved: false,
  }, { merge: true });

  // Distinct, increasing times keep the photos and text in the order sent.
  const start = Date.now();
  let i = 0;
  const messages = conversationRef.collection("messages");
  for (const m of media) {
    batch.set(messages.doc(), {
      sender: "scanner",
      kind: m.kind,
      text: "",
      ...(m.kind === "voice" ? { audioUrl: m.url, durationSeconds: m.seconds } : { mediaUrl: m.url }),
      loggedByServer: true,
      createdAt: Timestamp.fromMillis(start + i++),
    });
  }
  if (text) {
    batch.set(messages.doc(), {
      sender: "scanner",
      kind: "text",
      text,
      loggedByServer: true,
      createdAt: Timestamp.fromMillis(start + i++),
    });
  }
  await batch.commit();
  await logSafetyEvent("scanner_message", {
    vehicleId,
    scannerId,
    conversationId,
    ownerUid: vehicle.ownerUid,
    scannerName: scannerName || null,
    text: text || null,
    attachments: media.map((m) => m.kind),
    location: locationFrom(data.location),
  }, request);
  return { conversationId };
});

/**
 * Sign-up/login's "is this number registered?" check, which runs before
 * the user is signed in. Answers yes/no only, so `users/{uid}` (name,
 * phone, CNIC) can stay readable by its owner alone.
 */
exports.lookupPhone = onCall(async (request) => {
  const phone = String(request.data?.phone || "");
  if (!PK_MOBILE.test(phone)) {
    throw new HttpsError("invalid-argument", "Enter a valid Pakistani mobile number.");
  }
  const match = await db.collection("users").where("phone", "==", phone).limit(1).get();
  return {
    registered: !match.empty,
    isAdmin: phone === adminPhone.value(),
    blocked: !match.empty && match.docs[0].data().blocked === true,
  };
});


/** True only for the signed-in ADMIN_PHONE account that claimed the role. */
async function isAdminRequest(request) {
  const uid = request.auth?.uid;
  if (!uid || request.auth.token.phone_number !== adminPhone.value()) return false;
  const config = await ADMIN_CONFIG.get();
  return config.exists && config.data().uid === uid;
}

async function requireAdmin(request) {
  if (!(await isAdminRequest(request))) {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}

/**
 * Called right after the ADMIN_PHONE number signs in. Records its uid in
 * config/admin, which the security rules check for every admin read/write;
 * whoever held it before (an old ADMIN_PHONE) loses access immediately.
 */
exports.claimAdminRole = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const phone = request.auth.token.phone_number;
  if (phone !== adminPhone.value()) {
    throw new HttpsError("permission-denied", "This number is not the MoveMe admin.");
  }
  await ADMIN_CONFIG.set({ uid, phone, claimedAt: FieldValue.serverTimestamp() });
  logger.info(`claimAdminRole: admin is now ${uid}`);
  return { admin: true };
});

/**
 * Admin only. Blocking disables the customer's sign-in and revokes their
 * sessions, so every device is signed out once its current token expires
 * (within the hour). Nothing is deleted; unblocking lets them sign in again.
 */
exports.setUserBlocked = onCall(async (request) => {
  await requireAdmin(request);
  const uid = String(request.data?.uid || "");
  const blocked = request.data?.blocked === true;
  if (!uid) throw new HttpsError("invalid-argument", "Which user?");
  if (uid === request.auth.uid) throw new HttpsError("failed-precondition", "You can't block yourself.");

  const auth = getAuth();
  await auth.updateUser(uid, { disabled: blocked });
  if (blocked) await auth.revokeRefreshTokens(uid);
  await db.collection("users").doc(uid).set(
    { blocked, blockedAt: blocked ? FieldValue.serverTimestamp() : FieldValue.delete() },
    { merge: true },
  );
  logger.info(`setUserBlocked: ${uid} blocked=${blocked} by ${request.auth.uid}`);
  return { blocked };
});

/**
 * Permanently deletes the signed-in resident and everything tied to them:
 * profile (incl. FCM tokens), vehicles (private + public QR copies), vehicle
 * and RC-card photos, every conversation they own or joined as a scanner
 * (messages + voice notes), their OTP record, and finally the Auth user.
 *
 * Runs server-side because a client can't delete other rows/files under the
 * security rules, and a client-side `user.delete()` fails with
 * `requires-recent-login` once the sign-in is more than a few minutes old.
 * The Auth user is deleted last, so a partial failure can simply be retried.
 */
exports.deleteAccount = onCall({ timeoutSeconds: 300 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in to delete your account.");
  }

  const auth = getAuth();
  const bucket = getStorage().bucket();
  const userRecord = await auth.getUser(uid).catch(() => null);

  const [owned, scanned] = await Promise.all([
    db.collection("conversations").where("ownerUid", "==", uid).get(),
    db.collection("conversations").where("scannerUid", "==", uid).get(),
  ]);
  const conversationIds = new Set([...owned.docs, ...scanned.docs].map((d) => d.id));
  await Promise.all([...conversationIds].map(async (id) => {
    await bucket.deleteFiles({ prefix: `conversations/${id}/` });
    await db.recursiveDelete(db.collection("conversations").doc(id));
  }));

  const vehicles = await db.collection("vehicles").where("ownerUid", "==", uid).get();
  await Promise.all(vehicles.docs.map((d) => d.ref.delete()));
  await Promise.all([
    bucket.deleteFiles({ prefix: `vehicle_photos/${uid}/` }),
    bucket.deleteFiles({ prefix: `rc_cards/${uid}/` }),
  ]);

  await db.recursiveDelete(db.collection("users").doc(uid));
  if (userRecord?.phoneNumber) {
    await db.collection("phone_otps").doc(userRecord.phoneNumber).delete();
  }

  await auth.deleteUser(uid);
  logger.info(`deleteAccount: removed ${uid} (${conversationIds.size} conversation(s), ${vehicles.size} vehicle(s)).`);
  return { ok: true };
});
