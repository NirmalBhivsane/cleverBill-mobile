import 'package:flutter/services.dart';

void playScannerBeepPlatform() {
  SystemSound.play(SystemSoundType.click);
  HapticFeedback.lightImpact();
}

