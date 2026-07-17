import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/app_colors.dart';

/// WebView. Réplica de WebViewActivity + content_webview.
///
/// - En la pestaña Web (rama /web) carga `https://www.climamania.com`.
/// - Puede recibir un `url` concreto (p. ej. una gestión o un PDF). Los PDF se
///   abren con el visor de Google Drive, igual que en Android.
/// - `standalone` añade barra propia con "volver" cuando se empuja como pantalla
///   (fuera del shell). En la pestaña va sin barra (la pone el shell).
class WebViewScreen extends StatefulWidget {
  final String url;
  final bool standalone;

  const WebViewScreen({
    super.key,
    this.url = 'https://www.climamania.com',
    this.standalone = false,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final target = widget.url.trim().isEmpty
        ? 'https://www.climamania.com'
        : widget.url.trim();
    final loadUrl = _looksLikePdf(target)
        ? 'https://drive.google.com/viewerng/viewer?embedded=1&url='
            '${Uri.encodeComponent(target)}'
        : target;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setBackgroundColor(AppColors.primaryLight)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted && p >= 100 && _loading) {
            setState(() => _loading = false);
          }
        },
        onPageStarted: (_) {
          if (mounted && !_loading) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(loadUrl));
  }

  bool _looksLikePdf(String url) {
    var clean = url.trim();
    if (clean.isEmpty) return false;
    final q = clean.indexOf('?');
    if (q >= 0) clean = clean.substring(0, q);
    return clean.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.border,
          ),
      ],
    );
    if (!widget.standalone) return body;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(
        title: const Text('Web'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}
