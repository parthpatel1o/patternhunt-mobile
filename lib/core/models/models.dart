class PatternCard {
  final String id;
  final String title;
  final String slug;
  final List<String> imageUrls;
  final String designerName;
  final String? patternUrl;
  final bool isFree;
  final bool hasPdf;
  final int voteCount;
  final bool voted;
  final String createdAt;
  final bool isArchived;
  final bool saved;
  final int? allTimeRank;

  const PatternCard({
    required this.id,
    required this.title,
    required this.slug,
    required this.imageUrls,
    required this.designerName,
    required this.patternUrl,
    required this.isFree,
    required this.hasPdf,
    required this.voteCount,
    required this.voted,
    required this.createdAt,
    required this.isArchived,
    required this.saved,
    this.allTimeRank,
  });

  factory PatternCard.fromJson(Map<String, dynamic> json) {
    return PatternCard(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      imageUrls: (json['imageUrls'] as List<dynamic>).cast<String>(),
      designerName: json['designerName'] as String,
      patternUrl: json['patternUrl'] as String?,
      isFree: json['isFree'] as bool,
      hasPdf: json['hasPdf'] as bool,
      voteCount: json['voteCount'] as int,
      voted: json['voted'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      isArchived: json['isArchived'] as bool? ?? false,
      saved: json['saved'] as bool? ?? false,
      allTimeRank: json['allTimeRank'] as int?,
    );
  }

  PatternCard copyWith({
    int? voteCount,
    bool? voted,
    bool? saved,
  }) {
    return PatternCard(
      id: id,
      title: title,
      slug: slug,
      imageUrls: imageUrls,
      designerName: designerName,
      patternUrl: patternUrl,
      isFree: isFree,
      hasPdf: hasPdf,
      voteCount: voteCount ?? this.voteCount,
      voted: voted ?? this.voted,
      createdAt: createdAt,
      isArchived: isArchived,
      saved: saved ?? this.saved,
      allTimeRank: allTimeRank,
    );
  }
}

class PatternsPage {
  final List<PatternCard> patterns;
  final bool hasMore;
  final int? nextOffset;
  final bool loadingMore;

  const PatternsPage({
    required this.patterns,
    required this.hasMore,
    required this.nextOffset,
    this.loadingMore = false,
  });

  factory PatternsPage.fromJson(Map<String, dynamic> json) {
    return PatternsPage(
      patterns: (json['patterns'] as List<dynamic>)
          .map((e) => PatternCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] as bool? ?? false,
      nextOffset: json['nextOffset'] as int?,
    );
  }

  PatternsPage copyWith({
    List<PatternCard>? patterns,
    bool? hasMore,
    int? nextOffset,
    bool? loadingMore,
  }) {
    return PatternsPage(
      patterns: patterns ?? this.patterns,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class UserProfile {
  final String id;
  final String? displayName;
  final String role;
  final bool isPatternDesigner;
  final String? defaultCategorySlug;
  final String? email;
  final bool hasSubmittedPatterns;

  const UserProfile({
    required this.id,
    this.displayName,
    required this.role,
    required this.isPatternDesigner,
    this.defaultCategorySlug,
    this.email,
    this.hasSubmittedPatterns = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      role: json['role'] as String? ?? 'designer',
      isPatternDesigner: json['isPatternDesigner'] as bool? ?? false,
      defaultCategorySlug: json['defaultCategorySlug'] as String?,
      email: json['email'] as String?,
      hasSubmittedPatterns: json['hasSubmittedPatterns'] as bool? ?? false,
    );
  }
}

class BoardSummary {
  final String id;
  final String name;
  final String createdAt;

  const BoardSummary({required this.id, required this.name, required this.createdAt});

  factory BoardSummary.fromJson(Map<String, dynamic> json) {
    return BoardSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class BoardSaveOption extends BoardSummary {
  const BoardSaveOption({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.selected,
  });

  final bool selected;

  factory BoardSaveOption.fromJson(Map<String, dynamic> json) {
    return BoardSaveOption(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['createdAt'] as String,
      selected: json['selected'] as bool? ?? false,
    );
  }
}

class BoardWithPatterns {
  final BoardSummary board;
  final List<PatternCard> patterns;

  const BoardWithPatterns({required this.board, required this.patterns});

  factory BoardWithPatterns.fromJson(Map<String, dynamic> json) {
    return BoardWithPatterns(
      board: BoardSummary.fromJson(json['board'] as Map<String, dynamic>),
      patterns: (json['patterns'] as List<dynamic>)
          .map((e) => PatternCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CreatorProfile {
  final String? name;
  final List<PatternCard> patterns;
  final bool isFoundingMember;
  final Map<String, PatternBoardRanks> boardRanks;

  const CreatorProfile({
    required this.name,
    required this.patterns,
    this.isFoundingMember = false,
    this.boardRanks = const {},
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    final ranksRaw = json['boardRanks'];
    final ranks = <String, PatternBoardRanks>{};
    if (ranksRaw is Map) {
      for (final entry in ranksRaw.entries) {
        if (entry.value is Map<String, dynamic>) {
          ranks[entry.key.toString()] = PatternBoardRanks.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    }
    return CreatorProfile(
      name: json['name'] as String?,
      patterns: (json['patterns'] as List<dynamic>? ?? [])
          .map((e) => PatternCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFoundingMember: json['isFoundingMember'] as bool? ?? false,
      boardRanks: ranks,
    );
  }
}

class PatternBoardRanks {
  final int? all;
  final int? week;
  final int? month;

  const PatternBoardRanks({this.all, this.week, this.month});

  factory PatternBoardRanks.fromJson(Map<String, dynamic> json) {
    return PatternBoardRanks(
      all: json['all'] as int?,
      week: json['week'] as int?,
      month: json['month'] as int?,
    );
  }

  int? forPeriod(String period) {
    return switch (period) {
      'week' => week,
      'month' => month,
      _ => all,
    };
  }
}

class DesignerPatternInsight {
  final String id;
  final String title;
  final bool isFree;
  final bool hasPdf;
  final bool isArchived;
  final String createdAt;
  final String? imageUrl;
  final int voteCount;
  final int saveCount;
  final int viewClickCount;
  final int pdfDownloadCount;
  final PatternBoardRanks ranks;

  const DesignerPatternInsight({
    required this.id,
    required this.title,
    required this.isFree,
    required this.hasPdf,
    required this.isArchived,
    required this.createdAt,
    required this.imageUrl,
    required this.voteCount,
    required this.saveCount,
    required this.viewClickCount,
    required this.pdfDownloadCount,
    required this.ranks,
  });

  factory DesignerPatternInsight.fromJson(Map<String, dynamic> json) {
    return DesignerPatternInsight(
      id: json['id'] as String,
      title: json['title'] as String,
      isFree: json['isFree'] as bool? ?? false,
      hasPdf: json['hasPdf'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      voteCount: json['voteCount'] as int? ?? 0,
      saveCount: json['saveCount'] as int? ?? 0,
      viewClickCount: json['viewClickCount'] as int? ?? 0,
      pdfDownloadCount: json['pdfDownloadCount'] as int? ?? 0,
      ranks: PatternBoardRanks.fromJson(
        (json['ranks'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class DesignerInsights {
  final int profileViewCount;
  final int totalUpvotes;
  final int totalSaves;
  final int totalCtaClicks;
  final List<DesignerPatternInsight> patterns;

  const DesignerInsights({
    required this.profileViewCount,
    required this.totalUpvotes,
    required this.totalSaves,
    required this.totalCtaClicks,
    required this.patterns,
  });

  factory DesignerInsights.fromJson(Map<String, dynamic> json) {
    return DesignerInsights(
      profileViewCount: json['profileViewCount'] as int? ?? 0,
      totalUpvotes: json['totalUpvotes'] as int? ?? 0,
      totalSaves: json['totalSaves'] as int? ?? 0,
      totalCtaClicks: json['totalCtaClicks'] as int? ?? 0,
      patterns: (json['patterns'] as List<dynamic>? ?? [])
          .map((e) => DesignerPatternInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

