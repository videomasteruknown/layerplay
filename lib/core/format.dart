String fmtTime(Duration d) {
  final neg = d.isNegative;
  final t = d.abs();
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  final core = h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  return neg ? '-$core' : core;
}

String fmtOffset(int ms) {
  final sign = ms >= 0 ? '+' : '\u2212';
  final digits = ms.abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return '$sign$digits ms';
}

String fmtRate(double r) => '${r.toStringAsFixed((r * 100) % 10 == 0 ? 1 : 2)}x';
