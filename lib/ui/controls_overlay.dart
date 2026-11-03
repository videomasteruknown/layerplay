import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/playback_engine.dart';
import 'scrubber.dart';
import 'theme.dart';

class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({
    super.key,
    required this.engine,
    required this.visible,
    required this.onInteract,
    required this.onAudio,
    required this.onBack,
  });

  final PlaybackEngine engine;
  final bool visible;
  final VoidCallback onInteract;
  final VoidCallback onAudio;
  final VoidCallback onBack;

  static const _skip = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: _Scrim(top: true, child: _topBar(context)),
            ),
            Center(child: _transport()),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _Scrim(
                top: false,
                child: Scrubber(engine: engine, onInteract: onInteract),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: engine.title,
            builder: (_, t, __) => Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: engine.audioName,
          builder: (_, name, __) => IconButton(
            tooltip: 'Audio layer',
            onPressed: () {
              onInteract();
              onAudio();
            },
            icon: Badge(
              isLabelVisible: name != null,
              smallSize: 8,
              backgroundColor: Palette.accent,
              child: const Icon(Icons.library_music_outlined),
            ),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: engine.rate,
          builder: (_, r, __) => TextButton(
            onPressed: () {
              onInteract();
              _showSpeed(context);
            },
            style: TextButton.styleFrom(foregroundColor: Palette.text),
            child: Text(fmtRate(r),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _transport() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 44,
          tooltip: 'Back 10 seconds',
          icon: const Icon(Icons.replay_10),
          onPressed: () {
            onInteract();
            engine.skip(-_skip);
          },
        ),
        const SizedBox(width: 20),
        ValueListenableBuilder<bool>(
          valueListenable: engine.playing,
          builder: (_, p, __) => Material(
            color: Colors.black54,
            shape: const CircleBorder(
                side: BorderSide(color: Colors.white24, width: 1)),
            child: IconButton(
              iconSize: 52,
              padding: const EdgeInsets.all(14),
              tooltip: p ? 'Pause' : 'Play',
              icon: Icon(p ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                onInteract();
                engine.togglePlay();
              },
            ),
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          iconSize: 44,
          tooltip: 'Forward 10 seconds',
          icon: const Icon(Icons.forward_10),
          onPressed: () {
            onInteract();
            engine.skip(_skip);
          },
        ),
      ],
    );
  }

  void _showSpeed(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: ValueListenableBuilder<double>(
            valueListenable: engine.rate,
            builder: (ctx, current, __) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in PlaybackEngine.speeds)
                  ChoiceChip(
                    label: Text(fmtRate(s)),
                    selected: (current - s).abs() < 0.001,
                    selectedColor: Palette.accent,
                    labelStyle: TextStyle(
                      color: (current - s).abs() < 0.001
                          ? Colors.black
                          : Palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      engine.setRate(s);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.child});
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: top,
        bottom: !top,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, top ? 4 : 28, 8, top ? 24 : 6),
          child: child,
        ),
      ),
    );
  }
}
