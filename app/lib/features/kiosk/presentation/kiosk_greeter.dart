import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/value_list.dart';
import '../../../core/platform/speech_output.dart';
import '../../dashboard/application/home_sentence.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/home_snapshot.dart';
import '../../household/application/household_providers.dart';
import '../../household/presentation/person_avatar.dart';
import '../application/kiosk_controller.dart';

/// When someone comes home (their person in Home Assistant becomes
/// `home`), the kiosk wakes and says hello.
class KioskGreeter extends ConsumerStatefulWidget {
  const KioskGreeter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskGreeter> createState() => _KioskGreeterState();
}

class _KioskGreeterState extends ConsumerState<KioskGreeter> {
  String? _person;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _greet(String personId) {
    final name = ref.read(deviceProvider(personId))?.name;
    if (name == null) return;
    _hide?.cancel();
    setState(() => _person = personId);
    _hide = Timer(const Duration(seconds: 20), _dismiss);
    if (ref.read(kioskDimmedProvider)) {
      ref.read(kioskDimmedProvider.notifier).set(false);
    }
    final speech = ref.read(speechOutputProvider);
    if (!speech.supported) return;
    final l10n = context.l10n;
    unawaited(
      speech
          .speak(l10n.welcomeHome(name), languageTag: l10n.localeName)
          .catchError((Object _) => false),
    );
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted && _person != null) setState(() => _person = null);
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(kioskSettingsProvider.select((s) => s.greetPeople)) &&
        ref.watch(kioskActiveProvider);
    if (enabled) {
      final people = ref.watch(peopleIdsProvider);
      ref.listen(
        // A value-equal list: only a change of someone's state notifies,
        // not every other device's update.
        homeSnapshotProvider.select(
          (s) => ValueList([
            for (final id in people) (id, s.devices[id]?.state.raw),
          ]),
        ),
        (before, now) {
          // Only real arrivals: not the first load or a reconnect.
          if (before == null ||
              ref.read(syncStatusProvider) != SyncStatus.live) {
            return;
          }
          final was = {for (final (id, state) in before) id: state};
          for (final (id, state) in now) {
            if (state == 'home' && was[id] != null && was[id] != 'home') {
              _greet(id);
              return;
            }
          }
        },
      );
    }
    final person = _person;
    return Stack(
      children: [
        widget.child,
        if (person != null)
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Center(
                child: Theme(
                  data: AppTheme.dark(),
                  child: _Welcome(personId: person, onClose: _dismiss),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.personId, required this.onClose});

  final String personId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = ref.watch(deviceProvider(personId))?.name ?? '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Material(
        key: const Key('kioskWelcome'),
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 12,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PersonAvatar(personId: personId, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.welcomeHome(name),
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          ref.watch(homeSentenceProvider(l10n)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('kioskWelcomeClose'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
