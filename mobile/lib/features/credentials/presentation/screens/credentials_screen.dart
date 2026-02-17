import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/credentials/credentials_repository.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claves guardadas correctamente')),
      );
      context.go('/dashboard');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claves IronSource')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configura las credenciales de la Reporting API. '
                  'En IronSource ve a Mi cuenta → My Account y copia tu '
                  'Secret Key y Refresh Token.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                    labelText: 'Secret Key',
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
                    if (v == null || v.trim().isEmpty) return 'Introduce la Secret Key';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _refreshTokenController,
                  obscureText: _obscureRefresh,
                  decoration: InputDecoration(
                    labelText: 'Refresh Token',
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
                    if (v == null || v.trim().isEmpty) return 'Introduce el Refresh Token';
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
                      : const Text('Guardar y continuar'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Ir al dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
