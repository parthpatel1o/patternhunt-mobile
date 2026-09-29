import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Keep the full location so filters and search terms survive a return from
/// Submit even though it lives in a separate navigation branch.
void openSubmit(BuildContext context) {
  final from = GoRouterState.of(context).uri.toString();
  context.go(Uri(path: '/submit', queryParameters: {'from': from}).toString());
}

String submitReturnLocation(Uri submitUri) {
  final from = submitUri.queryParameters['from'];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/profile';
  }
  final uri = Uri.tryParse(from);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path.startsWith('/submit') ||
      uri.path.startsWith('/login') ||
      uri.path.startsWith('/reset-password')) {
    return '/profile';
  }
  return from;
}
