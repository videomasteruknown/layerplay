import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/playback_engine.dart';
import 'audio_panel.dart';
import 'controls_overlay.dart';
import 'theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.path, required this.name});
  final String path;
  final String name;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late final PlaybackEngine engine;
  bool _visible = true;
  bool _panelOpen = false;
  Timer? _hideTimer;
  double _lastTapX = 0;

  @override
  void initState() {
    super.initState();
    engine = PlaybackEngine();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    engine.init().then((_) => engine.openVideo(widget.path, widget.name));
    engine.playing.addListener(_scheduleHide);
    _scheduleHide();
  }

  @override
  void didHaveMemoryPressure() => engine.trimMemory();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) engine.pause();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!engine.playing.value) return;
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && !_panelOpen && engine.playing.value) {
        setState(() => _visible = false);
      }
    });
  }

  void _interact() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _visible = !_visible);
    if (_visible) _scheduleHide();
  }

  Future<void> _openAudioPanel() async {
    _panelOpen = true;
    await showAudioPanel(context, engine);
    _panelOpen = false;
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    engine.playing.removeListener(_scheduleHide);
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTapDown: (d) => _lastTapX = d.localPosition.dx,
        onDoubleTap: () {
          final w = MediaQuery.of(context).size.width;
          engine.skip(Duration(seconds: _lastTapX < w / 2 ? -10 : 10));
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: engine.videoController,
              controls: NoVideoControls,
              fill: Colors.black,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: engine.buffering,
              builder: (_, b, __) => b
                  ? const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Palette.accent),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            ControlsOverlay(
              engine: engine,
              visible: _visible,
              onInteract: _interact,
              onAudio: _openAudioPanel,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
