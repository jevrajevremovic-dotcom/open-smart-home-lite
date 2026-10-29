import 'package:flutter/foundation.dart';

/// Answer of `POST /api/conversation/process` (Assist).
@immutable
class HaConversationReply {
  const HaConversationReply({
    required this.speech,
    required this.type,
    this.conversationId,
  });

  /// What Assist says back (plain text).
  final String speech;

  /// `action_done`, `query_answer` or `error`.
  final String type;

  /// Pass back to continue the same conversation.
  final String? conversationId;

  bool get isError => type == 'error';

  static HaConversationReply parse(Object? json) {
    final body = json is Map ? json : const {};
    final response = body['response'] is Map
        ? body['response'] as Map
        : const {};
    final speech = response['speech'] is Map
        ? response['speech'] as Map
        : const {};
    final plain = speech['plain'] is Map ? speech['plain'] as Map : const {};
    return HaConversationReply(
      speech: plain['speech'] is String ? plain['speech']! as String : '',
      type: response['response_type'] is String
          ? response['response_type']! as String
          : 'error',
      conversationId: body['conversation_id'] is String
          ? body['conversation_id']! as String
          : null,
    );
  }
}
