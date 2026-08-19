/// What the bot said, plus outcome.
class ChatReply {
  const ChatReply({required this.text, this.wrote = false});

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      text: json['text'] as String? ?? '',
      wrote: json['wrote'] == true,
    );
  }

  final String text;

  /// True when the server really wrote.
  final bool wrote;
}

enum ChatAuthor { patient, bot }

/// One past line, as sent.
Map<String, dynamic> turnJson(ChatMessage message) => {
  'fromPatient': message.author == ChatAuthor.patient,
  'text': message.text,
};

/// One line in the transcript.
class ChatMessage {
  const ChatMessage.patient(this.text) : author = ChatAuthor.patient;

  const ChatMessage.bot(this.text) : author = ChatAuthor.bot;

  final ChatAuthor author;
  final String text;
}
