# Cómo activar la suscripción Pro (compras in-app)

La app ya tiene integrado el flujo de compra: botón "Comprar Pro" y "Restaurar compras" en la pestaña Suscripción. Para que funcione en dispositivos reales **tú debes crear el producto en cada tienda** y usar el mismo ID que la app espera.

## ID del producto en la app

En código está definido:

- **ID:** `adrev_dash_pro`

Ese mismo ID debe existir en App Store Connect (iOS) y en Google Play Console (Android). Si quieres usar otro ID, cámbialo en `lib/core/constants/app_constants.dart` en la constante `iapProProductId`.

---

## iOS (App Store Connect)

1. **Entra en** [App Store Connect](https://appstoreconnect.apple.com) → tu app → **Features** → **In-App Purchases**.

2. **Crea una suscripción:**
   - Pulsa **"+"** → elige **Auto-Renewable Subscription**.
   - **Reference Name:** por ejemplo "Pro".
   - **Product ID:** `adrev_dash_pro` (exactamente igual que en la app).
   - **Pricing:** elige precio y moneda (p. ej. mensual o anual).

3. **Configura el grupo de suscripción** (Subscription Group) si es la primera vez:
   - Crea un grupo (p. ej. "Premium") y asigna esta suscripción a ese grupo.

4. **Contratos y bancos:**
   - En **Agreements, Tax, and Banking** asegúrate de tener todo completado (contrato de pago, datos fiscales y bancarios). Sin esto las compras no se pueden probar en producción.

5. **Pruebas:**
   - Crea **Sandbox testers** en **Users and Access** → **Sandbox** para probar compras sin cobrar de verdad.

---

## Android (Google Play Console)

1. **Entra en** [Google Play Console](https://play.google.com/console) → tu app → **Monetize** → **Subscriptions** (o **Products** → **Subscriptions**).

2. **Crea una suscripción:**
   - **Create subscription**.
   - **Product ID:** `adrev_dash_pro` (el mismo que en la app).
   - **Name** y **Description:** lo que quieras (solo para la ficha en Play).
   - **Pricing:** define el precio y el periodo (mensual, anual, etc.).

3. **Activa la suscripción** cuando esté lista y publica los cambios (o inclúyela en una versión en revisión).

4. **Pruebas:**
   - Añade direcciones de email como **License testers** en **Setup** → **License testing** para probar sin cobrar.

---

## Resumen

| Qué hace la app | Qué tienes que hacer tú |
|-----------------|--------------------------|
| Mostrar "Comprar Pro" y "Restaurar compras" | Crear el producto **adrev_dash_pro** en cada tienda |
| Lanzar el flujo de compra al pulsar "Comprar Pro" | Configurar precios y periodos en cada tienda |
| Activar Pro al completar la compra o restaurar | Completar contratos/bancos (iOS) y activar la suscripción (Android) |
| Guardar el estado Pro en el dispositivo | — |

En **macOS / web** las compras no están disponibles; la app muestra un mensaje y el usuario puede seguir usando el **simulador de suscripción** en Ajustes para probar el plan Pro.
