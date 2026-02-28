import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';

/// Pantalla de error con mensaje y botón de reintentar.
/// Si [isNetworkError] es true, muestra ícono wifi_off y mensaje de sin internet.
class ErrorRetryBody extends StatelessWidget {
  const ErrorRetryBody({
    super.key,
    required this.message,
    required this.onRetry,
    this.isNetworkError = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isNetworkError;

  static bool detectNetworkError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('network is unreachable') ||
        lower.contains('no internet');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isNetworkError
                  ? cs.outline.withValues(alpha: 0.3)
                  : cs.error.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isNetworkError ? cs.tertiary : cs.error).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  size: 48,
                  color: isNetworkError ? cs.tertiary : cs.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isNetworkError
                    ? AppStrings.t('no_internet', LocaleNotifier.current)
                    : message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(AppStrings.t('retry', LocaleNotifier.current)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
