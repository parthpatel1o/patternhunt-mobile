String slugify(String value) {
  final slug = value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  // Keep mobile creator URLs compatible with the web/API slug format.
  return slug.length > 48 ? slug.substring(0, 48) : slug;
}

String creatorPath(String name) {
  final slug = slugify(name);
  return slug.isEmpty ? '/creator/unknown' : '/creator/$slug';
}
