const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const crypto = require("crypto");
const { getAuth } = require("firebase-admin/auth");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");

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

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

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
    if (!message || message.sender !== "scanner") return;

    const { conversationId } = event.params;
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

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: `${scannerName} messaged you about ${plateNumber}`,
        body: text,
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
        },
      },
      apns: { payload: { aps: { sound: "default" } } },
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
  const scannerName = scannerSnap.data()?.name || "A ParkTag resident";

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
      ownerName: vehicle.ownerName || "A ParkTag resident",
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

  return {
    conversationId,
    ownerName: conversation.ownerName || "A ParkTag resident",
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
