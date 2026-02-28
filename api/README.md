# Backend Ask AI (Gemini)

La app envía aquí la pregunta y los datos; este backend llama a Gemini con tu API key y devuelve la respuesta. **La key nunca va en la app.**

## Desplegar en Vercel (gratis)

1. Instala Vercel CLI: `npm i -g vercel`
2. En la **raíz del proyecto** (donde está esta carpeta `api/`), ejecuta: `vercel`
3. Sigue los pasos (login si hace falta, nombre del proyecto).
4. En el dashboard de Vercel: **Project → Settings → Environment Variables**
   - Añade: `GEMINI_API_KEY` = tu clave de https://aistudio.google.com/apikey
5. Redeploy si ya habías desplegado antes (Deployments → ... → Redeploy).
6. Copia la URL de tu proyecto (ej. `https://tu-proyecto.vercel.app`).
7. En la app Flutter, en `mobile/lib/core/config/ask_ai_config.dart`, pon:
   ```dart
   const String kAskAiBackendUrl = 'https://tu-proyecto.vercel.app/api/ask-ai';
   ```

Con eso, todos los usuarios de la app usarán tu backend y no tendrán que meter ninguna API key.

## Alternativa: Firebase Functions

Si prefieres Firebase, crea una función HTTP que reciba `question` y `dataSummary`, llame a Gemini con la key en `functions.config().gemini.key` (o env), y devuelva `{ text }`. La app apuntaría a la URL de esa función en `kAskAiBackendUrl`.
