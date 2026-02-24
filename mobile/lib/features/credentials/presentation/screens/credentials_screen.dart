import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/credentials_updated_notifier.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/locale_notifier.dart';
import '../../../../core/theme/theme_mode_notifier.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../../dashboard/data/dashboard_repository.dart';

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretKeyController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  bool _obscureSecret = true;
  bool _obscureRefresh = true;
  bool _loading = false;
  String? _errorMessage;

  late final CredentialsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = CredentialsRepository();
    _loadStored();
    LocaleNotifier.valueNotifier.addListener(_onLocaleChanged);
    ThemeModeNotifier.valueNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStored() async {
    final c = await _repo.getCredentials();
    if (c != null && mounted) {
      _secretKeyController.text = c.secretKey;
      _refreshTokenController.text = c.refreshToken;
    }
  }

  @override
  void dispose() {
    LocaleNotifier.valueNotifier.removeListener(_onLocaleChanged);
    ThemeModeNotifier.valueNotifier.removeListener(_onThemeChanged);
    _secretKeyController.dispose();
    _refreshTokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _loading = true;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }
    try {
      await _repo.saveCredentials(
        _secretKeyController.text.trim(),
        _refreshTokenController.text.trim(),
      );
      if (!mounted) return;
      final valid = await DashboardRepository().validateCredentials();
      if (!mounted) return;
      if (!valid) {
        setState(() {
          _errorMessage = AppStrings.t('invalid_keys_config', LocaleNotifier.current);
          _loading = false;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('keys_saved', LocaleNotifier.current))),
      );
      CredentialsUpdatedNotifier.notify();
      context.go('/dashboard');
    } catch (e) {
      setState(() {
        _errorMessage = _isKeysError(e.toString())
            ? AppStrings.t('invalid_keys_config', LocaleNotifier.current)
            : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _goToDashboard() async {
    final hasCredentials = await _repo.hasCredentials();
    if (!hasCredentials || !mounted) return;
    setState(() {
      _errorMessage = null;
      _loading = true;
    });
    final valid = await DashboardRepository().validateCredentials();
    if (!mounted) return;
    setState(() => _loading = false);
    if (valid) {
      context.go('/dashboard');
    } else {
      setState(() => _errorMessage = AppStrings.t('invalid_keys_config', LocaleNotifier.current));
    }
  }

  static bool _isKeysError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('secret') ||
        lower.contains('refresh token') ||
        lower.contains('bearer') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid credentials') ||
        lower.contains('token');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleNotifier.valueNotifier,
      builder: (context, locale, _) => Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          title: Text(AppStrings.t('credentials_title', locale)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    AppStrings.t('config_instructions', locale),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _secretKeyController,
                  obscureText: _obscureSecret,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('secret_key', locale),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecret ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureSecret = !_obscureSecret),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppStrings.t('enter_secret_key', locale);
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _refreshTokenController,
                  obscureText: _obscureRefresh,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('refresh_token', locale),
                    prefixIcon: const Icon(Icons.refresh),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRefresh ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureRefresh = !_obscureRefresh),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppStrings.t('enter_refresh_token', locale);
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppStrings.t('save_continue', locale)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loading ? null : _goToDashboard,
                  child: Text(AppStrings.t('go_dashboard', locale)),
                ),
                const SizedBox(height: 32),
                _buildLanguageSection(locale),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildLanguageSection(String locale) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.08),
              cs.tertiary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t('language', locale),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'es',
                  label: Text(AppStrings.t('spanish', locale)),
                ),
                ButtonSegment<String>(
                  value: 'en',
                  label: Text(AppStrings.t('english', locale)),
                ),
              ],
              selected: {LocaleNotifier.current},
              onSelectionChanged: (Set<String> selected) {
                LocaleNotifier.set(selected.first);
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ThemeModeNotifier.current == ThemeMode.light
                      ? AppStrings.t('light_mode', locale)
                      : AppStrings.t('dark_mode', locale),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Switch.adaptive(
                  value: ThemeModeNotifier.current == ThemeMode.dark,
                  onChanged: (_) {
                    ThemeModeNotifier.set(
                      ThemeModeNotifier.current == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
