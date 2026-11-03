import 'package:media_kit/media_kit.dart';

/// Every knob that decides how much RAM playback may use.
///
/// The video player and the audio-layer player each get their own budget.
/// Nothing is ever loaded whole: libmpv reads the file in chunks, keeps a small
/// read-ahead window plus a small back-buffer, and discards the rest.
class MemoryProfile {
  const MemoryProfile({
    required this.videoDemuxerBytes,
    required this.videoBackBytes,
    required this.audioDemuxerBytes,
    required this.audioBackBytes,
    required this.readaheadSecs,
    required this.decoderThreads,
  });

  final int videoDemuxerBytes;
  final int videoBackBytes;
  final int audioDemuxerBytes;
  final int audioBackBytes;
  final int readaheadSecs;
  final int decoderThreads;

  static const int _mib = 1024 * 1024;

  /// Target: 2 GB devices. Whole playback stack stays well under ~250 MB.
  static const lowEnd = MemoryProfile(
    videoDemuxerBytes: 24 * _mib,
    videoBackBytes: 4 * _mib,
    audioDemuxerBytes: 4 * _mib,
    audioBackBytes: 1 * _mib,
    readaheadSecs: 12,
    decoderThreads: 2,
  );

  static const standard = MemoryProfile(
    videoDemuxerBytes: 64 * _mib,
    videoBackBytes: 16 * _mib,
    audioDemuxerBytes: 8 * _mib,
    audioBackBytes: 2 * _mib,
    readaheadSecs: 30,
    decoderThreads: 4,
  );

  Future<void> applyToVideo(Player p) async {
    await setMpv(p, 'cache', 'yes');
    await setMpv(p, 'demuxer-max-bytes', '$videoDemuxerBytes');
    await setMpv(p, 'demuxer-max-back-bytes', '$videoBackBytes');
    await setMpv(p, 'demuxer-readahead-secs', '$readaheadSecs');
    await setMpv(p, 'cache-secs', '$readaheadSecs');
    await setMpv(p, 'vd-lavc-threads', '$decoderThreads');
    await setMpv(p, 'vd-lavc-skiploopfilter', 'nonref');
    await setMpv(p, 'framedrop', 'vo');
    await setMpv(p, 'hr-seek-framedrop', 'yes');
    await setMpv(p, 'audio-buffer', '0.2');
    await setMpv(p, 'ytdl', 'no');
  }

  Future<void> applyToAudio(Player p) async {
    await setMpv(p, 'vid', 'no');
    await setMpv(p, 'audio-display', 'no');
    await setMpv(p, 'cache', 'yes');
    await setMpv(p, 'demuxer-max-bytes', '$audioDemuxerBytes');
    await setMpv(p, 'demuxer-max-back-bytes', '$audioBackBytes');
    await setMpv(p, 'demuxer-readahead-secs', '$readaheadSecs');
    await setMpv(p, 'audio-buffer', '0.2');
  }

  /// Called on OS memory-pressure callbacks: shrink caches immediately.
  Future<void> trim(Player video, Player audio) async {
    await setMpv(video, 'demuxer-max-back-bytes', '0');
    await setMpv(video, 'demuxer-max-bytes', '${8 * _mib}');
    await setMpv(audio, 'demuxer-max-back-bytes', '0');
    await setMpv(audio, 'demuxer-max-bytes', '${2 * _mib}');
  }

  Future<void> restore(Player video, Player audio) async {
    await applyToVideo(video);
    await applyToAudio(audio);
  }
}

/// Sets a raw libmpv property. Silently ignored on platforms without libmpv.
Future<void> setMpv(Player p, String key, String value) async {
  try {
    await (p.platform as dynamic).setProperty(key, value);
  } catch (_) {}
}
