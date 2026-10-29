import 'dart:math';

/// Capped exponential backoff with "equal jitter".
///
/// Delays grow `initial * 2^n` up to [max]; half of each delay is
/// randomised so many wall tablets do not reconnect in lock-step after a
/// server restart. Retries never run in a tight loop.
class ExponentialBackoff {
  ExponentialBackoff({
    this.initial = const Duration(seconds: 1),
    this.max = const Duration(seconds: 60),
    Random? random,
  }) : assert(initial > Duration.zero && max >= initial),
       _random = random ?? Random();

  final Duration initial;
  final Duration max;
  final Random _random;
  int _attempt = 0;

  int get attempt => _attempt;

  Duration next() {
    final exp = initial.inMicroseconds * pow(2, min(_attempt, 20));
    final capped = min(exp, max.inMicroseconds.toDouble()).toInt();
    _attempt++;
    final half = capped ~/ 2;
    return Duration(microseconds: half + _random.nextInt(half + 1));
  }

  void reset() => _attempt = 0;
}
