import 'package:flutter/material.dart';

import '../core/playback_engine.dart';
import 'theme.dart';

/// Two-lane mini timeline. The video lane is fixed; the audio lane can be
/// dragged left/right to change the offset. Coarse mode shows a 20 s window,
/// fine mode a 2 s window (roughly 5 ms per pixel on a phone).
class OffsetLane extends StatefulWidget {
  const OffsetLane({super.key, required this.engine});
  final PlaybackEngine engine;

  @override
  State<OffsetLane> createState() => _OffsetLaneState();
}

class _OffsetLaneState extends State<OffsetLane> {
  bool _fine = false;
  double get _windowMs => _fine ? 2000 : 20000;

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Drag the audio lane to shift it',
                style: TextStyle(color: Palette.textDim, fontSize: 12.5)),
            const Spacer(),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('20 s')),
                ButtonSegment(value: true, label: Text('2 s')),
              ],
              selected: {_fine},
              onSelectionChanged: (s) => setState(() => _fine = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final msPerPx = _windowMs / c.maxWidth;
            return GestureDetector(
              onHorizontalDragUpdate: (d) => e.setOffset(
                  e.audioOffsetMs.value + (d.delta.dx * msPerPx).round()),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  size: Size(c.maxWidth, 92),
                  painter: _LanePainter(e, _windowMs, _fine),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter(this.e, this.windowMs, this.fine)
      : super(
          repaint: Listenable.merge(
              [e.position, e.audioOffsetMs, e.audioDuration, e.audioName]),
        );

  final PlaybackEngine e;
  final double windowMs;
  final bool fine;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final msPerPx = windowMs / w;
    final p = e.position.value.inMilliseconds.toDouble();
    final left = p - windowMs / 2;
    double xOf(double masterMs) => (masterMs - left) / msPerPx;

    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.raised);

    // ruler
    final step = fine ? 100.0 : 1000.0;
    final major = fine ? 500.0 : 5000.0;
    final tick = Paint()..color = Palette.line;
    final tickMajor = Paint()..color = Colors.white30;
    var t = (left / step).floorToDouble() * step;
    for (; t < left + windowMs; t += step) {
      final isMajor = (t % major).abs() < 0.5;
      final x = xOf(t);
      canvas.drawLine(Offset(x, 0), Offset(x, isMajor ? 10 : 5),
          isMajor ? tickMajor : tick);
    }

    // video lane
    final vRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 16, w, 28), const Radius.circular(4));
    canvas.drawRRect(vRect, Paint()..color = const Color(0xFF3A3A3A));
    _label(canvas, 'Video', const Offset(8, 22), Palette.text);

    // audio lane
    final hasAudio = e.audioName.value != null;
    final startMs = e.audioOffsetMs.value.toDouble();
    final durMs = e.audioDuration.value.inMilliseconds.toDouble();
    final x0 = xOf(startMs);
    final x1 = durMs > 0 ? xOf(startMs + durMs) : w + 40;
    final aRect = RRect.fromLTRBR(
        x0, 50, x1, 78, const Radius.circular(4));
    canvas.drawRRect(
      aRect,
      Paint()..color = hasAudio ? Palette.accent.withOpacity(0.9) : Palette.line,
    );
    _label(canvas, hasAudio ? 'Audio' : 'No audio loaded',
        Offset((x0 < 0 ? 0 : x0) + 8, 56), hasAudio ? Colors.black : Palette.textDim);

    // playhead
    canvas.drawLine(Offset(xOf(p), 0), Offset(xOf(p), size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5);
  }

  void _label(Canvas c, String s, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) =>
      old.windowMs != windowMs || old.fine != fine;
}
