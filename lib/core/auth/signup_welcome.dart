import 'package:shared_preferences/shared_preferences.dart';

const _pendingSignupWelcomeKey = 'pending_signup_welcome';

Future<void> markPendingSignupWelcome() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_pendingSignupWelcomeKey, true);
}

Future<bool> consumePendingSignupWelcome() async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getBool(_pendingSignupWelcomeKey) ?? false;
  if (pending) {
    await prefs.remove(_pendingSignupWelcomeKey);
  }
  return pending;
}
