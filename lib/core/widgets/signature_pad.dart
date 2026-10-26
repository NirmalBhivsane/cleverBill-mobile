import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../theme/app_theme.dart';

/// Simple finger-drawn signature pad. Returns a base64 PNG (no data-URL prefix) via [showSignatureDialog].
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged, this.height = 180});
  final ValueChanged<List<List<Offset>>> onChanged;
  final double height;
  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  @override
  Widget build(BuildContext context) => Container(
    height: widget.height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: C.border),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
        onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
        onPanEnd: (_) => widget.onChanged(_strokes),
        child: CustomPaint(painter: _SigPainter(_strokes), size: Size.infinite),
      ),
    ),
  );

  void clear() {
    setState(() => _strokes.clear());
    widget.onChanged(_strokes);
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, strokes);
  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}

void paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final p = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  for (final s in strokes) {
    if (s.length == 1) {
      canvas.drawPoints(ui.PointMode.points, s, p);
    } else {
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
  }
}

/// Shows a dialog; returns base64 PNG or null when cancelled / empty.
Future<String?> showSignatureDialog(
  BuildContext context, {
  double width = 300,
  double height = 180,
}) async {
  List<List<Offset>> strokes = [];
  final key = GlobalKey<_SignaturePadState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Customer signature'),
      content: SizedBox(
        width: width,
        child: SignaturePad(
          key: key,
          height: height,
          onChanged: (s) => strokes = s.map((e) => List.of(e)).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => key.currentState?.clear(),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (strokes.isEmpty) return Navigator.pop(ctx);
            final rec = ui.PictureRecorder();
            final canvas = Canvas(rec);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, width, height),
              Paint()..color = Colors.white,
            );
            paintStrokes(canvas, strokes);
            final img = await rec.endRecording().toImage(
              width.toInt(),
              height.toInt(),
            );
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            if (ctx.mounted)
              Navigator.pop(ctx, base64Encode(bytes!.buffer.asUint8List()));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
