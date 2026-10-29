import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';

/// The Android home screen widget with scene buttons (ScenesWidget.kt).
/// It only holds scene ids and names, never a token: a tap opens the app,
/// which runs the scene once data is live.
abstract interface class HomeScreenWidgetPlatform {
  bool get supported;

  /// Scenes as (id, name); [emptyText] is shown when there are none.
  Future<void> setScenes(List<(String, String)> scenes, String emptyText);

  /// What the home, thermostat or light widget ([kind]: `status`,
  /// `thermostat`, `light`) shows; `null` = not set up. Display text only.
  Future<void> setHomeWidget(String kind, Map<String, Object?>? data);

  /// The widget link that launched the app, if any.
  Future<Uri?> initialUri();

  /// Widget links tapped while the app runs.
  Stream<Uri?> get clicks;
}

/// Talks to MainActivity over `org.opensmarthome/widget`.
class AndroidHomeScreenWidget implements HomeScreenWidgetPlatform {
  static final _log = AppLogger('HomeWidget');
  static const _channel = MethodChannel('org.opensmarthome/widget');
  final _clicks = StreamController<Uri?>.broadcast();
  bool _listening = false;

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> setScenes(
    List<(String, String)> scenes,
    String emptyText,
  ) async {
    try {
      await _channel.invokeMethod<void>('setScenes', {
        'scenes': jsonEncode([
          for (final (id, name) in scenes) {'id': id, 'name': name},
        ]),
        'emptyText': emptyText,
      });
    } on Object catch (e) {
      _log.debug('widget update failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> setHomeWidget(String kind, Map<String, Object?>? data) async {
    try {
      await _channel.invokeMethod<void>('setHomeWidget', {
        'kind': kind,
        'json': data == null ? null : jsonEncode(data),
      });
    } on Object catch (e) {
      _log.debug('widget update failed: ${e.runtimeType}');
    }
  }

  @override
  Future<Uri?> initialUri() async {
    try {
      final link = await _channel.invokeMethod<String>('initialLink');
      return link == null ? null : Uri.tryParse(link);
    } on Object {
      return null;
    }
  }

  @override
  Stream<Uri?> get clicks {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'link' && call.arguments is String) {
          _clicks.add(Uri.tryParse(call.arguments as String));
        }
      });
    }
    return _clicks.stream;
  }
}

final homeScreenWidgetProvider = Provider<HomeScreenWidgetPlatform>(
  (ref) => AndroidHomeScreenWidget(),
);

final _sceneId = RegExp(r'^scene\.[a-z0-9_]+$');

/// `opensmarthome://scene?id=scene.x` → `scene.x`; anything else → null.
String? sceneIdFromWidgetUri(Uri? uri) {
  if (uri == null || uri.scheme != 'opensmarthome' || uri.host != 'scene') {
    return null;
  }
  final id = uri.queryParameters['id'];
  return id != null && _sceneId.hasMatch(id) ? id : null;
}
