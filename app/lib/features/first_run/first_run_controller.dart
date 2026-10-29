import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_preferences.dart';

/// Whether the first-run wizard is due: on the first start on this device
/// (not after an update), until it is finished or skipped once.
class FirstRunController extends Notifier<bool> {
  static const _key = 'firstRun';

  @override
  bool build() =>
      ref.read(appPreferencesProvider).readJson(_key)?['done'] != true;

  Future<void> finish() async {
    state = false;
    await ref.read(appPreferencesProvider).writeJson(_key, {'done': true});
  }
}

final firstRunProvider = NotifierProvider<FirstRunController, bool>(
  FirstRunController.new,
);
