import 'package:flutter/material.dart';
import '../../features/webview/in_app_webview_screen.dart';

Future<void> openInAppWebView(
  BuildContext context, {
  required String url,
  String? title,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => InAppWebViewScreen(url: url, title: title),
    ),
  );
}
