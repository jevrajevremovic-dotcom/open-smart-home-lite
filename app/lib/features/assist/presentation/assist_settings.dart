import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../application/voice_providers.dart';

/// Settings → Assist: spoken answers and the phone's assistant.
class AssistSettings extends ConsumerWidget {
  const AssistSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ref.watch(speechOutputProvider).supported)
          SwitchListTile(
            key: const Key('assistSpeak'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_outlined),
            title: Text(l10n.assistSpeak),
            subtitle: Text(l10n.assistSpeakHint),
            value: ref.watch(assistSpeakProvider),
            onChanged: (v) => ref.read(assistSpeakProvider.notifier).set(v),
          ),
        if (ref.watch(assistLaunchProvider).supported)
          ListTile(
            key: const Key('assistDefault'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.assistant_outlined),
            title: Text(l10n.assistDefault),
            subtitle: Text(l10n.assistDefaultHint),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => ref
                .read(assistLaunchProvider)
                .openAssistantSettings()
                .catchError((Object _) {}),
          ),
      ],
    );
  }
}
