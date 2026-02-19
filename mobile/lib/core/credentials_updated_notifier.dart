import 'package:flutter/foundation.dart';

/// Se notifica cuando el usuario guarda nuevas credenciales en Ajustes.
/// El dashboard (y cualquier pantalla con caché de API) debe escuchar y
/// invalidar caché + volver a cargar con las nuevas llaves.
class CredentialsUpdatedNotifier extends ChangeNotifier {
  CredentialsUpdatedNotifier._();

  static final CredentialsUpdatedNotifier instance = CredentialsUpdatedNotifier._();

  /// Llama después de guardar credenciales; el dashboard invalida caché y recarga.
  static void notify() {
    instance.notifyListeners();
  }
}
