import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time, refreshed every 30 s, for "… minutes ago" labels.
final kioskNowProvider = Provider<DateTime>((ref) {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now();
});
