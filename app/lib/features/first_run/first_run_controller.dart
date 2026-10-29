import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_preferences.dart';

/// Whether the first-run wizard is due: after the first sign-in on this
/// device (not when adding another home, not after an update), until it is
/// finished or skipped once.
class FirstRunController extends Notifier<bool> {
  static const _key = 'firstRun';

  @override
  bool build() => false;

  bool get _done =>
      ref.read(appPreferencesProvider).readJson(_key)?['done'] == true;

  /// A home was just signed in to for the first time.
  void signedIn() {
    if (!_done) state = true;
  }

  Future<void> finish() async {
    state = false;
    await ref.read(appPreferencesProvider).writeJson(_key, {'done': true});
  }
}

final firstRunProvider = NotifierProvider<FirstRunController, bool>(
  FirstRunController.new,
);
