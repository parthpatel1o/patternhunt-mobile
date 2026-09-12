import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Only allow in-app relative paths for post-login redirects.
String? safeInternalPath(String? next) {
  if (next == null || next.isEmpty) return null;
  final decoded = Uri.decodeComponent(next);
  if (!decoded.startsWith('/') || decoded.startsWith('//')) return null;
  if (decoded.startsWith('/login')) return null;
  return decoded;
}

/// Login route that returns the user to [next] after auth.
String loginLocation({String? next}) {
  final safe = safeInternalPath(next);
  if (safe == null || safe == '/' || safe == '/profile') {
    return '/login';
  }
  return Uri(path: '/login', queryParameters: {'next': safe}).toString();
}

/// Login route that returns to the current location after auth.
String loginLocationFor(BuildContext context) {
  try {
    final uri = GoRouterState.of(context).uri;
    final next = uri.toString();
    // Already on login / profile auth — no useful return path.
    if (uri.path == '/login' || uri.path == '/profile') {
      return '/login';
    }
    return loginLocation(next: next);
  } catch (_) {
    return '/login';
  }
}
