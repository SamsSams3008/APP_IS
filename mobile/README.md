# IronSource Dashboard

App móvil en Flutter (Android e iOS) para ver estadísticas de monetización de IronSource: mismo tipo de métricas que el dashboard oficial, en app móvil y con vista resumida. Los datos se sincronizan en segundo plano y están siempre disponibles.

## Arquitectura (seria, con backend)

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  App Flutter│────▶│ Cloud Functions  │────▶│  IronSource │
│  (móvil)   │     │ (cron + getStats) │     │  Reporting  │
└─────────────┘     └────────┬─────────┘     └─────────────┘
       │                     │
       │                     ▼
       │             ┌──────────────┐
       └─────────────▶│  Firestore    │
         (Auth +     │ users/        │  ← credenciales por usuario
          getStats)  │ userStats/    │  ← estadísticas por usuario/día
                     └──────────────┘
```

- **Cron (cada 6 horas)**: una Cloud Function se ejecuta automáticamente, lee las credenciales IronSource de cada usuario desde Firestore, llama a la API de IronSource y guarda los datos en `userStats/{userId}/days/{fecha}`.
- **La app** ya no llama a IronSource directamente: pide los datos al backend con `getStats` (y opcionalmente dispara una sincronización con `requestSync`). Los usuarios siempre ven datos desde nuestra base, sin depender del límite de la API en tiempo real.
- **Firestore**: guarda credenciales por usuario (para el cron) y las estadísticas ya extraídas (para que la app las consulte cuando quiera).

## Estructura del proyecto

```
APP_IS/
├── mobile/                 # App Flutter
│   └── lib/
│       ├── data/
│       │   ├── backend/    # BackendStatsRepository (getStats, requestSync, getApplications)
│       │   ├── credentials/# CredentialsRepository (Firestore + secure storage)
│       │   └── ironsource/ # (solo por si se necesita en el futuro)
│       └── features/       # auth, credentials, dashboard, splash
├── functions/              # Firebase Cloud Functions (Node 20)
│   ├── index.js            # syncIronsourceStats (cron), getStats, requestSync, getApplications
│   └── package.json
├── firebase.json
└── firestore.rules
```

## Configuración

### 1. Flutter (mobile)

- Flutter SDK estable (ej. 3.22+).
- `cd mobile && flutter pub get`.

### 2. Firebase

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com).
2. Activa **Authentication** (Email/Password).
3. Crea una base de datos **Firestore**.
4. En la raíz del repo (`APP_IS/`):
   - `firebase login`
   - `firebase use <tu-project-id>`
   - Instala dependencias de functions: `cd functions && npm install`
   - Despliega functions: `firebase deploy --only functions`
   - Despliega reglas: `firebase deploy --only firestore:rules`
5. En la app Flutter (`mobile/`):
   - `flutterfire configure` (o añade a mano `google-services.json` y `GoogleService-Info.plist`).

### 3. Reglas de Firestore

El archivo `firestore.rules` en la raíz ya define:

- `users/{userId}`: solo el usuario autenticado puede leer/escribir (ahí se guardan las claves IronSource).
- `userStats/{userId}/...`: solo lectura para ese usuario; la escritura la hace solo el backend (Cloud Functions).

### 4. Claves IronSource

Cada usuario, en la app, introduce su **email** y **Secret Key** de la Reporting API de IronSource (Mi cuenta → Reporting API). Esas credenciales se guardan en Firestore (para que el cron las use) y también en el dispositivo.

## Cómo ejecutar

```bash
# Backend (una vez, o al cambiar functions)
cd functions && npm install && cd ..
firebase deploy --only functions

# App
cd mobile
flutter pub get
flutter run
```

## Funcionalidad

- **Auth**: registro e inicio de sesión (Firebase Auth).
- **Claves**: pantalla para guardar email y Secret Key de IronSource; se almacenan en Firestore y en el dispositivo.
- **Dashboard** (datos desde nuestro backend, no directamente de IronSource):
  - Rango de fechas: Hoy, Ayer, 7 / 30 / 90 días, personalizado.
  - Tarjetas: ingresos, impresiones, eCPM, clicks, completados.
  - Gráfica de ingresos por fecha.
  - Filtros: por app, tipo de anuncio, plataforma (todo aplicado en memoria sobre datos ya cargados).
  - Tabla detallada por fecha, ad unit, plataforma, país.
- **Sincronización**: el cron actualiza datos cada 6 horas; al abrir la app o al pulsar "Actualizar" se puede forzar una sincronización inmediata (`requestSync`) y luego se muestran los datos con `getStats`.

## Coste aproximado

- Firebase Auth: uso gratuito habitual.
- Firestore: lecturas/escrituras según uso; el cron escribe por usuario y por día.
- Cloud Functions: invocaciones del cron (cada 6 h) + llamadas a `getStats` / `requestSync` / `getApplications`. Plan Blaze para poder usar el cron y llamadas a APIs externas (IronSource).
