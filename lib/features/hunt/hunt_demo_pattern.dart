import '../../core/models/models.dart';

const _demoIdPrefix = 'hunt-demo-';

const huntDemoPatternId = '${_demoIdPrefix}turtle';
const huntDemoPatternIdAlt = '${_demoIdPrefix}keychains';

const _demoR2Base =
    'https://pub-eb00171700b54f888da559db82db5457.r2.dev/patterns';

/// Public R2 image sets used only for the first-run gesture tutorial.
const _demoDeckSources = <({
  String id,
  String title,
  String slug,
  String designerName,
  String storageId,
  int imageCount,
})>[
  (
    id: huntDemoPatternId,
    title: 'Removable Shell Turtle',
    slug: 'removable-shell-turtle-demo',
    designerName: 'CrochetwithPrachi',
    storageId: 'a8e5fd23-7d94-4b78-8270-9e4a570e2324',
    imageCount: 5,
  ),
  (
    id: huntDemoPatternIdAlt,
    title: '16-in-1 Animal Keychains',
    slug: '16-in-1-animal-keychains-demo',
    designerName: 'CrochetwithPrachi',
    storageId: '8bcfbf07-e2cf-44d3-886c-6b4fcc97ad02',
    imageCount: 5,
  ),
];

List<String> _demoImageUrls(String storageId, int imageCount) {
  final base = '$_demoR2Base/$storageId';
  return [
    for (var i = 0; i < imageCount; i++) '$base/cover-$i.jpg',
  ];
}

PatternCard _toDemoPattern(
  ({
    String id,
    String title,
    String slug,
    String designerName,
    String storageId,
    int imageCount,
  }) source,
) {
  return PatternCard(
    id: source.id,
    title: source.title,
    slug: source.slug,
    imageUrls: _demoImageUrls(source.storageId, source.imageCount),
    designerName: source.designerName,
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

/// Practice cards used only during the first-run gesture tutorial.
List<PatternCard> createHuntDemoPatterns() =>
    _demoDeckSources.map(_toDemoPattern).toList(growable: false);

PatternCard createHuntDemoPattern() => createHuntDemoPatterns().first;

bool isHuntDemoPattern(PatternCard pattern) =>
    pattern.id.startsWith(_demoIdPrefix);
