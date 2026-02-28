/**
 * Backend mínimo para Ask AI: la app envía pregunta + datos, aquí se llama a Gemini
 * y se devuelve la respuesta. La API key de Gemini NUNCA va en la app.
 *
 * Despliegue en Vercel (gratis):
 * 1. Sube esta carpeta /api a un repo o ejecuta "vercel" en la raíz del proyecto.
 * 2. En Vercel → Project Settings → Environment Variables: GEMINI_API_KEY = tu key de aistudio.google.com/apikey
 * 3. La URL será https://tu-proyecto.vercel.app/api/ask-ai
 * 4. En la app Flutter, pon esa URL en lib/core/config/ask_ai_config.dart
 */

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'GEMINI_API_KEY not configured' });
  }

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch (_) {
    return res.status(400).json({ error: 'Invalid JSON' });
  }

  const { question, dataSummary } = body;
  if (!question || typeof question !== 'string') {
    return res.status(400).json({ error: 'Missing question' });
  }

  const data = dataSummary || 'No data provided.';
  const prompt = `You are a simple assistant inside a dashboard app. You may ONLY answer:
1) Basic factual questions: current time, date, day of week.
2) Questions about the following dashboard data.

For anything else (history, science, general knowledge, etc.) politely refuse: "I can only help with basics like the current time and questions about your dashboard data."

Answer in the same language as the user. Be very concise.\n\n--- Dashboard data ---\n${data}\n\n--- User question ---\n${question}`;

  try {
    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 512 },
        }),
      }
    );

    const json = await geminiRes.json();
    if (!geminiRes.ok) {
      const msg = json.error?.message || 'Gemini API error';
      const status = geminiRes.status;
      const isQuota = status === 429 || (msg && msg.toLowerCase().includes('quota'));
      const limitZero = msg && msg.includes('limit: 0');
      if (isQuota) {
        const hint = limitZero
          ? 'Your API key has no quota left (limit 0). Create a new key at aistudio.google.com/apikey or try again tomorrow.'
          : 'Too many requests. Wait a minute and try again.';
        return res.status(429).json({ error: hint });
      }
      return res.status(status).json({ error: msg });
    }

    const text = json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? 'No response.';
    return res.status(200).json({ text });
  } catch (e) {
    return res.status(500).json({ error: String(e.message) });
  }
};
