import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  bool _hasValidCredentials = false;
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
    final (valid, _) = await DashboardRepository().validateCredentialsWithError();
    if (mounted) {
      if (c != null) {
        _secretKeyController.text = c.secretKey;
        _refreshTokenController.text = c.refreshToken;
      }
      if (applovin != null) _appLovinReportKeyController.text = applovin;
      setState(() {
        _admobConnected = admobOk;
        _hasValidCredentials = valid;
      });
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
      final (authUri, resultFuture, cancel) = AdMobOAuth.prepareOAuthFlow(
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
          onCancel: cancel,
        ),
      );
      if (mounted && result != null && result.refreshToken != null && result.refreshToken!.isNotEmpty) {
        await _repo.saveAdMobRefreshToken(result.refreshToken!);
        if (result.publisherId != null && result.publisherId!.isNotEmpty) {
          await _repo.saveAdMobPublisherId(result.publisherId!);
        }
        if (!mounted) return;
        setState(() {
          _admobConnected = true;
          _loading = false;
        });
        CredentialsUpdatedNotifier.notify();
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.t('admob_connected', LocaleNotifier.current))),
        );
        final navigator = GoRouter.of(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigator.go('/dashboard');
        });
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
      if (mounted) setState(() => _hasValidCredentials = true);
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

  InputDecoration _minimalDecoration(String label, {VoidCallback? onToggleObscure, bool obscure = true}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      floatingLabelStyle: const TextStyle(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: onToggleObscure != null
          ? IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 14,
                color: const Color(0xFF888888),
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleNotifier.valueNotifier,
      builder: (context, locale, _) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: _hasValidCredentials && Navigator.of(context).canPop(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            AppStrings.t('credentials_title', locale),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        20 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          KeyedSubtree(
                            key: _ironsourceKey,
                            child: _buildPanelSection(
                              context: context,
                              title: AppStrings.t('ironsource_section', locale),
                              hint: AppStrings.t('config_ironsource_hint', locale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _secretKeyController,
                                    obscureText: _obscureSecret,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: _minimalDecoration(
                                      AppStrings.t('secret_key', locale),
                                      onToggleObscure: () => setState(() => _obscureSecret = !_obscureSecret),
                                      obscure: _obscureSecret,
                                    ),
                                    validator: (v) => null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _refreshTokenController,
                                    obscureText: _obscureRefresh,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: _minimalDecoration(
                                      AppStrings.t('refresh_token', locale),
                                      onToggleObscure: () => setState(() => _obscureRefresh = !_obscureRefresh),
                                      obscure: _obscureRefresh,
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
                            child: _buildPanelSection(
                              context: context,
                              title: AppStrings.t('applovin_section', locale),
                              hint: AppStrings.t('config_applovin_hint', locale),
                              child: TextFormField(
                                controller: _appLovinReportKeyController,
                                obscureText: _obscureAppLovin,
                                style: const TextStyle(fontSize: 13),
                                decoration: _minimalDecoration(
                                  AppStrings.t('applovin_report_key', locale),
                                  onToggleObscure: () => setState(() => _obscureAppLovin = !_obscureAppLovin),
                                  obscure: _obscureAppLovin,
                                ),
                                validator: (v) => null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          KeyedSubtree(
                            key: _admobKey,
                            child: _buildPanelSection(
                              context: context,
                              title: AppStrings.t('admob_label', locale),
                              hint: AppStrings.t('config_admob_auto_hint', locale),
                              child: _admobConnected
                                  ? Row(
                                      children: [
                                        Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            AppStrings.t('admob_connected', locale),
                                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13),
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
                                          child: Text(AppStrings.t('admob_disconnect', locale), style: const TextStyle(fontSize: 13)),
                                        ),
                                      ],
                                    )
                                  : FilledButton(
                                      onPressed: _loading ? null : _connectAdMob,
                                      child: Text(AppStrings.t('admob_connect', locale)),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 24),
                          _buildLanguageSection(locale),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeModeNotifier.valueNotifier,
                  builder: (context, mode, _) => IconButton(
                    onPressed: () {
                      ThemeModeNotifier.set(
                        mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                    icon: Icon(
                      mode == ThemeMode.light ? LucideIcons.moon : LucideIcons.sun,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelSection({
    required BuildContext context,
    required String title,
    required String hint,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildLanguageSection(String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.t('language', locale),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            ButtonSegment<String>(value: 'es', label: Text(AppStrings.t('spanish', locale))),
            ButtonSegment<String>(value: 'en', label: Text(AppStrings.t('english', locale))),
          ],
          selected: {LocaleNotifier.current},
          onSelectionChanged: (Set<String> selected) => LocaleNotifier.set(selected.first),
        ),
      ],
    );
  }
}
