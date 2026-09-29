// src/features/gestor/mocks/osmFixtures.js
export const OSM_POIS_STATUS_FIXTURE = {
  updated_at: null,
  raio: null,
  profiles: [],
  digest: null,
  total: 0,
  resumo: [],
};

// Status com dados "recentes" (< 7 dias) — a UI deve pedir confirmação.
export const OSM_POIS_STATUS_RECENT_FIXTURE = {
  updated_at: new Date(Date.now() - 2 * 86_400_000).toISOString(),
  raio: 1000,
  profiles: ["transporte"],
  digest: "abc123",
  total: 2,
  resumo: [
    { category: "amenity=bus_station", count: 1 },
    { category: "highway=bus_stop", count: 1 },
  ],
};

// Status com um job pendente/ativo (a UI deve travar e anexar).
export const OSM_POIS_STATUS_PENDING_JOB_FIXTURE = {
  updated_at: null,
  raio: null,
  profiles: [],
  total: 0,
  resumo: [],
  job_id: 42,
};
