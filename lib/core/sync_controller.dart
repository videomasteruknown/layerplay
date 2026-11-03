import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// Virtual timeline: the video player is the master clock, the audio layer is a
/// slave that is continuously steered to
///
///     audioPosition = masterPosition - offset
///
/// A positive [offsetMs] delays the audio (it starts that many ms into the
/// video); a negative one makes the audio start early (skips its first ms).
///
/// Nothing is rendered or written to disk. Both files are simply streamed in
/// parallel and re-aligned whenever they drift.
class TimelineSync {
  TimelineSync({required this.master, required this.slave});

  final Player master;
  final Player slave;

  /// Beyond this, correct with a seek (audible, but rare).
  static const int hardSeekThresholdMs = 150;

  /// Between soft and hard, correct inaudibly by nudging playback speed +-3%.
  static const int softThresholdMs = 30;

  static const Duration tickInterval = Duration(milliseconds: 200);

  /// After any seek/start, ignore drift readings while the slave settles.
  static const Duration settleTime = Duration(milliseconds: 700);

  int _offsetMs = 0;
  bool _loaded = false;
  bool _resyncing = false;
  double _masterRate = 1.0;
  double _slaveRate = 1.0;
  DateTime _settleUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  final List<StreamSubscription<dynamic>> _subs = [];

  int get offsetMs => _offsetMs;

  bool get _masterRunning =>
      master.state.playing && !master.state.buffering && !master.state.completed;

  int get _targetMs => master.state.position.inMilliseconds - _offsetMs;

  void start() {
    _subs
      ..add(master.stream.playing.listen((_) => _onTransport()))
      ..add(master.stream.buffering.listen((_) => _onTransport()))
      ..add(master.stream.completed.listen((c) {
        if (c) slave.pause();
      }))
      ..add(master.stream.rate.listen(_onMasterRate));
    _timer = Timer.periodic(tickInterval, (_) => _correct());
  }

  Future<void> stop() async {
    _timer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  void setLoaded(bool loaded) => _loaded = loaded;

  /// Updates the offset without seeking; call [resync] afterwards.
  void setOffsetNoResync(int ms) => _offsetMs = ms;

  /// Hard re-alignment: seek the slave to where the master says it should be.
  Future<void> resync() async {
    if (!_loaded || _resyncing) return;
    _resyncing = true;
    try {
      _settleUntil = DateTime.now().add(settleTime);
      final t = _targetMs;
      final dur = slave.state.duration.inMilliseconds;
      final inRange = t >= 0 && (dur == 0 || t < dur);
      if (!inRange) {
        // Audio hasn't started yet (or already ended): park it silently.
        if (slave.state.playing) await slave.pause();
        return;
      }
      await _setSlaveRate(1.0);
      await slave.seek(Duration(milliseconds: t));
      if (_masterRunning) {
        await slave.play();
      } else {
        await slave.pause();
      }
    } finally {
      _resyncing = false;
    }
  }

  void _onTransport() {
    if (!_loaded) return;
    if (_masterRunning) {
      resync();
    } else {
      slave.pause();
    }
  }

  void _onMasterRate(double r) {
    _masterRate = r;
    _slaveRate = -1; // force re-apply
    _setSlaveRate(1.0);
  }

  Future<void> _setSlaveRate(double factor) async {
    final r = _masterRate * factor;
    if ((r - _slaveRate).abs() < 0.0001) return;
    _slaveRate = r;
    await slave.setRate(r);
  }

  /// Runs 5x per second. Cheap: two property reads and an integer subtraction.
  void _correct() {
    if (!_loaded || _resyncing || !_masterRunning) return;
    if (DateTime.now().isBefore(_settleUntil)) return;

    final t = _targetMs;
    final dur = slave.state.duration.inMilliseconds;
    final inRange = t >= 0 && (dur == 0 || t < dur);

    if (!inRange) {
      if (slave.state.playing) slave.pause();
      return;
    }
    if (!slave.state.playing) {
      resync(); // audio's start point has just been reached
      return;
    }

    final drift = slave.state.position.inMilliseconds - t; // + = audio ahead
    final abs = drift.abs();
    if (abs > hardSeekThresholdMs) {
      resync();
    } else if (abs > softThresholdMs) {
      _setSlaveRate(drift > 0 ? 0.97 : 1.03);
    } else {
      _setSlaveRate(1.0);
    }
  }
}
