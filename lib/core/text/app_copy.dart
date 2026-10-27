/// Single-sentence messages omit a final full stop; multi-sentence messages
/// keep sentence boundaries and end with punctuation.
/// Keeps dots inside URLs, email addresses, filenames, numbers, and ellipses.
String applySentencePunctuation(String message) {
  final fullStop = RegExp(r'(?<!\.)\.(?!\.)(?=\s|$)');
  final sentenceEnd = RegExp(r'(?<!\.)[.!?](?!\.)(?=\s|$)');
  final hasMultipleSentences = sentenceEnd
      .allMatches(message)
      .any((match) => message.substring(match.end).trim().isNotEmpty);
  if (!hasMultipleSentences) return message.replaceAll(fullStop, '');

  final text = message.trimRight();
  if (text.endsWith('.') ||
      text.endsWith('!') ||
      text.endsWith('?') ||
      text.endsWith('…')) {
    return message;
  }
  return '$text.${message.substring(text.length)}';
}
