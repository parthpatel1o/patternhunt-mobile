String slugify(String value) {
  final slug = value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug;
}

String creatorPath(String name) {
  final slug = slugify(name);
  return slug.isEmpty ? '/creator/unknown' : '/creator/$slug';
}
