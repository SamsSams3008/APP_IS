import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

const IRONSOURCE_STATS_URL =
  "https://platform.ironsrc.com/partners/publisher/mediation/applications/v5/stats";
const IRONSOURCE_APPS_URL =
  "https://platform.ironsrc.com/partners/publisher/applications/v3";
const USERS_COLLECTION = "users";
const USER_STATS_COLLECTION = "userStats";
const DAYS_SUBCOLLECTION = "days";

/**
 * Llama a la API de IronSource y devuelve las filas crudas para el rango de fechas.
 */
async function fetchIronSourceStats(email, secretKey, startDate, endDate) {
  const auth = Buffer.from(`${email}:${secretKey}`).toString("base64");
  const url = new URL(IRONSOURCE_STATS_URL);
  url.searchParams.set("startDate", startDate);
  url.searchParams.set("endDate", endDate);
  url.searchParams.set("breakdowns", "date,adUnits,appKey,country");
  url.searchParams.set("metrics", "revenue,impressions,eCPM,clicks,completions");

  const res = await fetch(url.toString(), {
    headers: { Authorization: `Basic ${auth}` },
  });
  if (!res.ok) {
    throw new Error(`IronSource API ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

/**
 * Convierte la respuesta de IronSource en filas planas para guardar en Firestore.
 */
function flattenRows(apiRows) {
  const rows = [];
  for (const row of apiRows || []) {
    const date = row.date || "";
    const adUnits = row.adUnits ?? null;
    const appKey = row.appKey ?? null;
    const country = row.country ?? null;
    const platform = row.platform ?? null;
    for (const d of row.data || []) {
      rows.push({
        date,
        adUnits,
        appKey,
        country,
        platform,
        revenue: typeof d.revenue === "number" ? d.revenue : 0,
        impressions: typeof d.impressions === "number" ? d.impressions : 0,
        eCPM: typeof d.eCPM === "number" ? d.eCPM : 0,
        clicks: typeof d.clicks === "number" ? d.clicks : 0,
        completions: typeof d.completions === "number" ? d.completions : 0,
      });
    }
  }
  return rows;
}

/**
 * Sincroniza las estadísticas de IronSource para un usuario y las guarda en Firestore.
 */
async function syncUserStats(userId, email, secretKey) {
  const today = new Date();
  const start = new Date(today);
  start.setDate(start.getDate() - 2);
  const startStr = start.toISOString().slice(0, 10);
  const endStr = today.toISOString().slice(0, 10);

  const apiRows = await fetchIronSourceStats(email, secretKey, startStr, endStr);
  const rows = flattenRows(apiRows);

  const byDate = {};
  for (const r of rows) {
    if (!r.date) continue;
    if (!byDate[r.date]) byDate[r.date] = [];
    byDate[r.date].push(r);
  }

  const batch = db.batch();
  for (const [date, dayRows] of Object.entries(byDate)) {
    const ref = db
      .collection(USER_STATS_COLLECTION)
      .doc(userId)
      .collection(DAYS_SUBCOLLECTION)
      .doc(date);
    batch.set(ref, { date, rows: dayRows }, { merge: true });
  }
  await batch.commit();
}

/**
 * Cron: cada 6 horas sincroniza los datos de IronSource de todos los usuarios
 * que tienen credenciales guardadas.
 */
export const syncIronsourceStats = onSchedule(
  {
    schedule: "0 */6 * * *",
    timeZone: "UTC",
  },
  async () => {
    const usersSnap = await db.collection(USERS_COLLECTION).get();
    for (const doc of usersSnap.docs) {
      const data = doc.data();
      const email = data.ironsourceEmail;
      const secret = data.ironsourceSecret;
      if (!email || !secret) continue;
      try {
        await syncUserStats(doc.id, email, secret);
      } catch (err) {
        console.error(`Sync failed for user ${doc.id}:`, err.message);
      }
    }
  }
);

/**
 * Callable: devuelve las estadísticas del usuario para el rango y filtros dados.
 * Lee de Firestore (datos ya sincronizados por el cron).
 */
export const getStats = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = request.auth.uid;
    const { startDate, endDate, appKey, adUnits, country, platform } =
      request.data || {};

    if (!startDate || !endDate) {
      throw new HttpsError(
        "invalid-argument",
        "startDate y endDate son obligatorios."
      );
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    const allRows = [];

    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().slice(0, 10);
      const dayRef = db
        .collection(USER_STATS_COLLECTION)
        .doc(uid)
        .collection(DAYS_SUBCOLLECTION)
        .doc(dateStr);
      const daySnap = await dayRef.get();
      if (!daySnap.exists) continue;
      const dayData = daySnap.data();
      const rows = dayData?.rows || [];
      for (const r of rows) {
        if (appKey != null && r.appKey !== appKey) continue;
        if (adUnits != null && !matchAdUnit(r.adUnits, adUnits)) continue;
        if (country != null && r.country !== country) continue;
        if (platform != null && r.platform !== platform) continue;
        allRows.push(r);
      }
    }

    let revenue = 0;
    let impressions = 0;
    let clicks = 0;
    let completions = 0;
    for (const r of allRows) {
      revenue += r.revenue || 0;
      impressions += r.impressions || 0;
      clicks += r.clicks || 0;
      completions += r.completions || 0;
    }
    const ecpm = impressions > 0 ? (revenue / impressions) * 1000 : 0;

    const byDate = {};
    for (const r of allRows) {
      const d = r.date || "";
      byDate[d] = (byDate[d] || 0) + (r.revenue || 0);
    }
    const chartData = Object.entries(byDate)
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, value]) => ({ date, value }));

    return {
      stats: {
        revenue,
        impressions,
        ecpm,
        clicks,
        completions,
      },
      chartData,
      tableRows: allRows,
    };
  }
);

function matchAdUnit(rowAdUnit, filterAdUnit) {
  if (!rowAdUnit) return false;
  const normalized = String(rowAdUnit).toLowerCase().replace(/\s/g, "");
  const f = String(filterAdUnit).toLowerCase();
  if (normalized.includes(f) || f.includes(normalized)) return true;
  if (filterAdUnit === "rewardedVideo" && normalized.includes("rewarded"))
    return true;
  return false;
}

/**
 * Callable: devuelve la lista de aplicaciones del usuario en IronSource (para el filtro por app).
 */
export const getApplications = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = request.auth.uid;
    const userDoc = await db.collection(USERS_COLLECTION).doc(uid).get();
    if (!userDoc.exists) return [];
    const { ironsourceEmail, ironsourceSecret } = userDoc.data();
    if (!ironsourceEmail || !ironsourceSecret) return [];

    const auth = Buffer.from(`${ironsourceEmail}:${ironsourceSecret}`).toString("base64");
    const res = await fetch(IRONSOURCE_APPS_URL, {
      headers: { Authorization: `Basic ${auth}` },
    });
    if (!res.ok) return [];
    const body = await res.json();
    const list = Array.isArray(body) ? body : body ? [body] : [];
    return list.map((app) => ({
      appKey: app.appKey,
      appName: app.appName || app.application_name,
      platform: app.platform,
      bundleId: app.bundleId || app.bundle_id,
    }));
  }
);

/**
 * Callable: el usuario puede forzar una sincronización "ahora" para su cuenta.
 * Útil al abrir la app o al pulsar "Actualizar".
 */
export const requestSync = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = request.auth.uid;
    const userDoc = await db.collection(USERS_COLLECTION).doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("failed-precondition", "Configura tus claves IronSource en Ajustes.");
    }
    const { ironsourceEmail, ironsourceSecret } = userDoc.data();
    if (!ironsourceEmail || !ironsourceSecret) {
      throw new HttpsError("failed-precondition", "Configura tus claves IronSource en Ajustes.");
    }
    await syncUserStats(uid, ironsourceEmail, ironsourceSecret);
    return { ok: true };
  }
);
