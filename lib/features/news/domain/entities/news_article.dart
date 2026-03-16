enum NewsInteractionType {
  impression,
  click,
  open,
  save,
  dismiss,
  share,
  markNotInterested,
}

extension NewsInteractionTypeX on NewsInteractionType {
  String get wireValue {
    switch (this) {
      case NewsInteractionType.impression:
        return 'impression';
      case NewsInteractionType.click:
        return 'click';
      case NewsInteractionType.open:
        return 'open';
      case NewsInteractionType.save:
        return 'save';
      case NewsInteractionType.dismiss:
        return 'dismiss';
      case NewsInteractionType.share:
        return 'share';
      case NewsInteractionType.markNotInterested:
        return 'mark_not_interested';
    }
  }
}

class NewsArticleEntity {
  const NewsArticleEntity({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.sourceBaseUrl,
    required this.canonicalUrl,
    required this.title,
    required this.summary,
    required this.publishedAt,
    this.content,
    this.authorName,
    this.imageUrl,
    this.language = 'english',
    this.category,
    this.safetyLevel = 'general',
    this.evidenceLevel,
    this.trustScore = 0,
    this.qualityScore = 0,
    this.topicCodes = const <String>[],
    this.targetRoles = const <String>[],
    this.targetGoals = const <String>[],
    this.targetLevels = const <String>[],
    this.relevanceReason,
    this.relevanceTags = const <String>[],
    this.rankingScore = 0,
    this.isSaved = false,
  });

  final String id;
  final String sourceId;
  final String sourceName;
  final String sourceBaseUrl;
  final String canonicalUrl;
  final String title;
  final String summary;
  final DateTime publishedAt;
  final String? content;
  final String? authorName;
  final String? imageUrl;
  final String language;
  final String? category;
  final String safetyLevel;
  final String? evidenceLevel;
  final double trustScore;
  final double qualityScore;
  final List<String> topicCodes;
  final List<String> targetRoles;
  final List<String> targetGoals;
  final List<String> targetLevels;
  final String? relevanceReason;
  final List<String> relevanceTags;
  final double rankingScore;
  final bool isSaved;

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  bool get isCaution => safetyLevel == 'caution';

  NewsArticleEntity copyWith({
    String? id,
    String? sourceId,
    String? sourceName,
    String? sourceBaseUrl,
    String? canonicalUrl,
    String? title,
    String? summary,
    DateTime? publishedAt,
    String? content,
    String? authorName,
    String? imageUrl,
    String? language,
    String? category,
    String? safetyLevel,
    String? evidenceLevel,
    double? trustScore,
    double? qualityScore,
    List<String>? topicCodes,
    List<String>? targetRoles,
    List<String>? targetGoals,
    List<String>? targetLevels,
    String? relevanceReason,
    List<String>? relevanceTags,
    double? rankingScore,
    bool? isSaved,
  }) {
    return NewsArticleEntity(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      sourceBaseUrl: sourceBaseUrl ?? this.sourceBaseUrl,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      publishedAt: publishedAt ?? this.publishedAt,
      content: content ?? this.content,
      authorName: authorName ?? this.authorName,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      category: category ?? this.category,
      safetyLevel: safetyLevel ?? this.safetyLevel,
      evidenceLevel: evidenceLevel ?? this.evidenceLevel,
      trustScore: trustScore ?? this.trustScore,
      qualityScore: qualityScore ?? this.qualityScore,
      topicCodes: topicCodes ?? this.topicCodes,
      targetRoles: targetRoles ?? this.targetRoles,
      targetGoals: targetGoals ?? this.targetGoals,
      targetLevels: targetLevels ?? this.targetLevels,
      relevanceReason: relevanceReason ?? this.relevanceReason,
      relevanceTags: relevanceTags ?? this.relevanceTags,
      rankingScore: rankingScore ?? this.rankingScore,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
