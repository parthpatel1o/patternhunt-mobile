/// Resolves the public identity shown on a designer's own patterns.
String designerDisplayName({
  String? profileDisplayName,
  Map<String, dynamic>? userMetadata,
  String? email,
}) {
  String? usable(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  return usable(profileDisplayName) ??
      usable(userMetadata?['full_name']) ??
      usable(userMetadata?['name']) ??
      usable(email) ??
      'Pattern Hunt designer';
}
