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
