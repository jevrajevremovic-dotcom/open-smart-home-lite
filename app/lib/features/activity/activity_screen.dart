import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/widgets/status_widgets.dart';
import '../../integrations/home_assistant/models/ha_history.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_history.dart' show historyStateLabel;
import '../devices/presentation/device_presentation.dart';
import '../restricted/application/restricted_mode.dart';
import '../../core/widgets/skeleton.dart';

enum ActivityFilter { all, lights, security, people }

/// The whole home's logbook for the last 24 hours, newest first.
final homeActivityProvider = FutureProvider.autoDispose<List<HaLogbookEntry>>((
  ref,
) async {
  final api = ref.watch(homeAssistantApiProvider);
  if (api == null) return const [];
  final end = DateTime.now();
  return api.fetchLogbook(null, end.subtract(const Duration(hours: 24)), end);
});

bool _matches(ActivityFilter f, SmartHomeDevice? d, String? entityId) {
  final domain = entityId?.split('.').first;
  return switch (f) {
    ActivityFilter.all => true,
    ActivityFilter.lights => d?.kind.isLight ?? domain == 'light',
    ActivityFilter.people => d?.kind == DeviceKind.person || domain == 'person',
    ActivityFilter.security => switch (d?.kind) {
      DeviceKind.lock ||
      DeviceKind.alarm ||
      DeviceKind.garageDoor ||
      DeviceKind.contactSensor ||
      DeviceKind.motionSensor ||
      DeviceKind.occupancySensor ||
      DeviceKind.smokeSensor ||
      DeviceKind.coSensor ||
      DeviceKind.waterLeakSensor ||
      DeviceKind.siren ||
      DeviceKind.doorbell => true,
      null => const {'lock', 'alarm_control_panel'}.contains(domain),
      _ => false,
    },
  };
}

/// What happened at home: lights, doors, people, and who did it.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityFilter _filter = ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final log = ref.watch(homeActivityProvider);
    final restricted = ref.watch(restrictedModeProvider);

    String label(ActivityFilter f) => switch (f) {
      ActivityFilter.all => l10n.activityAll,
      ActivityFilter.lights => l10n.groupLights,
      ActivityFilter.security => l10n.activitySecurity,
      ActivityFilter.people => l10n.activityPeople,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeActivityProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverToBoxAdapter(
                // One row that scrolls sideways, like other filter rows.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final f in ActivityFilter.values)
                        ChoiceChip(
                          key: ValueKey('activityFilter-${f.name}'),
                          label: Text(label(f)),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            switch (log) {
              AsyncData(:final value) => _list(context, value, restricted),
              AsyncError() => SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: InlineNotice.error(l10n.historyUnavailable),
                ),
              ),
              _ => SliverToBoxAdapter(
                child: ListSkeleton(rows: 8, label: l10n.loadingContent),
              ),
            },
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.activityHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<HaLogbookEntry> entries,
    RestrictedSettings restricted,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final time = DateFormat.Hm(l10n.localeName);
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateFormat.MMMEd(l10n.localeName);

    final shown = [
      for (final e in entries)
        if (devices[e.entityId] case final d
            when (d == null || !restricted.hides(d)) &&
                // Without a device we can't tell what a hidden kind is.
                (d != null || restricted.hiddenKinds.isEmpty) &&
                _matches(_filter, d, e.entityId))
          (e, d),
    ].take(200).toList();

    if (shown.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: Text(
            l10n.activityEmpty,
            key: const Key('activityEmpty'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final (e, d) = shown[i];
          final when = DateUtils.dateOnly(e.when) == today
              ? time.format(e.when)
              : '${day.format(e.when)} ${time.format(e.when)}';
          final what = e.state != null
              ? historyStateLabel(l10n, e.state!, d?.kind)
              : (e.message ?? '');
          return ListTile(
            key: ValueKey('activity-$i'),
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              child: Icon(
                d == null ? Icons.history : DevicePresentation.icon(d),
                size: 20,
              ),
            ),
            title: Text(d?.name ?? e.name ?? e.entityId ?? ''),
            subtitle: Text(e.byUser ? '$what · ${l10n.activityByUser}' : what),
            trailing: Text(when, style: theme.textTheme.labelMedium),
            onTap: d == null
                ? null
                : () => context.push(AppRoutes.device(d.id)),
          );
        },
      ),
    );
  }
}
