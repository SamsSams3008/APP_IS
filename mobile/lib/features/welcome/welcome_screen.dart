import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/config/admob_oauth_credentials.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/credentials_updated_notifier.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';
import '../../data/admob/admob_oauth.dart';
import '../../data/credentials/credentials_repository.dart';
import '../credentials/widgets/oauth_webview_dialog.dart';
import '../dashboard/data/dashboard_repository.dart';

/// Pantalla de bienvenida / configuración: mismo panel, mismo diseño.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.fromSettings = false});

  /// true cuando se entra desde Ajustes (dashboard): muestra flecha atrás si hay credenciales.
  final bool fromSettings;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final CredentialsRepository _repo = CredentialsRepository();
  bool _hasAny = false;
  bool _hasIronSource = false;
  bool _hasAppLovin = false;
  bool _hasAdMob = false;

  static const Color _primary = Color(0xFF388BFD);

  @override
  void initState() {
    super.initState();
    _checkHasAny();
    CredentialsUpdatedNotifier.instance.addListener(_checkHasAny);
  }

  @override
  void dispose() {
    CredentialsUpdatedNotifier.instance.removeListener(_checkHasAny);
    super.dispose();
  }

  Future<void> _checkHasAny() async {
    final creds = await _repo.getCredentials();
    final applovin = await _repo.getAppLovinReportKey();
    final admob = await _repo.hasAdMobCredentials();
    final ok = (creds != null) || (applovin != null) || admob;
    if (mounted) {
      setState(() {
        _hasAny = ok;
        _hasIronSource = creds != null;
        _hasAppLovin = applovin != null && applovin.isNotEmpty;
        _hasAdMob = admob;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.onSurfaceVariant;
    return ValueListenableBuilder<String>(
      valueListenable: LocaleNotifier.valueNotifier,
      builder: (context, localeValue, _) {
        final locale = localeValue;
        final size = MediaQuery.of(context).size;
        final padding = size.width > 600 ? 48.0 : 24.0;
        return Scaffold(
      backgroundColor: bg,
      appBar: widget.fromSettings && _hasAny && Navigator.of(context).canPop()
          ? AppBar(
              backgroundColor: bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: textColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),
                // RevenueScope
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.2,
                        color: textColor,
                      ),
                      children: [
                        TextSpan(text: 'Revenue', style: TextStyle(color: _primary, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2)),
                        TextSpan(text: 'Scope', style: TextStyle(color: textColor, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Text(
                    AppStrings.t('welcome_choose_one', locale),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 3 botones: más estrechos, separados, centrados
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 280),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ExpandableNetworkButton(
                          network: 'ironsource',
                          label: AppStrings.t('ironsource_section', locale),
                          isConfigured: _hasIronSource,
                          onSaved: _checkHasAny,
                        ),
                        const SizedBox(height: 14),
                        _ExpandableNetworkButton(
                          network: 'applovin',
                          label: AppStrings.t('applovin_section', locale),
                          isConfigured: _hasAppLovin,
                          onSaved: _checkHasAny,
                        ),
                        const SizedBox(height: 14),
                        _ExpandableNetworkButton(
                          network: 'admob',
                          label: AppStrings.t('admob_label', locale),
                          isConfigured: _hasAdMob,
                          onSaved: _checkHasAny,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Continue - bien arriba, justo debajo de los botones
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _hasAny ? () => context.go('/dashboard') : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: theme.colorScheme.onPrimary,
                            disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            AppStrings.t('continue_label', locale),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
            // Idioma abajo izquierda
            Positioned(
              left: 16,
              bottom: 16,
              child: _LanguageSelector(),
            ),
            // Modo oscuro/claro abajo derecha
            Positioned(
              right: 16,
              bottom: 16,
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}

Widget _buildNetworkButton(BuildContext context, String label) {
  final color = Theme.of(context).colorScheme.onSurface;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    alignment: Alignment.center,
    child: Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    ),
  );
}

class _ExpandableNetworkButton extends StatefulWidget {
  const _ExpandableNetworkButton({
    required this.network,
    required this.label,
    required this.isConfigured,
    required this.onSaved,
  });

  final String network;
  final String label;
  final bool isConfigured;
  final VoidCallback onSaved;

  @override
  State<_ExpandableNetworkButton> createState() => _ExpandableNetworkButtonState();
}

class _ExpandableNetworkButtonState extends State<_ExpandableNetworkButton> {
  void _openPanel() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _NetworkConfigPanel(
                    network: widget.network,
                    onSaved: () {
                      Navigator.of(context).pop();
                      widget.onSaved();
                    },
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = widget.isConfigured ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: _openPanel,
        borderRadius: BorderRadius.circular(12),
        child: _buildNetworkButton(context, widget.label),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return ValueListenableBuilder<String>(
      valueListenable: LocaleNotifier.valueNotifier,
      builder: (context, current, _) {
        final locale = current;
        final label = current == 'es' ? AppStrings.t('spanish', locale) : AppStrings.t('english', locale);
        return PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          offset: const Offset(0, -80),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: color)),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 16, color: color),
            ],
          ),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'es', child: Text(AppStrings.t('spanish', locale), style: const TextStyle(fontSize: 14))),
            PopupMenuItem(value: 'en', child: Text(AppStrings.t('english', locale), style: const TextStyle(fontSize: 14))),
          ],
          onSelected: (v) => LocaleNotifier.set(v),
        );
      },
    );
  }
}

