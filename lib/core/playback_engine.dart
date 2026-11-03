import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'memory_profile.dart';
import 'sync_controller.dart';

/// Owns both players and exposes UI state as ValueNotifiers so that only the
/// widgets that care (scrubber, play button...) rebuild.
class PlaybackEngine {
  PlaybackEngine({this.profile = MemoryProfile.lowEnd}) {
    video = Player(
      configuration: PlayerConfiguration(
        title: 'LayerPlay',
        bufferSize: profile.videoDemuxerBytes,
      ),
    );
    audio = Player(
      configuration: PlayerConfiguration(
        vo: 'null', // audio layer never allocates a video surface
        bufferSize: profile.audioDemuxerBytes,
      ),
    );
    videoController = VideoController(
      video,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    sync = TimelineSync(master: video, slave: audio);
  }

  final MemoryProfile profile;
  late final Player video;
  late final Player audio;
  late final VideoController videoController;
  late final TimelineSync sync;

  // UI state
  final title = ValueNotifier<String>('');
  final position = ValueNotifier<Duration>(Duration.zero);
  final duration = ValueNotifier<Duration>(Duration.zero);
  final buffer = ValueNotifier<Duration>(Duration.zero);
  final playing = ValueNotifier<bool>(false);
  final buffering = ValueNotifier<bool>(false);
  final rate = ValueNotifier<double>(1.0);
  final videoVolume = ValueNotifier<double>(100);
  final audioVolume = ValueNotifier<double>(100);
  final audioOffsetMs = ValueNotifier<int>(0);
  final audioName = ValueNotifier<String?>(null);
  final audioDuration = ValueNotifier<Duration>(Duration.zero);

  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const int maxOffsetMs = 3600000; // +-1 hour

  final List<StreamSubscription<dynamic>> _subs = [];
  DateTime _lastUi = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _offsetDebounce;

  Future<void> init() async {
    await profile.applyToVideo(video);
    await profile.applyToAudio(audio);
    _subs
      ..add(video.stream.position.listen(_onPosition))
      ..add(video.stream.duration.listen((d) => duration.value = d))
      ..add(video.stream.buffer.listen((b) => buffer.value = b))
      ..add(video.stream.playing.listen((p) => playing.value = p))
      ..add(video.stream.buffering.listen((b) => buffering.value = b))
      ..add(video.stream.rate.listen((r) => rate.value = r))
      ..add(audio.stream.duration.listen((d) => audioDuration.value = d));
    sync.start();
  }

  // Position events arrive far more often than a UI needs; 4 Hz is plenty.
  void _onPosition(Duration p) {
    final now = DateTime.now();
    if (now.difference(_lastUi).inMilliseconds < 250) return;
    _lastUi = now;
    position.value = p;
  }

  Future<void> openVideo(String path, String name) async {
    title.value = name;
    await video.open(Media(path), play: true);
  }

  Future<void> loadAudio(String path, String name) async {
    sync.setLoaded(false);
    await audio.open(Media(path), play: false);
    try {
      await audio.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await audio.setVolume(audioVolume.value);
    audioName.value = name;
    sync.setLoaded(true);
    await sync.resync();
  }

  Future<void> clearAudio() async {
    sync.setLoaded(false);
    await audio.stop();
    audioName.value = null;
    audioDuration.value = Duration.zero;
  }

  Future<void> togglePlay() => video.playOrPause();
  Future<void> pause() => video.pause();

  Future<void> seekTo(Duration target) async {
    final max = duration.value;
    var t = target;
    if (t < Duration.zero) t = Duration.zero;
    if (max > Duration.zero && t > max) t = max;
    position.value = t;
    await video.seek(t);
    await sync.resync();
  }

  Future<void> skip(Duration delta) =>
      seekTo(video.state.position + delta);

  Future<void> setRate(double r) async {
    rate.value = r;
    await video.setRate(r); // TimelineSync mirrors this onto the audio layer
  }

  Future<void> setVideoVolume(double v) async {
    videoVolume.value = v;
    await video.setVolume(v);
  }

  Future<void> setAudioVolume(double v) async {
    audioVolume.value = v;
    await audio.setVolume(v);
  }

  /// Millisecond-accurate offset. Re-sync is debounced so dragging stays smooth.
  void setOffset(int ms) {
    final v = ms.clamp(-maxOffsetMs, maxOffsetMs);
    audioOffsetMs.value = v;
    sync.setOffsetNoResync(v);
    _offsetDebounce?.cancel();
    _offsetDebounce =
        Timer(const Duration(milliseconds: 120), () => sync.resync());
  }

  Future<void> trimMemory() => profile.trim(video, audio);
  Future<void> restoreMemory() => profile.restore(video, audio);

  Future<void> dispose() async {
    _offsetDebounce?.cancel();
    await sync.stop();
    for (final s in _subs) {
      await s.cancel();
    }
    for (final n in <ChangeNotifier>[
      title, position, duration, buffer, playing, buffering, rate,
      videoVolume, audioVolume, audioOffsetMs, audioName, audioDuration,
    ]) {
      n.dispose();
    }
    await video.dispose();
    await audio.dispose();
  }
}
