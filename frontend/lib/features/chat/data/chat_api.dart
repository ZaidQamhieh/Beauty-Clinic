import 'package:dio/dio.dart';

import '../../../network/api_client.dart';
import 'chat_models.dart';

/// The bot could not answer this turn.
class ChatUnavailableException implements Exception {
  const ChatUnavailableException();
}

/// Talks to the chat endpoint.
class ChatApi {
  const ChatApi(this._client);

  static const messageLimit = 300;

  /// The server keeps the last thirty anyway.
  static const historyTurns = 30;

  final ApiClient _client;

  /// One turn; the caller owns the transcript.
  Future<ChatReply> send({
    required String message,
    List<ChatMessage> history = const [],
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/chat',
        data: {
          'message': message,
          'history': history
              .skip(
                history.length > historyTurns
                    ? history.length - historyTurns
                    : 0,
              )
              .map(turnJson)
              .toList(growable: false),
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const ChatUnavailableException();
      }
      return ChatReply.fromJson(data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      throw const ChatUnavailableException();
    }
  }
}
