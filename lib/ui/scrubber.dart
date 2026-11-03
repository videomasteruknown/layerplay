import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/playback_engine.dart';
import 'theme.dart';

class Scrubber extends StatefulWidget {
  const Scrubber({super.key, required this.engine, required this.onInteract});
  final PlaybackEngine engine;
  final VoidCallback onInteract;

  @override
  State<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<Scrubber> {
  double? _drag; // ms while the finger is down; seek happens on release only

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    return AnimatedBuilder(
      animation: Listenable.merge([e.position, e.duration, e.buffer]),
      builder: (context, _) {
        final dur = e.duration.value.inMilliseconds.toDouble();
        final max = dur <= 0 ? 1.0 : dur;
        final pos =
            (_drag ?? e.position.value.inMilliseconds.toDouble()).clamp(0.0, max);
        final buf = e.buffer.value.inMilliseconds.toDouble().clamp(0.0, max);
        const style = TextStyle(
          fontSize: 12.5,
          color: Palette.text,
          fontFeatures: [FontFeature.tabularFigures()],
        );
        return Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(fmtTime(Duration(milliseconds: pos.round())),
                  style: style),
            ),
            Expanded(
              child: Slider(
                value: pos,
                max: max,
                secondaryTrackValue: buf,
                onChangeStart: (v) {
                  setState(() => _drag = v);
                  widget.onInteract();
                },
                onChanged: (v) {
                  setState(() => _drag = v);
                  widget.onInteract();
                },
                onChangeEnd: (v) {
                  setState(() => _drag = null);
                  e.seekTo(Duration(milliseconds: v.round()));
                },
              ),
            ),
            SizedBox(
              width: 58,
              child: Text(fmtTime(e.duration.value),
                  textAlign: TextAlign.right, style: style),
            ),
          ],
        );
      },
    );
  }
}
