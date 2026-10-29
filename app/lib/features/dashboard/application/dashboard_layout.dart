import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';

/// Cards of the home screen the user can show, hide and reorder. Warnings
/// (connection, stale data, critical alerts) are always shown on top.
enum DashboardCard {
  summary,
  weather,
  media,
  notifications,
  lists,
  shortcuts,
  scenes,
  attention,
  favorites,
  rooms;

  /// On wide screens these go to the right-hand pane.
  bool get contentPane => this == favorites || this == rooms;
}

@immutable
class DashboardLayout {
  const DashboardLayout({
    this.order = DashboardCard.values,
    this.hidden = const {},
  });

  /// Tolerant: unknown names are dropped, cards added in a later version
  /// are appended, so an old saved layout never hides something new.
  factory DashboardLayout.fromJson(Map<String, Object?>? json) {
    if (json == null) return const DashboardLayout();
    DashboardCard? card(Object? name) =>
        DashboardCard.values.where((c) => c.name == name).firstOrNull;
    final order = <DashboardCard>[
      if (json['order'] case final List<Object?> l)
        for (final n in l) ?card(n),
    ];
    final unique = order.toSet().toList();
    for (final c in DashboardCard.values) {
      if (!unique.contains(c)) unique.add(c);
    }
    return DashboardLayout(
      order: unique,
      hidden: {
        if (json['hidden'] case final List<Object?> l)
          for (final n in l) ?card(n),
      },
    );
  }

  final List<DashboardCard> order;
  final Set<DashboardCard> hidden;

  Iterable<DashboardCard> get visible =>
      order.where((c) => !hidden.contains(c));

  bool get isDefault =>
      listEquals(order, DashboardCard.values) && hidden.isEmpty;

  Map<String, Object?> toJson() => {
    'order': [for (final c in order) c.name],
    'hidden': [for (final c in hidden) c.name],
  };
}

class DashboardLayoutController extends Notifier<DashboardLayout> {
  static const _key = 'dashboard.layout';

  @override
  DashboardLayout build() => DashboardLayout.fromJson(
    ref.watch(appPreferencesProvider).readJson(_key),
  );

  Future<void> _save(DashboardLayout layout) async {
    state = layout;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, layout.isDefault ? null : layout.toJson());
  }

  Future<void> setVisible(DashboardCard card, bool visible) => _save(
    DashboardLayout(
      order: state.order,
      hidden: visible
          ? ({...state.hidden}..remove(card))
          : {...state.hidden, card},
    ),
  );

  Future<void> move(int from, int to) {
    final order = [...state.order];
    final card = order.removeAt(from);
    order.insert(to, card);
    return _save(DashboardLayout(order: order, hidden: state.hidden));
  }

  Future<void> reset() => _save(const DashboardLayout());
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutController, DashboardLayout>(
      DashboardLayoutController.new,
    );
