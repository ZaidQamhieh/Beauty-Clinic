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

  /// Editing a record doesn't overwrite it server-side - amend() appends a
  /// new row that supersedes the old one, so a session can have several
  /// records over time (an original plus each correction). Groups every
  /// record by session, newest [createdAt] first, so a caller can show the
  /// current one plus the rest as history - not just whichever the API
  /// happened to list last, since list order isn't a contract to lean on.
  /// Deduplicates by [id] first: a caller that fetches the same patient's
  /// records more than once (one visit among several, say) would otherwise
  /// have every genuine version counted again for each fetch, inflating
  /// "previous versions" with copies of the same record rather than actual
  /// edits.
  static Map<String, List<SessionRecord>> historyBySession(
    Iterable<SessionRecord> records,
  ) {
    final byId = <String, SessionRecord>{};
    for (final record in records) {
      byId[record.id] = record;
    }
    final bySession = <String, List<SessionRecord>>{};
    for (final record in byId.values) {
      (bySession[record.sessionId] ??= []).add(record);
    }
    for (final versions in bySession.values) {
      versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return bySession;
  }

  /// The current record per session - the first (newest) entry of
  /// [historyBySession], for callers that only need what's in effect now.
  static Map<String, SessionRecord> latestBySession(
    Iterable<SessionRecord> records,
  ) {
    return {
      for (final entry in historyBySession(records).entries)
        entry.key: entry.value.first,
    };
  }
}
