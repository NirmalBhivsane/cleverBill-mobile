import 'package:flutter/services.dart';
import 'sound_web.dart' if (dart.library.io) 'sound_io.dart';

/// Scanner sound service providing DMart-style supermarket checkout beeps
class PosSound {
  static void playBeep() {
    try {
      playScannerBeepPlatform();
    } catch (_) {}
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
}

