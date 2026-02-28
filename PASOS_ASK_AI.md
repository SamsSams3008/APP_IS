# Ask AI: qué hacer tú (y qué pasarme)

**Vercel es gratis** para este uso (un backend pequeño).

---

## Lo que tienes que hacer

### 1. Sacar una API key de Gemini (gratis)
- Entra en: **https://aistudio.google.com/apikey**
- Inicia sesión con Google y crea una clave.
- **Cópiala** (la vas a usar en el paso 3).

### 2. Crear cuenta en Vercel (gratis)
- Entra en **https://vercel.com** y regístrate (con GitHub o email).

### 3. Instalar Vercel en el ordenador
- Abre la **terminal**.
- Ejecuta:  
  `npm i -g vercel`  
  (si no tienes Node, instálalo antes desde https://nodejs.org)

### 4. Subir el backend
- En la terminal, ve a la carpeta del proyecto (donde está la carpeta `api`):  
  `cd /Users/samuelsantoro/Documents/APP_IS`
- Ejecuta:  
  `vercel`
- Responde a lo que pregunte (login si pide, nombre del proyecto, etc.).
- Al terminar, Vercel te dará una **URL**, por ejemplo:  
  `https://tu-proyecto-xxx.vercel.app`

### 5. Poner tu API key de Gemini en Vercel
- Entra en **https://vercel.com** → tu proyecto.
- **Settings** → **Environment Variables**.
- Añade una variable:
  - **Name:** `GEMINI_API_KEY`
  - **Value:** la clave que copiaste en el paso 1
- Guarda y haz **Redeploy** del proyecto (pestaña Deployments → los tres puntos del último deploy → Redeploy).

### 6. Pasarme la URL
- La URL de tu API será:  
  **`https://tu-proyecto-xxx.vercel.app/api/ask-ai`**  
  (cambia `tu-proyecto-xxx` por lo que te haya salido).
- **Pásame esa URL completa** (por ejemplo: `https://mi-app-abc123.vercel.app/api/ask-ai`).

Yo la pondré en la app y Ask AI funcionará para todos los usuarios, sin que nadie tenga que meter ninguna API key.

---

## Resumen

| Paso | Qué haces |
|------|-----------|
| 1 | Crear API key en aistudio.google.com/apikey |
| 2 | Crear cuenta en vercel.com |
| 3 | En terminal: `npm i -g vercel` |
| 4 | En terminal: `cd` a la carpeta del proyecto y `vercel` |
| 5 | En Vercel: añadir variable `GEMINI_API_KEY` y redeploy |
| 6 | Pasarme la URL: `https://xxx.vercel.app/api/ask-ai` |

Cuando me pases la URL, la integro en la app y listo.
