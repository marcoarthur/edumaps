// src/features/admin/api/telemetryApi.js
//
// Espelha EduMaps::Plugin::API::Admin (base /api/admin/telemetry). Toda chamada
// da feature passa por aqui. Exige sessão de gestor com access_role = 'admin'.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/admin/telemetry";

/**
 * KPIs agregados do fluxo de acesso de sessão. Só agregados — nunca dado
 * pessoal (IP, texto digitado, sessão individual).
 * @param {string} window - 6h | 12h | 24h | hoje | 7d | 30d
 * @returns {Promise<{
 *   window: string, granularity: "hour"|"day", generated_at: string,
 *   logins: Record<string, number>,
 *   sessions: { active: number, logged: number, anonymous: number },
 *   searches: number, events: number,
 *   top_routes: Array<{ route: string, count: number, share_pct: number }>,
 *   series: Array<{ bucket: string, events: number, sessions: number }>,
 * }>}
 */
export function getTelemetryOverview(window = "24h") {
  return apiClient.get(`${BASE}/overview`, { window });
}
