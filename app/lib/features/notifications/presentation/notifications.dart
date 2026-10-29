import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/notifications_provider.dart';

/// Dismisses through the documented `persistent_notification` services.
Future<void> _dismiss(WidgetRef ref, String? id) async {
  final api = ref.read(homeAssistantApiProvider);
  if (api == null) return;
  await api.callService(
    'persistent_notification',
    id == null ? 'dismiss_all' : 'dismiss',
    data: {'notification_id': ?id},
  );
}

/// Shown on the dashboard only while there are notifications.
class NotificationsBanner extends ConsumerWidget {
  const NotificationsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(haNotificationsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('notificationsBanner'),
        color: scheme.primaryContainer,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Badge.count(
            count: items.length,
            child: Icon(
              Icons.notifications_outlined,
              color: scheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            l10n.notificationsCount(items.length),
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          subtitle: Text(
            items.first.title ?? items.first.plainMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
          onTap: () => showNotificationsSheet(context),
        ),
      ),
    );
  }
}

Future<void> showNotificationsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NotificationsSheet(),
    );

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(haNotificationsProvider).value ?? const [];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        maxWidth: 720,
      ),
      child: Column(
        key: const Key('notificationsSheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.notificationsTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (items.length > 1)
                  TextButton(
                    key: const Key('notificationsDismissAll'),
                    onPressed: () => _dismiss(ref, null),
                    child: Text(l10n.notificationsDismissAll),
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(l10n.notificationsEmpty),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                for (final n in items)
                  Card(
                    key: ValueKey('notification-${n.id}'),
                    child: ListTile(
                      title: Text(n.title ?? l10n.notificationsTitle),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.plainMessage),
                          if (n.createdAt != null)
                            Text(
                              formatDateTime(l10n.localeName, n.createdAt!),
                              style: theme.textTheme.labelSmall,
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        key: ValueKey('dismiss-${n.id}'),
                        tooltip: l10n.notificationDismiss,
                        onPressed: () => _dismiss(ref, n.id),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
