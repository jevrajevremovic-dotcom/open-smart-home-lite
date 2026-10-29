import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/app_preferences.dart';

/// Android's foreground service that keeps the app running when it is
/// closed (ConnectionService.kt).
abstract interface class BackgroundPlatform {
  bool get supported;
  Future<void> start({required String title, required String text});
  Future<void> stop();
}

class AndroidBackground implements BackgroundPlatform {
  static const _channel = MethodChannel('org.opensmarthome/background');
  static final _log = AppLogger('Background');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> start({required String title, required String text}) async {
    try {
      await _channel.invokeMethod('start', {'title': title, 'text': text});
    } on PlatformException catch (e) {
      _log.warning('Could not start', e.code);
    } on MissingPluginException {
      // Not in this build.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      _log.warning('Could not stop', e.code);
    } on MissingPluginException {
      // Not in this build.
    }
  }
}

final backgroundPlatformProvider = Provider<BackgroundPlatform>(
  (ref) => AndroidBackground(),
);

/// Automations keep running when the app is closed (opt-in).
class BackgroundAutomationsController extends Notifier<bool> {
  static const _key = 'automations.background';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(
    bool enabled, {
    required String title,
    required String text,
  }) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
    await apply(title: title, text: text);
  }

  /// Starts or stops the service as chosen (also at the app's start).
  Future<void> apply({required String title, required String text}) async {
    final platform = ref.read(backgroundPlatformProvider);
    if (!platform.supported) return;
    if (state) {
      await platform.start(title: title, text: text);
    } else {
      await platform.stop();
    }
  }
}

final backgroundAutomationsProvider =
    NotifierProvider<BackgroundAutomationsController, bool>(
      BackgroundAutomationsController.new,
    );
