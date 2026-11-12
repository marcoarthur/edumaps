// src/features/admin/mocks/telemetryFixtures.js
// Fixtures do painel de telemetria (compatíveis com o backend).

export const TELEMETRY_OVERVIEW = {
  window: "24h",
  granularity: "hour",
  generated_at: "2026-10-11T12:00:00+00",
  logins: { "6h": 2, "12h": 4, "24h": 7 },
  sessions: { active: 120, logged: 5, anonymous: 115 },
  searches: 34,
  events: 812,
  top_routes: [
    { route: "/escola/search", count: 145, share_pct: 40.5 },
    { route: "/", count: 88, share_pct: 27.0 },
    { route: "/privacidade", count: 44, share_pct: 13.5 },
  ],
  tours: [
    {
      tour_id: "busca-escola",
      started: 20,
      started_auto: 14,
      started_button: 5,
      started_link: 1,
      completed: 9,
      dismissed: 11,
      completion_pct: 45,
      top_dismiss_step: 3,
      total_steps: 7,
    },
    {
      tour_id: "painel-gestor",
      started: 0,
      started_auto: 0,
      started_button: 0,
      started_link: 0,
      completed: 0,
      dismissed: 2,
      completion_pct: null,
      top_dismiss_step: 2,
      total_steps: 8,
    },
  ],
  series: [
    { bucket: "2026-10-11T10:00", events: 90, sessions: 20 },
    { bucket: "2026-10-11T11:00", events: 130, sessions: 31 },
  ],
};

// Devolve uma cópia do overview com números distintos para a janela de 6h —
// usado para provar que trocar a janela refaz a consulta.
export function buildOverview(window) {
  const o = JSON.parse(JSON.stringify(TELEMETRY_OVERVIEW));
  o.window = window;
  if (window === "6h") {
    o.sessions = { active: 30, logged: 2, anonymous: 28 };
    o.searches = 8;
    o.events = 203;
    o.top_routes = [{ route: "/escola/search", count: 31, share_pct: 60 }];
    o.series = [{ bucket: "2026-10-11T11:00", events: 203, sessions: 30 }];
  } else if (window === "7d" || window === "30d") {
    o.granularity = "day";
    o.series = [
      { bucket: "2026-10-09", events: 400, sessions: 80 },
      { bucket: "2026-10-10", events: 500, sessions: 95 },
      { bucket: "2026-10-11", events: 300, sessions: 60 },
    ];
  }
  return o;
}
