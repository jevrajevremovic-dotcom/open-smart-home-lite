/// How loud and sharp a clap must be.
enum ClapSensitivity {
  low(0.45),
  medium(0.28),
  high(0.16);

  const ClapSensitivity(this.minPeak);

  /// Peak level (0…1 of full scale) a clap must reach.
  final double minPeak;
}

/// Finds a double clap in a stream of short-frame peak levels.
///
/// Fed one value per audio frame (the loudest sample, 0…1). Nothing is
/// recorded: only these levels exist, and only on this device.
///
/// A clap is a sudden peak well above the room's background level that is
/// gone again within ~150 ms. Speech, music and a slammed door last longer
/// or come alone. Exactly two claps 0.15–0.8 s apart, followed by 0.5 s
/// without another one, count as a double clap.
class ClapDetector {
  ClapDetector({
    this.sensitivity = ClapSensitivity.medium,
    this.frame = const Duration(milliseconds: 20),
  });

  final ClapSensitivity sensitivity;
  final Duration frame;

  static const _onsetOverBackground = 6.0; // ≈ 16 dB
  static const _maxClapLength = Duration(milliseconds: 160);
  static const _decayTo = 0.35; // of the clap's own peak
  static const _minGap = Duration(milliseconds: 150);
  static const _maxGap = Duration(milliseconds: 800);
  static const _quietAfter = Duration(milliseconds: 500);
  static const _refractory = Duration(milliseconds: 1500);

  Duration _now = Duration.zero;
  double _background = 0.01;

  // A clap in progress: when it started and how loud it got.
  Duration? _candidateAt;
  double _candidatePeak = 0;

  // Sound stayed loud: ignore everything until it calms down.
  bool _sustained = false;

  final List<Duration> _claps = [];
  Duration _quietUntil = Duration.zero;

  /// Adds one frame; returns `true` once when a double clap is complete.
  bool add(double peak) {
    _now += frame;
    final level = peak.clamp(0.0, 1.0);

    if (_sustained) {
      if (level < _background * 3) _sustained = false;
      _track(level);
      return false;
    }

    final started = _candidateAt;
    if (started != null) {
      if (level > _candidatePeak) _candidatePeak = level;
      if (level < _candidatePeak * _decayTo) {
        _candidateAt = null;
        _clap(started);
      } else if (_now - started > _maxClapLength) {
        // Too long for a clap: speech, music, a vacuum cleaner…
        _candidateAt = null;
        _sustained = true;
        _claps.clear();
      }
      return false;
    }

    if (_now >= _quietUntil &&
        level >= sensitivity.minPeak &&
        level >= _background * _onsetOverBackground) {
      _candidateAt = _now;
      _candidatePeak = level;
      return false;
    }

    _track(level);
    return _check();
  }

  void _track(double level) {
    // Slow average of the room's normal level, never influenced by claps.
    _background = (_background * 0.97 + level * 0.03).clamp(0.005, 1.0);
  }

  void _clap(Duration at) {
    if (_claps.isNotEmpty) {
      final gap = at - _claps.last;
      if (gap < _minGap || gap > _maxGap) _claps.clear();
    }
    _claps.add(at);
    if (_claps.length > 2) _claps.clear(); // three or more: not a command
  }

  bool _check() {
    if (_claps.length != 2) {
      if (_claps.length == 1 && _now - _claps.first > _maxGap) _claps.clear();
      return false;
    }
    if (_now - _claps.last < _quietAfter) return false;
    _claps.clear();
    _quietUntil = _now + _refractory;
    return true;
  }
}
