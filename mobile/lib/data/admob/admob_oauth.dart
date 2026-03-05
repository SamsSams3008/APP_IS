import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Flujo OAuth 2.0 para AdMob API con PKCE.
/// Usa localhost como redirect. Web app requiere client_secret.
class AdMobOAuth {
  static const _authBase = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const _scope = 'https://www.googleapis.com/auth/admob.report';
  static const int _redirectPort = 8765;
  static const String _redirectPath = '/oauth2callback';

  static String get redirectUri =>
      'http://localhost:$_redirectPort$_redirectPath';

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Prepara el flujo OAuth. Retorna (authUri, future con refresh token).
  /// El future completa cuando el servidor recibe el callback. Web app requiere clientSecret.
  /// Resultado del flujo automático: refresh token y publisher ID.
  static (Uri authUri, Future<({String? refreshToken, String? publisherId})?> result) prepareOAuthFlow(
    String clientId, {
    String? clientSecret,
  }) {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final params = <String, String>{
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
    };
    final authUri = Uri.parse(_authBase).replace(queryParameters: params);

    HttpServer? server;
    final codeCompleter = Completer<String?>();

    Future<({String? refreshToken, String? publisherId})?> run() async {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);
        server!.listen((request) async {
          if (request.uri.path != _redirectPath) {
            request.response..statusCode = 404..write('Not found');
            await request.response.close();
            return;
          }
          final query = request.uri.queryParameters;
          final code = query['code'];
          final error = query['error'];
          final html = '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>AdMob</title></head>
<body style="font-family:sans-serif;text-align:center;padding:40px;">
<p style="color:green;font-size:18px;">Listo. Cerrando...</p>
<script>setTimeout(function(){ window.close(); }, 1500);</script>
</body></html>''';
          request.response
            ..headers.contentType = ContentType.html
            ..write(html);
          await request.response.close();
          if (!codeCompleter.isCompleted) {
            codeCompleter.complete(error != null ? null : code);
          }
        });

        final code = await codeCompleter.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () => null,
        );
        if (code == null || code.isEmpty) return null;

        final (accessToken, refreshToken) = await _exchangeCodeForTokens(
          code: code,
          clientId: clientId,
          clientSecret: clientSecret,
          codeVerifier: verifier,
        );
        if (refreshToken == null || refreshToken.isEmpty) return null;
        final publisherId = await _fetchFirstPublisherId(accessToken);
        return (refreshToken: refreshToken, publisherId: publisherId);
      } catch (_) {
        return null;
      } finally {
        await server?.close(force: true);
      }
    }

    return (authUri, run());
  }

  /// Obtiene el primer Publisher ID de la cuenta del usuario (accounts.list).
  static Future<String?> _fetchFirstPublisherId(String? accessToken) async {
    if (accessToken == null || accessToken.isEmpty) return null;
    final response = await http.get(
      Uri.parse('https://admob.googleapis.com/v1/accounts'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = json['account'] as List?;
    if (accounts == null || accounts.isEmpty) return null;
    final first = accounts.first;
    if (first is! Map<String, dynamic>) return null;
    final publisherId = first['publisherId'] as String?;
    if (publisherId != null && publisherId.trim().isNotEmpty) return publisherId.trim();
    final name = first['name'] as String?;
    if (name == null || name.isEmpty) return null;
    if (name.startsWith('accounts/')) return name.substring(9);
    return name;
  }

  /// Refresca el access token.
  static Future<String?> refreshAccessToken({
    required String clientId,
    required String refreshToken,
    String? clientSecret,
  }) async {
    final body = <String, String>{
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
    };
    if (clientSecret != null && clientSecret.trim().isNotEmpty) {
      body['client_secret'] = clientSecret.trim();
    }
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String?;
    return (accessToken != null && accessToken.isNotEmpty) ? accessToken : null;
  }

  static Future<(String?, String?)> _exchangeCodeForTokens({
    required String code,
    required String clientId,
    String? clientSecret,
    required String codeVerifier,
  }) async {
    final body = <String, String>{
      'code': code,
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
      'code_verifier': codeVerifier,
    };
    if (clientSecret != null && clientSecret.trim().isNotEmpty) {
      body['client_secret'] = clientSecret.trim();
    }
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );
    if (response.statusCode != 200) return (null, null);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    return (
      accessToken != null && accessToken.isNotEmpty ? accessToken : null,
      refreshToken != null && refreshToken.isNotEmpty ? refreshToken : null,
    );
  }
}
