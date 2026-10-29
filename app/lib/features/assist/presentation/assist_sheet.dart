import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/errors/app_failure.dart';
import '../../authentication/application/session_controller.dart';
import '../../timers/kiosk_timers.dart' show timerLabel;
import '../../timers/kitchen_timers.dart';
import '../application/voice_providers.dart';
import '../data/speech_output.dart';
import '../data/voice_input.dart';

/// Opens Assist: a short conversation with Home Assistant. [listen]
/// starts listening right away (opened as the phone's assistant).
Future<void> showAssist(BuildContext context, {bool listen = false}) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssistSheet(listenNow: listen),
    );

class _Message {
  const _Message(this.text, {required this.fromUser, this.error = false});

  final String text;
  final bool fromUser;
  final bool error;
}

class AssistSheet extends ConsumerStatefulWidget {
  const AssistSheet({super.key, this.listenNow = false});

  final bool listenNow;

  @override
  ConsumerState<AssistSheet> createState() => _AssistSheetState();
}

class _AssistSheetState extends ConsumerState<AssistSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  String? _conversationId;
  bool _busy = false;
  bool _listening = false;
  late final VoiceInput _voice = ref.read(voiceInputProvider);
  late final SpeechOutput _speech;
  late final AssistOpenController _open;

  @override
  void initState() {
    super.initState();
    // Read now: dispose() must not touch ref.
    _speech = ref.read(speechOutputProvider);
    // The kiosk wake word pauses while this sheet may use the microphone.
    _open = ref.read(assistOpenProvider.notifier);
    Future.microtask(_open.opened);
    if (widget.listenNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_listen());
      });
    }
  }

  /// Asks once whether online recognition is OK; `null` = cancelled.
  Future<bool?> _voicePrivacyChoice() async {
    final saved = ref.read(voiceCloudAllowedProvider);
    if (saved != null) return saved;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          icon: const Icon(Icons.mic_none),
          title: Text(l10n.voicePrivacyTitle),
          content: Text(l10n.voicePrivacyBody),
          actions: [
            TextButton(
              key: const Key('voiceAllowCloud'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.voiceAllowCloud),
            ),
            FilledButton(
              key: const Key('voiceOnDeviceOnly'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.voiceOnDeviceOnly),
            ),
          ],
        );
      },
    );
    if (choice != null) {
      await ref.read(voiceCloudAllowedProvider.notifier).set(choice);
    }
    return choice;
  }

  Future<void> _listen() async {
    final l10n = context.l10n;
    if (_listening) {
      await _voice.stop();
      return;
    }
    final cloud = await _voicePrivacyChoice();
    if (cloud == null || !mounted) return;
    setState(() => _listening = true);
    try {
      final text = await _voice.listen(
        languageTag: l10n.localeName,
        onDeviceOnly: !cloud,
        onText: (t) {
          if (mounted) _controller.text = t;
        },
      );
      if (!mounted) return;
      setState(() => _listening = false);
      // Asked by voice: answered by voice.
      await _send(text, speak: true);
    } on VoiceError catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      _messages.add(
        _Message(
          switch (e) {
            VoiceError.unavailable => l10n.voiceUnavailable,
            VoiceError.onDeviceUnavailable => l10n.voiceOnDeviceUnavailable,
            VoiceError.noMatch => l10n.voiceNoMatch,
            VoiceError.failed => l10n.voiceUnavailable,
          },
          fromUser: false,
          error: true,
        ),
      );
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    Future.microtask(_open.closed);
    if (_listening) unawaited(_voice.stop());
    if (_speech.supported) {
      unawaited(_speech.stop().catchError((Object _) {}));
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {bool speak = false}) async {
    final l10n = context.l10n;
    final trimmed = text.trim();
    final api = ref.read(homeAssistantApiProvider);
    if (trimmed.isEmpty || _busy) return;
    // Timers work without a connection; everything else needs HA.
    if (api == null && parseTimerCommand(trimmed) == null) return;
    setState(() {
      _messages.add(_Message(trimmed, fromUser: true));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();
    // Timers run on this device: Home Assistant is not asked.
    if (parseTimerCommand(trimmed) case final duration?) {
      await ref.read(kitchenTimersProvider.notifier).start(duration);
      final answer = l10n.timerStarted(timerLabel(duration));
      if (speak && _speech.supported && ref.read(assistSpeakProvider)) {
        unawaited(
          _speech
              .speak(answer, languageTag: l10n.localeName)
              .catchError((Object _) => false),
        );
      }
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(answer, fromUser: false));
        _busy = false;
      });
      _scrollToEnd();
      return;
    }
    try {
      final reply = await api!.processConversation(
        trimmed,
        language: assistLanguage(l10n.localeName, trimmed),
        conversationId: _conversationId,
      );
      _conversationId = reply.conversationId ?? _conversationId;
      if (speak &&
          reply.speech.isNotEmpty &&
          _speech.supported &&
          ref.read(assistSpeakProvider)) {
        unawaited(
          _speech
              .speak(reply.speech, languageTag: l10n.localeName)
              .catchError((Object _) => false),
        );
      }
      _messages.add(
        _Message(
          reply.speech.isEmpty
              ? (reply.isError ? l10n.assistNotUnderstood : '✓')
              : reply.speech,
          fromUser: false,
          error: reply.isError,
        ),
      );
    } on AppFailure catch (e) {
      _messages.add(
        _Message(failureMessage(l10n, e), fromUser: false, error: true),
      );
    } on Object {
      _messages.add(
        _Message(l10n.assistUnavailable, fromUser: false, error: true),
      );
    }
    if (mounted) setState(() => _busy = false);
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suggestions = [
      l10n.assistSuggestionLightsOff,
      l10n.assistSuggestionTemperature,
      l10n.assistSuggestionLightsOn,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          maxWidth: 720,
        ),
        child: Column(
          key: const Key('assistSheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.assistant_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.assistTitle, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_messages.isEmpty) ...[
                    Text(l10n.assistIntro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in suggestions)
                          ActionChip(label: Text(s), onPressed: () => _send(s)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.assistPrivacy,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  for (final m in _messages) _Bubble(message: m),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('assistInput'),
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: _listening
                            ? l10n.assistListening
                            : l10n.assistHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const Key('assistMic'),
                    tooltip: _listening ? l10n.assistListening : l10n.assistMic,
                    isSelected: _listening,
                    onPressed: _busy ? null : _listen,
                    icon: const Icon(Icons.mic_none),
                    selectedIcon: const Icon(Icons.mic),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('assistSend'),
                    tooltip: l10n.assistSend,
                    onPressed: _busy ? null : () => _send(_controller.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: user
              ? scheme.primary
              : message.error
              ? scheme.errorContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: user
                ? scheme.onPrimary
                : message.error
                ? scheme.onErrorContainer
                : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Language for Home Assistant's conversation agent. Serbian has two
/// grammars there: `sr` (Cyrillic) and `sr-Latn` (Latin); the text decides
/// (typed text is usually Latin, phone speech recognition often Cyrillic).
String assistLanguage(String localeName, String text) {
  if (!localeName.toLowerCase().startsWith('sr')) return localeName;
  return RegExp('[\u0400-\u04FF]').hasMatch(text) ? 'sr' : 'sr-Latn';
}
