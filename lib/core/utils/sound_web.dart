import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('playDmartBeep')
external void _jsPlayDmartBeep();

web.AudioContext? _sharedAudioCtx;

void playScannerBeepPlatform() {
  // 1. Primary: Call global JS hardware synthesizer defined in index.html
  try {
    _jsPlayDmartBeep();
    return;
  } catch (_) {}

  // 2. Direct Web Audio API via package:web using shared AudioContext
  try {
    _sharedAudioCtx ??= web.AudioContext();
    final ctx = _sharedAudioCtx!;
    if (ctx.state == 'suspended') {
      ctx.resume();
    }
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.type = 'sine';
    final now = ctx.currentTime;
    osc.frequency.setValueAtTime(2350, now);
    gain.gain.setValueAtTime(0.35, now);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.075);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(now);
    osc.stop(now + 0.075);
    return;
  } catch (_) {}
}
