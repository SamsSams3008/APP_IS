# AdMob: configuración (solo el desarrollador, una vez)

Los **usuarios finales** no escriben nada: solo pulsan **Conectar AdMob** y autorizan con Google.

Tú, como desarrollador, debes configurar las credenciales OAuth **una vez** en el proyecto.

---

## Paso 1: Google Cloud Console

1. Entra en [Google Cloud Console](https://console.cloud.google.com).
2. Crea o elige un proyecto.
3. **APIs y servicios** → **Biblioteca** → busca **AdMob API** → **Activar**.
4. **Credenciales** → **+ Crear credenciales** → **ID de cliente de OAuth**.
5. **Tipo de aplicación:** **Aplicación web**.
6. Nombre: por ejemplo "Ad Revenue Dashboard".
7. En **URIs de redirección autorizados** añade:
   ```
   http://localhost:8765/oauth2callback
   ```
8. **Crear**. Copia el **Client ID** y el **Client Secret**.

---

## Paso 2: Poner las credenciales en la app

Abre `lib/core/config/admob_oauth_credentials.dart` y pega:

```dart
const String kAdMobOAuthClientId = 'TU_CLIENT_ID.apps.googleusercontent.com';
const String kAdMobOAuthClientSecret = 'TU_CLIENT_SECRET';
```

Guarda el archivo. Con eso queda configurado.

---

## Para los usuarios

En Ajustes solo verán la sección **AdMob** con el texto:

*"Pulsa abajo para conectar con tu cuenta de Google. No hace falta escribir nada."*

Al pulsar **Conectar AdMob** se abre la ventana de Google, autorizan y la app guarda el token y obtiene sola el Publisher ID. No tienen que pegar IDs ni secretos.