class _MinimalTextField extends StatelessWidget {
  const _MinimalTextField({
    required this.controller,
    required this.obscureText,
    required this.label,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscureText;
  final String label;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        floatingLabelStyle: const TextStyle(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          onPressed: onToggleObscure,
          icon: Icon(
            obscureText ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 14,
            color: const Color(0xFF888888),
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _NetworkConfigPanel extends StatefulWidget {
  const _NetworkConfigPanel({
    required this.network,
    required this.onSaved,
    this.onClose,
  });

  final String network;
  final VoidCallback onSaved;
  final VoidCallback? onClose;

  @override
  State<_NetworkConfigPanel> createState() => _NetworkConfigPanelState();
}

class _NetworkConfigPanelState extends State<_NetworkConfigPanel> {
  late final CredentialsRepository _repo;
  late final TextEditingController _secretController;
  late final TextEditingController _refreshController;
  late final TextEditingController _reportKeyController;
  bool _obscureSecret = true;
  bool _obscureRefresh = true;
  bool _obscureAppLovin = true;
  bool _loading = false;
  bool _admobConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = CredentialsRepository();
    _secretController = TextEditingController();
    _refreshController = TextEditingController();
    _reportKeyController = TextEditingController();
    _loadStored();
  }

  @override
  void dispose() {
    _secretController.dispose();
    _refreshController.dispose();
    _reportKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadStored() async {
    if (widget.network == 'ironsource') {
      final c = await _repo.getCredentials();
      if (mounted && c != null) {
        _secretController.text = c.secretKey;
        _refreshController.text = c.refreshToken;
      }
    } else if (widget.network == 'applovin') {
      final k = await _repo.getAppLovinReportKey();
      if (mounted && k != null) _reportKeyController.text = k;
    } else if (widget.network == 'admob') {
      final ok = await _repo.hasAdMobCredentials();
      if (mounted) setState(() => _admobConnected = ok);
    }
  }

  Future<void> _save() async {
    if (widget.network == 'admob' && !_admobConnected) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    final locale = LocaleNotifier.current;
    final dashRepo = DashboardRepository();
    bool success = false;

    try {
      if (widget.network == 'ironsource') {
        await _repo.saveCredentials(
          _secretController.text.trim(),
          _refreshController.text.trim(),
        );
        final ok = await dashRepo.validateIronSource();
        if (!ok) {
          await _repo.saveCredentials('', '');
          if (mounted) {
            _secretController.text = '';
            _refreshController.text = '';
            setState(() {
              _error = AppStrings.t('invalid_keys_config', locale);
              _loading = false;
            });
            return;
          }
        }
        success = true;
      } else if (widget.network == 'applovin') {
        await _repo.saveAppLovinReportKey(_reportKeyController.text.trim());
        final ok = await dashRepo.validateAppLovin();
        if (!ok) {
          await _repo.saveAppLovinReportKey('');
          if (mounted) {
            _reportKeyController.text = '';
            setState(() {
              _error = AppStrings.t('invalid_applovin_config', locale);
              _loading = false;
            });
            return;
          }
        }
        success = true;
      } else if (widget.network == 'admob') {
        final ok = await dashRepo.validateAdMob();
        if (!ok) {
          await _repo.clearAllAdMob();
          if (mounted) {
            setState(() {
              _admobConnected = false;
              _error = AppStrings.t('invalid_admob_config', locale);
              _loading = false;
            });
            return;
          }
        }
        success = true;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      CredentialsUpdatedNotifier.notify();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('keys_saved', locale))),
      );
      widget.onSaved();
    }
  }

  Future<void> _connectAdMob() async {
    final clientId = kAdMobOAuthClientId.trim();
    final clientSecret = kAdMobOAuthClientSecret.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AdMob no configurado.')),
      );
      return;
    }
    setState(() => _loading = true);
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
        setState(() => _admobConnected = true);
        CredentialsUpdatedNotifier.notify();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('admob_connected', LocaleNotifier.current))),
        );
        widget.onSaved();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _title {
    final l = LocaleNotifier.current;
    switch (widget.network) {
      case 'ironsource':
        return AppStrings.t('ironsource_section', l);
      case 'applovin':
        return AppStrings.t('applovin_section', l);
      case 'admob':
        return AppStrings.t('admob_label', l);
      default:
        return '';
    }
  }

  String get _hint {
    final l = LocaleNotifier.current;
    switch (widget.network) {
      case 'ironsource':
        return AppStrings.t('config_ironsource_hint', l);
      case 'applovin':
        return AppStrings.t('config_applovin_hint', l);
      case 'admob':
        return AppStrings.t('config_admob_auto_hint', l);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.current;
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width > 500 ? 440.0 : width - 32;
    return Container(
      width: panelWidth,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: título + cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              children: [
                Text(
                  _title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _hint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
                    const SizedBox(height: 16),
                  ],
                  if (widget.network == 'ironsource') ...[
                    _MinimalTextField(
                      controller: _secretController,
                      obscureText: _obscureSecret,
                      label: AppStrings.t('secret_key', locale),
                      onToggleObscure: () => setState(() => _obscureSecret = !_obscureSecret),
                    ),
                    const SizedBox(height: 14),
                    _MinimalTextField(
                      controller: _refreshController,
                      obscureText: _obscureRefresh,
                      label: AppStrings.t('refresh_token', locale),
                      onToggleObscure: () => setState(() => _obscureRefresh = !_obscureRefresh),
                    ),
                  ] else if (widget.network == 'applovin') ...[
                    _MinimalTextField(
                      controller: _reportKeyController,
                      obscureText: _obscureAppLovin,
                      label: AppStrings.t('applovin_report_key', locale),
                      onToggleObscure: () => setState(() => _obscureAppLovin = !_obscureAppLovin),
                    ),
                  ] else if (widget.network == 'admob') ...[
                    if (_admobConnected)
                      Row(
                        children: [
                          Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(AppStrings.t('admob_connected', locale), style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _repo.clearAllAdMob();
                              if (mounted) {
                                setState(() => _admobConnected = false);
                                CredentialsUpdatedNotifier.notify();
                                widget.onSaved();
                              }
                            },
                            child: Text(AppStrings.t('admob_disconnect', locale), style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _loading ? null : _connectAdMob,
                        icon: const Icon(LucideIcons.logIn, size: 18),
                        label: Text(AppStrings.t('admob_connect', locale)),
                      ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : (widget.network == 'admob' && !_admobConnected ? null : _save),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(AppStrings.t('save', locale)),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}
