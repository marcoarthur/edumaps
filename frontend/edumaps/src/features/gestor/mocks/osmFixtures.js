// src/features/gestor/mocks/osmFixtures.js
export const OSM_POIS_STATUS_FIXTURE = {
  updated_at: null,
  raio: null,
  profiles: [],
  digest: null,
  total: 0,
  resumo: [],
  escola: null,
  geojson: { type: "FeatureCollection", features: [] },
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
  escola: {
    co_entidade: 11000040,
    nu_ano_censo: 2025,
    nome: "EMEIEF PEQUENOS TALENTOS",
    latitude: -8.76,
    longitude: -63.9,
  },
  geojson: {
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        geometry: { type: "Point", coordinates: [-63.901, -8.761] },
        properties: {
          osm_type: "node",
          osm_id: 1,
          category: "amenity=bus_station",
          nome: "Terminal Central",
          distance_m: 120,
        },
      },
      {
        type: "Feature",
        geometry: { type: "Point", coordinates: [-63.899, -8.759] },
        properties: {
          osm_type: "node",
          osm_id: 2,
          category: "highway=bus_stop",
          nome: "Parada da Praça",
          distance_m: 260,
        },
      },
    ],
  },
};

// Status com um job pendente/ativo (a UI deve travar e anexar).
export const OSM_POIS_STATUS_PENDING_JOB_FIXTURE = {
  updated_at: null,
  raio: null,
  profiles: [],
  total: 0,
  resumo: [],
  escola: null,
  geojson: { type: "FeatureCollection", features: [] },
  job_id: 42,
};
