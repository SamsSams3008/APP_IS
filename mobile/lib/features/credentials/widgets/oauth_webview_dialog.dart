import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Diálogo con WebView para OAuth. Se cierra cuando [resultFuture] completa.
class OAuthWebViewDialog extends StatefulWidget {
  const OAuthWebViewDialog({
    super.key,
    required this.authUrl,
    required this.resultFuture,
  });

  final String authUrl;
  final Future<({String? refreshToken, String? publisherId})?> resultFuture;

  @override
  State<OAuthWebViewDialog> createState() => _OAuthWebViewDialogState();
}

class _OAuthWebViewDialogState extends State<OAuthWebViewDialog> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {},
          onPageFinished: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));

    widget.resultFuture.then((result) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Conectar con Google',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
