package com.parktagapp.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /**
         * Must match `com.google.firebase.messaging.default_notification_channel_id`
         * in AndroidManifest.xml. FCM attaches incoming notifications to this
         * channel; on Android 8+ a notification whose channel does not exist is
         * dropped silently by the system, which is why the channel is created
         * here rather than assumed.
         */
        const val MESSAGES_CHANNEL_ID = "parktag_messages"

        /** Blocks screenshots and screen recording while a QR code is shown. */
        const val SCREEN_SECURITY_CHANNEL = "moveme/screen_security"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.argument<Boolean>("secure") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createMessagesChannel()
    }

    private fun createMessagesChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return
        // Creating an existing channel is a no-op, so this is safe on every
        // launch. IMPORTANCE_HIGH is what makes a message heads-up rather
        // than appearing silently in the shade — someone is asking the
        // resident to move a blocking car.
        val channel = NotificationChannel(
            MESSAGES_CHANNEL_ID,
            "Messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Someone scanned your vehicle's QR code and sent you a message."
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }
}
