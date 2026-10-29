import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/status_widgets.dart';
import '../application/device_providers.dart';
import '../data/home_state_repository.dart';
import 'device_presentation.dart';

/// Shown whenever the visible data is not live (loaded from the offline
/// cache, or the connection dropped), with the time it was last confirmed.
/// Cached data is never presented as current.
class StaleDataBanner extends ConsumerWidget {
  const StaleDataBanner({
    super.key,
    this.padding = const EdgeInsets.only(top: 8),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (status, syncedAt, hasData) = ref.watch(
      homeSnapshotProvider.select((s) => (s.status, s.lastSyncedAt, s.hasData)),
    );
    if (!hasData || status == SyncStatus.live || syncedAt == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final time = formatDateTime(l10n.localeName, syncedAt);
    return Padding(
      key: const Key('staleDataBanner'),
      padding: padding,
      child: InlineNotice.warning(
        status == SyncStatus.syncing
            ? l10n.dataUpdating(time)
            : l10n.dataStaleSince(time),
      ),
    );
  }
}
