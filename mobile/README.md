# Ad Revenue Dashboard - For ironSource

App para ver tus estadísticas de IronSource: ingresas **Secret Key** y **Refresh Token**, y ves el dashboard con gráficas, filtros y tablas.

## Cómo ejecutar

Abre la terminal y ejecuta:

```bash
cd /Users/samuelsantoro/Documents/APP_IS/mobile
flutter pub get
flutter run
```

Si tienes varios dispositivos, elige el **simulador de iPhone** cuando Flutter pregunte (por ejemplo escribe el número que corresponda a "iPhone 16" o similar).

**Solo iPhone (simulador):**
```bash
flutter run -d "iPhone"
```

**Solo Android (emulador o dispositivo):**
```bash
flutter run -d android
```

## Uso

1. **Primera vez**: La app te lleva a la pantalla **Claves IronSource**.
2. Pega tu **Secret Key** y **Refresh Token** (IronSource → Mi cuenta → My Account).
3. Pulsa **Guardar y continuar**.
4. Entras al **dashboard**: tarjetas (ingresos, impresiones, eCPM, clicks), gráfica de ingresos por fecha, filtros (por app, tipo de anuncio, plataforma) y tabla de datos.
5. Para cambiar las claves: icono de engranaje en la barra superior → editas y guardas.

No hace falta Firebase ni cuentas de Google; todo funciona con tus claves de IronSource en el dispositivo.
