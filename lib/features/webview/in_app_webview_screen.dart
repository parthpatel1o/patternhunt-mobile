import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../core/theme/app_colors.dart';

class InAppWebViewScreen extends StatefulWidget {
  const InAppWebViewScreen({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final WebViewController _controller;
  Timer? _loadingTimeout;
  var _loading = true;
  var _progress = 0;
  String? _error;
  late final Uri? _initialUri;

  @override
  void initState() {
    super.initState();
    _initialUri = _normalizeUrl(widget.url);

    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
            _armLoadingTimeout();
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
            // Some sites never fire onPageFinished cleanly; stop the spinner once nearly done.
            if (progress >= 90) _finishLoading();
          },
          onPageFinished: (_) => _finishLoading(),
          onWebResourceError: (error) {
            // Ignore subframe / cancelled noise; only surface main-frame failures.
            if (error.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = error.description.isNotEmpty ? error.description : 'Failed to load page';
            });
            _loadingTimeout?.cancel();
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.isScheme('http') || uri.isScheme('https')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;

    final uri = _initialUri;
    if (uri == null) {
      _loading = false;
      _error = 'Invalid link';
    } else {
      _armLoadingTimeout();
      _controller.loadRequest(uri);
    }
  }

  void _armLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_loading) return;
      // Don't treat timeout as a hard error if content may already be visible.
      _finishLoading();
    });
  }

  void _finishLoading() {
    _loadingTimeout?.cancel();
    if (!mounted || !_loading) return;
    setState(() {
      _loading = false;
      _progress = 100;
    });
  }

  Uri? _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title?.trim().isNotEmpty == true ? widget.title! : 'Pattern',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress / 100,
              minHeight: 2,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.muted),
                          const SizedBox(height: 12),
                          Text(
                            'Couldn’t load this page',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                            textAlign: TextAlign.center,
                          ),
                          if (_initialUri != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _initialUri.toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              final uri = _initialUri;
                              if (uri == null) return;
                              setState(() {
                                _error = null;
                                _loading = true;
                                _progress = 0;
                              });
                              _armLoadingTimeout();
                              _controller.loadRequest(uri);
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
