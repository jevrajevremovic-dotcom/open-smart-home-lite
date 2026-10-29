import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/app_preferences.dart';
import 'app.dart';

final _log = AppLogger('App');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    _log.error('Flutter error', details.exception, details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.error('Uncaught error', error, stack);
    return true;
  };

  final config = AppConfig.fromEnvironment();
  if (config.mockMode) {
    _log.warning('Mock mode enabled — no real server is used');
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Connection retries are handled explicitly (WebSocket backoff,
      // user-triggered retry); automatic provider retries would hide errors.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SmartHomeApp(),
    ),
  );
}
