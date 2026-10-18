import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording (Android) while a QR code is on
/// screen. Counted, so a QR screen that opens another QR screen stays
/// protected until the last one closes. A no-op on iOS and the web.
abstract class ScreenSecurity {
  static const _channel = MethodChannel('moveme/screen_security');
  static int _holders = 0;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> enable() async {
    _holders++;
    if (_holders == 1) await _set(true);
  }

  static Future<void> disable() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _set(false);
  }

  static Future<void> _set(bool secure) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Widget tests have no platform side.
    } on PlatformException {
      // Never let a missing flag break the screen.
    }
  }
}
