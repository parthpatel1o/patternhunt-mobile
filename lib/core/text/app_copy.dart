/// Applies the app's punctuation style to messages received from services.
/// Keeps dots inside URLs, email addresses, filenames, numbers, and ellipses.
String withoutSentenceFullStops(String message) =>
    message.replaceAll(RegExp(r'(?<!\.)\.(?!\.)(?=\s|$)'), '');
