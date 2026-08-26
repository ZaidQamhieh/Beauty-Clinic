class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.sessionId,
    required this.authorName,
    required this.note,
    required this.skinReaction,
    required this.followUpDate,
    required this.createdAt,
    required this.prescribedProductIds,
  });

  final String id;
  final String sessionId;
  final String? authorName;
  final String? note;
  final String? skinReaction;
  final String? followUpDate;
  final DateTime createdAt;
  final List<String> prescribedProductIds;

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: json['id'].toString(),
      sessionId: json['sessionId'].toString(),
      authorName: json['authorName']?.toString(),
      note: json['note']?.toString(),
      skinReaction: json['skinReaction']?.toString(),
      followUpDate: json['followUpDate']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      prescribedProductIds:
          ((json['prescribedProductIds'] as List?) ?? const [])
              .map((id) => id.toString())
              .toList(),
    );
  }
}
