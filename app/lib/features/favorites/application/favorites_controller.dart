import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../authentication/application/session_controller.dart';

/// Ordered favorite device ids of the active server, stored locally.
class FavoritesController extends Notifier<List<String>> {
  @override
  List<String> build() {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) return const [];
    return List.unmodifiable(
      ref.watch(appPreferencesProvider).favorites(profile.id),
    );
  }

  bool contains(String id) => state.contains(id);

  Future<void> toggle(String id) => _save(
    state.contains(id) ? [...state.where((e) => e != id)] : [...state, id],
  );

  Future<void> reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    return _save(list);
  }

  /// New order for the favorites shown; ids not shown (devices that are
  /// gone for now) keep their place at the end.
  Future<void> setOrder(List<String> shown) =>
      _save([...shown, ...state.where((id) => !shown.contains(id))]);

  Future<void> _save(List<String> ids) async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;
    state = List.unmodifiable(ids);
    await ref.read(appPreferencesProvider).setFavorites(profile.id, ids);
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, List<String>>(
  FavoritesController.new,
);

final isFavoriteProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(favoritesProvider.select((f) => f.contains(id))),
);
