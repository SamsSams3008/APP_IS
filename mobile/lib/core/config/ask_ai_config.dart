/// URL de tu backend para Ask AI. Si está vacía, la app usará la API key
/// guardada por el usuario (o pedirá una).
///
/// Cuando tengas el backend desplegado (p. ej. Vercel):
/// 1. Despliega api/ask-ai.js (ver README en /api o instrucciones en el propio archivo).
/// 2. Pon aquí la URL, por ejemplo: https://tu-proyecto.vercel.app/api/ask-ai
/// 3. Deja [kAskAiBackendUrl] con esa URL y los usuarios no tendrán que meter ninguna key.
const String kAskAiBackendUrl = 'https://app-is.vercel.app/api/ask-ai';

/// Token enviado en cada petición para validar origen. Debe coincidir con ASK_AI_APP_TOKEN
/// en Vercel (Environment Variables). Si no lo configuras en Vercel, el backend usa este valor por defecto.
const String kAskAiAppToken = 'adrev-dash-ai-2025-7f3b9c2e';
