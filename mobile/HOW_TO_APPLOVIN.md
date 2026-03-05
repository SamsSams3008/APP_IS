# Cómo usar AppLovin MAX en el Dashboard

## Modo demo (sin cuenta)

En el Report Key escribe `demo`, `test` o `hola`. La app mostrará datos de ejemplo con las 3 métricas de AppLovin: revenue, impresiones, eCPM.

## API de reportes (cuenta real)

AppLovin no ofrece una API de prueba pública. Necesitas una cuenta real en [dash.applovin.com](https://dash.applovin.com) para obtener el Report Key.

## Pasos para probar con cuenta real

1. **Crear cuenta** en [dash.applovin.com](https://dash.applovin.com) (gratuita).
2. **Añadir una app** (o usar la Demo App de MAX para generar tráfico de prueba).
3. **Obtener el Report Key**: Account → Keys → Report Key.
4. **Pegar el Report Key** en la pantalla de Credenciales de la app.

## Límites

- **Ventana máxima de fechas**: 45 días.
- **Métricas disponibles**: revenue, impressions, eCPM (las que todos los proveedores soportan se muestran; el resto se ocultan).

## Métricas AppLovin vs IronSource

| Métrica        | IronSource | AppLovin |
|----------------|------------|----------|
| Revenue        | ✅         | ✅       |
| Impressions    | ✅         | ✅       |
| eCPM           | ✅         | ✅       |
| Clicks         | ✅         | ❌       |
| Completions    | ✅         | ❌       |
| Fill rate      | ✅         | ❌       |
| Completion rate| ✅         | ❌       |
| CTR            | ✅         | ❌       |
| ...            |            |          |

Si configuras **solo AppLovin**, verás revenue, impressions y eCPM.  
Si configuras **IronSource + AppLovin**, solo se muestran esas tres (intersección).
