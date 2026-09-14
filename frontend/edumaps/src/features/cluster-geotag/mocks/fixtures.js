// src/features/cluster-geotag/mocks/fixtures.js
//
// Dados sintéticos para a página de clusterização por geotag.
// Os ids de cluster (1..3) espelham o contrato do GET /api/cluster/schools.

export const REGIONS_FIXTURE = [
  { co_regiao: 1, no_regiao: "Norte" },
  { co_regiao: 2, no_regiao: "Nordeste" },
  { co_regiao: 3, no_regiao: "Sudeste" },
  { co_regiao: 4, no_regiao: "Sul" },
  { co_regiao: 5, no_regiao: "Centro-Oeste" },
];

export const UFS_FIXTURE = [
  { co_uf: 11, sg_uf: "RO", no_uf: "Rondônia" },
  { co_uf: 12, sg_uf: "AC", no_uf: "Acre" },
  { co_uf: 13, sg_uf: "AM", no_uf: "Amazonas" },
  { co_uf: 14, sg_uf: "RR", no_uf: "Roraima" },
  { co_uf: 15, sg_uf: "PA", no_uf: "Pará" },
  { co_uf: 16, sg_uf: "AP", no_uf: "Amapá" },
  { co_uf: 17, sg_uf: "TO", no_uf: "Tocantins" },
];

export const MUNICIPALITIES_FIXTURE = [
  { co_municipio: 1200401, no_municipio: "Rio Branco" },
  { co_municipio: 1200203, no_municipio: "Cruzeiro do Sul" },
  { co_municipio: 1200336, no_municipio: "Feijó" },
];

// Recorte usado nos fixtures: região 1 (Norte) + UF 12 (AC).
export const FIXTURE_GEOTAG = { codigo_regiao: 1, codigo_uf: 12 };

export const CLUSTER_POLYGONS_FIXTURE = {
  type: "FeatureCollection",
  features: [
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [-67.811, -9.974] },
      properties: { co_entidade: 12000101, no_entidade: "ESC A", cluster_id: 1, latitude: -9.974, longitude: -67.811 },
    },
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [-67.823, -9.962] },
      properties: { co_entidade: 12000102, no_entidade: "ESC B", cluster_id: 1, latitude: -9.962, longitude: -67.823 },
    },
    {
      type: "Feature",
      geometry: { type: "Point", coordinates: [-68.021, -9.886] },
      properties: { co_entidade: 12000103, no_entidade: "ESC C", cluster_id: 2, latitude: -9.886, longitude: -68.021 },
    },
  ],
};