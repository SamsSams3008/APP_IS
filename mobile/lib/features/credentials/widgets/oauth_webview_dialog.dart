import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Diálogo con WebView para OAuth. Se cierra cuando [resultFuture] completa.
/// Si el usuario cierra sin completar, llamar [onCancel] para liberar el servidor.
class OAuthWebViewDialog extends StatefulWidget {
  const OAuthWebViewDialog({
    super.key,
    required this.authUrl,
    required this.resultFuture,
    this.onCancel,
  });

  final String authUrl;
  final Future<({String? refreshToken, String? publisherId})?> resultFuture;
  final VoidCallback? onCancel;

  @override
  State<OAuthWebViewDialog> createState() => _OAuthWebViewDialogState();
}

class _OAuthWebViewDialogState extends State<OAuthWebViewDialog> {
  late final WebViewController _controller;

  void _closeWithoutResult() {
    widget.onCancel?.call();
    // No pop aquí: resultFuture completará y el .then hará un solo pop.
  }

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeWithoutResult();
      },
      child: Dialog(
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
                      onPressed: _closeWithoutResult,
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
      ),
    );
  }
}
