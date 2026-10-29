import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../domain/routines.dart';

/// The household's scenes and automations, kept on this phone.
@immutable
class Routines {
  const Routines({this.scenes = const [], this.automations = const []});

  final List<LocalScene> scenes;
  final List<LocalAutomation> automations;

  Map<String, Object?> toJson() => {
    'scenes': [for (final s in scenes) s.toJson()],
    'automations': [for (final a in automations) a.toJson()],
  };

  static Routines fromJson(Map<String, Object?>? json) => Routines(
    scenes: [
      for (final s in (json?['scenes'] as List?) ?? const [])
        ?LocalScene.fromJson(s),
    ],
    automations: [
      for (final a in (json?['automations'] as List?) ?? const [])
        ?LocalAutomation.fromJson(a),
    ],
  );
}

class RoutinesController extends Notifier<Routines> {
  static const _key = 'routines';

  @override
  Routines build() =>
      Routines.fromJson(ref.watch(appPreferencesProvider).readJson(_key));

  Future<void> _save(Routines r) async {
    state = r;
    await ref.read(appPreferencesProvider).writeJson(_key, r.toJson());
  }

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// Adds or replaces [scene] (by id).
  Future<void> saveScene(LocalScene scene) => _save(
    Routines(
      scenes: [
        for (final s in state.scenes)
          if (s.id != scene.id) s,
        scene,
      ],
      automations: state.automations,
    ),
  );

  Future<void> deleteScene(String id) => _save(
    Routines(
      scenes: [
        for (final s in state.scenes)
          if (s.id != id) s,
      ],
      automations: state.automations,
    ),
  );

  /// Adds or replaces [automation] (by id), keeping its place.
  Future<void> saveAutomation(LocalAutomation automation) {
    final list = [...state.automations];
    final i = list.indexWhere((a) => a.id == automation.id);
    if (i < 0) {
      list.add(automation);
    } else {
      list[i] = automation;
    }
    return _save(Routines(scenes: state.scenes, automations: list));
  }

  Future<void> deleteAutomation(String id) => _save(
    Routines(
      scenes: state.scenes,
      automations: [
        for (final a in state.automations)
          if (a.id != id) a,
      ],
    ),
  );

  Future<void> setEnabled(String id, bool enabled) async {
    final a = state.automations.where((a) => a.id == id).firstOrNull;
    if (a != null) await saveAutomation(a.copyWith(enabled: enabled));
  }

  Future<void> markTriggered(String id, DateTime at) async {
    final a = state.automations.where((a) => a.id == id).firstOrNull;
    if (a != null) await saveAutomation(a.copyWith(lastTriggered: at));
  }
}

final routinesProvider = NotifierProvider<RoutinesController, Routines>(
  RoutinesController.new,
);
