// src/features/gestor/constants/osm.js
//
// Catálogos de POIs (espelham EduMaps::Services::OSM::Query::%PROFILES),
// limites do buffer e eventos da feature (emitidos no EventBus).
export const OSM_CATALOGS = [
  { id: "equipamentos_publicos", label: "Todos os equipamentos públicos" },
  { id: "transporte", label: "Transporte" },
  { id: "saude", label: "Saúde" },
  { id: "educacao", label: "Educação" },
  { id: "assistencia", label: "Assistência social" },
  { id: "cultura_lazer", label: "Cultura e lazer" },
  { id: "seguranca", label: "Segurança" },
  { id: "administracao", label: "Administração pública" },
];

export const OSM_DEFAULT_PROFILES = ["equipamentos_publicos"];
export const OSM_RAIO_MIN = 100;
export const OSM_RAIO_MAX = 10000;
export const OSM_RAIO_STEP = 100;
export const OSM_RAIO_DEFAULT = 1000;

// A partir de quantos dias os dados são considerados "recentes" (a UI pede
// confirmação antes de sobrescrever).
export const OSM_RECENT_DAYS = 7;

export const OSM_EVENTS = {
  START: "gestor/osm-pois-start",
  PROGRESS: "gestor/osm-pois-progress",
  DONE: "gestor/osm-pois-done",
  ERROR: "gestor/osm-pois-error",
};

// Paleta categórica (estável por hash do nome) — mesma cor na legenda e no mapa.
export const OSM_CATEGORY_PALETTE = [
  "#2563eb", "#dc2626", "#16a34a", "#d97706", "#7c3aed", "#0891b2",
  "#db2777", "#65a30d", "#ea580c", "#4f46e5", "#0d9488", "#b45309",
  "#9333ea", "#059669", "#e11d48", "#0284c7", "#a16207", "#6d28d9",
];

/** Cor estável de uma categoria (tag OSM) para legenda/marcador. */
export function categoryColor(category) {
  const key = String(category ?? "outros");
  let hash = 0;
  for (let i = 0; i < key.length; i += 1) {
    hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
  }
  return OSM_CATEGORY_PALETTE[hash % OSM_CATEGORY_PALETTE.length];
}

/** Rótulo legível de uma tag OSM: `amenity=bus_station` → "amenity: bus station". */
export function formatCategory(category) {
  if (!category) return "outros";
  return String(category).replace(/_/g, " ").replace(/=/g, ": ");
}

// Rótulos em português para as tags do catálogo curado
// (espelha EduMaps::Services::OSM::Query::%PROFILES).
export const OSM_CATEGORY_LABELS = {
  "highway=bus_stop": "Ponto de ônibus",
  "public_transport=platform": "Plataforma de transporte",
  "public_transport=station": "Estação de transporte",
  "railway=station": "Estação ferroviária",
  "railway=halt": "Parada ferroviária",
  "railway=tram_stop": "Parada de bonde",
  "railway=subway_entrance": "Entrada de metrô",
  "amenity=bus_station": "Terminal de ônibus",
  "amenity=ferry_terminal": "Terminal de balsa",
  "aeroway=aerodrome": "Aeródromo",
  "amenity=hospital": "Hospital",
  "amenity=clinic": "Clínica",
  "amenity=doctors": "Consultório médico",
  "amenity=dentist": "Consultório odontológico",
  "amenity=pharmacy": "Farmácia",
  "amenity=school": "Escola",
  "amenity=college": "Faculdade",
  "amenity=university": "Universidade",
  "amenity=kindergarten": "Educação infantil",
  "amenity=library": "Biblioteca",
  "amenity=social_facility": "Assistência social",
  "amenity=community_centre": "Centro comunitário",
  "amenity=nursing_home": "Casa de repouso",
  "leisure=park": "Parque",
  "leisure=playground": "Parquinho",
  "leisure=sports_centre": "Centro esportivo",
  "leisure=pitch": "Quadra",
  "amenity=theatre": "Teatro",
  "amenity=cinema": "Cinema",
  "amenity=arts_centre": "Centro cultural",
  "amenity=museum": "Museu",
  "amenity=police": "Polícia",
  "amenity=fire_station": "Corpo de bombeiros",
  "amenity=townhall": "Prefeitura",
  "amenity=courthouse": "Fórum",
  "amenity=post_office": "Correios",
  "office=government": "Órgão público",
};

/** Rótulo em PT de uma categoria (tag OSM); fallback formatado. */
export function categoryLabel(category) {
  if (!category) return "Outros";
  if (OSM_CATEGORY_LABELS[category]) return OSM_CATEGORY_LABELS[category];
  if (String(category).startsWith("healthcare=")) return "Serviço de saúde";
  return formatCategory(category);
}

/** Dias (fracionários) desde um timestamp ISO/Postgres; null se inválido. */
export function daysSince(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return (Date.now() - d.getTime()) / 86_400_000;
}

/** Formata um timestamp em data/hora pt-BR (ou null). */
export function formatUpdatedAt(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}
