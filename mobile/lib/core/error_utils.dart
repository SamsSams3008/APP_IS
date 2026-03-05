/// Utilidades para clasificar errores de API/red.
class ErrorUtils {
  ErrorUtils._();

  static bool isNetworkError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('no internet') ||
        lower.contains('handshakeexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('connection failed');
  }

  static bool isKeysError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('secret') ||
        lower.contains('refresh token') ||
        lower.contains('bearer') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid credentials') ||
        lower.contains('configura secret') ||
        lower.contains('token vacío');
  }
}
