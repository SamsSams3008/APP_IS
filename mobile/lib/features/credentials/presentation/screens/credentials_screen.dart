import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/credentials_updated_notifier.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/locale_notifier.dart';
import '../../../../core/theme/theme_mode_notifier.dart';
import '../../../../core/config/admob_oauth_credentials.dart';
import '../../../../data/admob/admob_oauth.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../widgets/oauth_webview_dialog.dart';
import '../../../dashboard/data/dashboard_repository.dart';

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretKeyController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _appLovinReportKeyController = TextEditingController();
  bool _obscureSecret = true;
  bool _obscureRefresh = true;
  bool _obscureAppLovin = true;
  bool _admobConnected = false;
  bool _loading = false;
  String? _errorMessage;

  late final CredentialsRepository _repo;
  final _ironsourceKey = GlobalKey();
  final _applovinKey = GlobalKey();
  final _admobKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _repo = CredentialsRepository();
    _loadStored();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final section = widget.initialSection;
      if (section != null && section.isNotEmpty) {
        _scrollToSection(section);
      }
    });
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
    final applovin = await _repo.getAppLovinReportKey();
    final admobOk = await _repo.hasAdMobCredentials();
    if (mounted) {
      if (c != null) {
        _secretKeyController.text = c.secretKey;
        _refreshTokenController.text = c.refreshToken;
      }
      if (applovin != null) _appLovinReportKeyController.text = applovin;
      setState(() => _admobConnected = admobOk);
    }
  }

  @override
  void dispose() {
    LocaleNotifier.valueNotifier.removeListener(_onLocaleChanged);
    ThemeModeNotifier.valueNotifier.removeListener(_onThemeChanged);
    _secretKeyController.dispose();
    _refreshTokenController.dispose();
    _appLovinReportKeyController.dispose();
    super.dispose();
  }

  Future<void> _connectAdMob() async {
    final clientId = kAdMobOAuthClientId.trim();
    final clientSecret = kAdMobOAuthClientSecret.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AdMob no configurado. El desarrollador debe añadir Client ID y Secret en lib/core/config/admob_oauth_credentials.dart')),
      );
      return;
    }
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (authUri, resultFuture) = AdMobOAuth.prepareOAuthFlow(
        clientId,
        clientSecret: clientSecret.isEmpty ? null : clientSecret,
      );
      if (!mounted) return;
      final result = await showDialog<({String? refreshToken, String? publisherId})?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => OAuthWebViewDialog(
          authUrl: authUri.toString(),
          resultFuture: resultFuture,
        ),
      );
      if (mounted && result != null && result.refreshToken != null && result.refreshToken!.isNotEmpty) {
        await _repo.saveAdMobRefreshToken(result.refreshToken!);
        if (result.publisherId != null && result.publisherId!.isNotEmpty) {
          await _repo.saveAdMobPublisherId(result.publisherId!);
          setState(() => _admobConnected = true);
          CredentialsUpdatedNotifier.notify();
          messenger.showSnackBar(
            SnackBar(content: Text(AppStrings.t('admob_connected', LocaleNotifier.current))),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se encontró ninguna cuenta de AdMob. ¿Tienes una en admob.google.com?')),
          );
        }
      } else if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la autorización. Intenta de nuevo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToSection(String section) {
    final key = switch (section.toLowerCase()) {
      'ironsource' => _ironsourceKey,
      'applovin' => _applovinKey,
      'admob' => _admobKey,
      _ => null,
    };
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
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
    final isInput = _secretKeyController.text.trim().isNotEmpty &&
        _refreshTokenController.text.trim().isNotEmpty;
    final alInput = _appLovinReportKeyController.text.trim().isNotEmpty;
    final admobInput = await _repo.hasAdMobCredentials();

    try {
      await _repo.saveCredentials(
        _secretKeyController.text.trim(),
        _refreshTokenController.text.trim(),
      );
      await _repo.saveAppLovinReportKey(_appLovinReportKeyController.text.trim());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;

    if (!isInput && !alInput && !admobInput) {
      setState(() {
        _errorMessage = AppStrings.t('need_at_least_one', LocaleNotifier.current);
        _loading = false;
      });
      CredentialsUpdatedNotifier.notify();
      return;
    }

    final dashRepo = DashboardRepository();
    bool ironSourceValid = false;
    bool appLovinValid = false;
    bool admobValid = false;
    final errors = <String>[];

    if (isInput) {
      ironSourceValid = await dashRepo.validateIronSource();
      if (!ironSourceValid) {
        await _repo.saveCredentials('', '');
        if (mounted) {
          _secretKeyController.text = '';
          _refreshTokenController.text = '';
        }
        errors.add(AppStrings.t('invalid_keys_config', LocaleNotifier.current));
      }
    }
    if (alInput) {
      appLovinValid = await dashRepo.validateAppLovin();
      if (!appLovinValid) {
        await _repo.saveAppLovinReportKey('');
        if (mounted) _appLovinReportKeyController.text = '';
        errors.add(AppStrings.t('invalid_applovin_config', LocaleNotifier.current));
      }
    }
    if (admobInput) {
      admobValid = await dashRepo.validateAdMob();
      if (!admobValid) {
        await _repo.clearAllAdMob();
        if (mounted) setState(() => _admobConnected = false);
        errors.add(AppStrings.t('invalid_admob_config', LocaleNotifier.current));
      }
    }

    if (!mounted) return;
    if (ironSourceValid || appLovinValid || admobValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('keys_saved', LocaleNotifier.current))),
      );
      CredentialsUpdatedNotifier.notify();
      if (context.mounted && Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    } else {
      setState(() {
        _errorMessage = errors.join(' ');
      });
      CredentialsUpdatedNotifier.notify();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleNotifier.valueNotifier,
      builder: (context, locale, _) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: Navigator.of(context).canPop(),
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
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    AppStrings.t('config_instructions', locale),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFBBDEFB),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                KeyedSubtree(
                  key: _ironsourceKey,
                  child: _buildIntegrationCard(
                    context: context,
                    title: AppStrings.t('ironsource_section', locale),
                    hint: AppStrings.t('config_ironsource_hint', locale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _secretKeyController,
                          obscureText: _obscureSecret,
                          decoration: InputDecoration(
                            labelText: AppStrings.t('secret_key', locale),
                            prefixIcon: const Icon(Icons.key),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                            ),
                          ),
                          validator: (v) => null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _refreshTokenController,
                          obscureText: _obscureRefresh,
                          decoration: InputDecoration(
                            labelText: AppStrings.t('refresh_token', locale),
                            prefixIcon: const Icon(Icons.refresh),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureRefresh ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureRefresh = !_obscureRefresh),
                            ),
                          ),
                          validator: (v) => null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _applovinKey,
                  child: _buildIntegrationCard(
                    context: context,
                    title: AppStrings.t('applovin_section', locale),
                    hint: AppStrings.t('config_applovin_hint', locale),
                    child: TextFormField(
                      controller: _appLovinReportKeyController,
                      obscureText: _obscureAppLovin,
                      decoration: InputDecoration(
                        labelText: AppStrings.t('applovin_report_key', locale),
                        prefixIcon: const Icon(Icons.bar_chart),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureAppLovin ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureAppLovin = !_obscureAppLovin),
                        ),
                      ),
                      validator: (v) => null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _admobKey,
                  child: _buildIntegrationCard(
                    context: context,
                    title: AppStrings.t('admob_label', locale),
                    hint: AppStrings.t('config_admob_auto_hint', locale),
                    child: _admobConnected
                        ? Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppStrings.t('admob_connected', locale),
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _repo.clearAllAdMob();
                                  if (mounted) {
                                    setState(() => _admobConnected = false);
                                    CredentialsUpdatedNotifier.notify();
                                  }
                                },
                                child: Text(AppStrings.t('admob_disconnect', locale)),
                              ),
                            ],
                          )
                        : FilledButton.icon(
                            onPressed: _loading ? null : _connectAdMob,
                            icon: const Icon(Icons.login, size: 18),
                            label: Text(AppStrings.t('admob_connect', locale)),
                          ),
                  ),
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

  Widget _buildIntegrationCard({
    required BuildContext context,
    required String title,
    required String hint,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
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
