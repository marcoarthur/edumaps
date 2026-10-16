// src/features/gestor/mocks/influenciaFixtures.js
// MSW fixtures da área de influência materializada (clean.escola_influencia).
// O formato espelha EduMaps::Model::Influencia::status.

const CENTRO = { lng: -63.9, lat: -8.76 };

// Anel fechado aproximando um buffer de raio `m` (metros) em [lng, lat].
function ring(m) {
  const dLat = m / 111_320;
  const dLng = m / (111_320 * Math.cos((CENTRO.lat * Math.PI) / 180));
  const { lng, lat } = CENTRO;
  return [
    [lng - dLng, lat - dLat],
    [lng + dLng, lat - dLat],
    [lng + dLng, lat + dLat],
    [lng - dLng, lat + dLat],
    [lng - dLng, lat - dLat],
  ];
}

const COMPUTADO_EM = new Date(Date.now() - 3 * 86_400_000).toISOString();

function feature(raio_m) {
  return {
    type: "Feature",
    geometry: { type: "Polygon", coordinates: [ring(raio_m)] },
    properties: {
      raio_m,
      tier: "buffer",
      versao: "influencia-v1",
      // área real de um buffer circular, arredondada como no SQL
      area_km2: Number((Math.PI * (raio_m / 1000) ** 2).toFixed(4)),
      computado_em: COMPUTADO_EM,
    },
  };
}

export const INFLUENCIA_STATUS_FIXTURE = {
  co_entidade: 11000040,
  nu_ano_censo: 2025,
  computado: 1,
  versao: "influencia-v1",
  tier: "buffer",
  computado_em: COMPUTADO_EM,
  raios: [500, 1000, 2000],
  escola: {
    co_entidade: 11000040,
    nu_ano_censo: 2025,
    nome: "EMEIEF PEQUENOS TALENTOS",
    latitude: CENTRO.lat,
    longitude: CENTRO.lng,
  },
  geojson: {
    type: "FeatureCollection",
    features: [feature(500), feature(1000), feature(2000)],
  },
};
