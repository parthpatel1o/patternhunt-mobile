import '../../core/models/models.dart';

const huntDemoPatternId = 'hunt-demo-pattern';

/// Public R2 URLs for CrochetwithPrachi’s Removable Shell Turtle (tutorial only).
const _demoImageBase =
    'https://pub-eb00171700b54f888da559db82db5457.r2.dev/patterns/a8e5fd23-7d94-4b78-8270-9e4a570e2324';

/// Practice card used only during the first-run gesture tutorial.
PatternCard createHuntDemoPattern() {
  return PatternCard(
    id: huntDemoPatternId,
    title: 'Removable Shell Turtle',
    slug: 'removable-shell-turtle-demo',
    imageUrls: const [
      '$_demoImageBase/cover-0.jpg',
      '$_demoImageBase/cover-1.jpg',
      '$_demoImageBase/cover-2.jpg',
      '$_demoImageBase/cover-3.jpg',
      '$_demoImageBase/cover-4.jpg',
    ],
    designerName: 'CrochetwithPrachi',
    patternUrl: null,
    isFree: false,
    hasPdf: false,
    voteCount: 1,
    voted: false,
    createdAt: '1970-01-01T00:00:00.000Z',
    isArchived: false,
    saved: false,
    allTimeRank: null,
  );
}

bool isHuntDemoPattern(PatternCard pattern) => pattern.id == huntDemoPatternId;
