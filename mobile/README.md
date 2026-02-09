# IronSource Dashboard

App móvil en Flutter (Android e iOS) para ver estadísticas de monetización de IronSource. Inicio de sesión, configuración de claves de la Reporting API, dashboard con gráficas, tablas y filtros por fecha, app, plataforma y tipo de anuncio.

## Estructura del proyecto

```
lib/
├── main.dart                 # Entrada, inicialización Firebase y Provider
├── app.dart                  # MaterialApp y router
├── core/
│   ├── constants/            # Constantes (URLs API, nombres)
│   ├── theme/                # Tema de la app
│   └── router/               # go_router y redirección por auth
├── data/
│   ├── credentials/          # Repositorio de claves IronSource (Firestore + secure storage)
│   └── ironsource/           # Cliente HTTP de la API IronSource (stats, aplicaciones)
├── features/
│   ├── auth/                 # Login, registro, AuthState (Firebase Auth)
│   ├── credentials/          # Pantalla para guardar email + Secret Key IronSource
│   ├── dashboard/             # Filtros, estadísticas, gráficas, tabla
│   │   ├── domain/           # DashboardFilters, DashboardStats
│   │   ├── data/             # DashboardRepository
│   │   └── presentation/     # DashboardScreen
│   └── splash/               # Splash y resolución de ruta inicial
└── shared/
    ├── utils/                # Formateo (dinero, números, fechas)
    └── widgets/              # StatCard y componentes reutilizables
```

## Configuración

### 1. Flutter

- Flutter SDK estable (ej. 3.22+).
- `flutter pub get` en la carpeta `mobile/`.

### 2. Firebase

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com).
2. Activa **Authentication** (método Email/Password).
3. Crea una base de datos **Firestore**.
4. En el proyecto Flutter:
   - Instala la CLI de FlutterFire: `dart pub global activate flutterfire_cli`
   - Ejecuta `flutterfire configure` en `mobile/` para generar la configuración por plataforma.
   - O añade manualmente:
     - **Android**: `android/app/google-services.json`
     - **iOS**: `ios/Runner/GoogleService-Info.plist`

### 3. Reglas de Firestore

En Firestore > Reglas, usa algo como:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Así cada usuario solo puede leer/escribir su propio documento (donde se guardan las claves IronSource).

### 4. Claves IronSource

Cada usuario debe configurar sus credenciales de la **Reporting API** de IronSource:

- **Email**: el mismo con el que entras en IronSource.
- **Secret Key**: en IronSource → Mi cuenta → Reporting API.

Esas credenciales se guardan en el dispositivo (almacenamiento seguro) y, si hay sesión Firebase, también en Firestore para sincronizar entre dispositivos.

## Cómo ejecutar

```bash
cd mobile
flutter pub get
flutter run
```

Para Android: `flutter run -d android`  
Para iOS: `flutter run -d ios`

## Funcionalidad

- **Auth**: registro e inicio de sesión con email y contraseña (Firebase Auth).
- **Claves**: pantalla de configuración para guardar email y Secret Key de IronSource.
- **Dashboard**:
  - Rango de fechas: Hoy, Ayer, 7 / 30 / 90 días, o rango personalizado.
  - Tarjetas de resumen: ingresos, impresiones, eCPM, clicks, completados.
  - Gráfica de ingresos por fecha.
  - Filtros: por app, tipo de anuncio (rewarded, interstitial, banner, offerwall), plataforma (Android/iOS).
  - Tabla con datos detallados por fecha, ad unit, plataforma, país, ingresos, impresiones, eCPM.

La API de IronSource tiene un límite de **20 peticiones cada 10 minutos**; los filtros y el pull-to-refresh consumen peticiones.
