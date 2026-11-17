// src/features/cluster-geotag/constants/cluster.js
//
// Contratos e listas curadas usadas pela página de clusterização por geotag.
// Os nomes das features espelham colunas de clean.censo_escolas.

export const ALGORITHMS = [
  { value: "kmeans", label: "K-Means", descricao: "Grupos de tamanho parecido, no número que você escolher." },
  { value: "gmm", label: "Mistura gaussiana (GMM)", descricao: "Grupos de formato livre, no número que você escolher." },
  { value: "dbscan", label: "DBSCAN", descricao: "Acha os grupos sozinho pela proximidade; escolas isoladas ficam de fora." },
  { value: "spectral", label: "Espectral", descricao: "Grupos em formas irregulares, no número que você escolher." },
];

// Recorte mínimo: região (1-5), UF (2 dígitos) e município (7 dígitos),
// seguindo a validação do Controller::Cluster.
export const GEO_HINTS = {
  regiao: "Código da região (1-5): Norte, Nordeste, Sudeste, Sul, Centro-Oeste",
  uf: "Código da UF com 2 dígitos (ex.: 35 = SP)",
  municipio: "Código do município (IBGE) com 7 dígitos (ex.: 3550308 = São Paulo)",
};

// Rótulos amigáveis das tabelas-fonte de clean.school_indicators
// (coluna table_name do GET /api/cluster/columns).
export const SOURCE_LABELS = {
  censo_escolas: "Censo Escolar",
  censo_docentes: "Docentes (Censo)",
  ideb_notas_escolas: "IDEB/SAEB",
};

export const SOURCE_TAG_COLORS = {
  censo_escolas: "bg-gray-100 text-gray-600",
  censo_docentes: "bg-emerald-50 text-emerald-700",
  ideb_notas_escolas: "bg-sky-50 text-sky-700",
};

// Rótulo de exibição de uma feature: usa o comment do banco quando existe
// (o metadado do censo/docentes/IDEB costuma descrever o indicador).
export function featureLabel({ column_name, comment }) {
  const label = (comment || "").trim();
  return label || formatColumnName(column_name);
}

// Fallback legível para colunas sem comentário (ex.: qt_doc_bas).
export function formatColumnName(name) {
  return String(name).replaceAll("_", " ");
}

// Paleta por cluster_id (ordem estável, independente de quantos clusters
// o algoritmo retornar). Índice 0 = fallback.
export const CLUSTER_COLORS = [
  "#64748b", // fallback / sem cor específica
  "#2563eb", // 1
  "#16a34a", // 2
  "#f59e0b", // 3
  "#7c3aed", // 4
  "#dc2626", // 5
  "#0d9488", // 6
  "#e11d48", // 7
  "#4f46e5", // 8
];

export function clusterColor(clusterId) {
  const id = Number(clusterId);
  return CLUSTER_COLORS[id] ?? CLUSTER_COLORS[0];
}

// Rótulo semântico do cluster (ex.: "Alta qualidade de infraestrutura"),
// com fallback para "Cluster N" quando o rótulo não foi gravado.
export function clusterLabel(label, clusterId) {
  const text = (label ?? "").trim();
  return text || `Cluster ${clusterId}`;
}
// #481 (RO-01): o IDEB/SAEB só se agrupa dentro de uma etapa. A escala do
// SAEB cresce com a série e o IDEB cai; a média entre as etapas da escola
// agrupava pela etapa oferecida. Espelha EduMaps::Presets.
export const IDEB_FEATURES = ["nota_media", "nota_matematica", "nota_portugues", "ideb_observado", "aprovacao_si_4"];

export const ETAPAS_IDEB = [
  { id: "anos_iniciais", label: "Anos iniciais do fundamental" },
  { id: "anos_finais", label: "Anos finais do fundamental" },
  { id: "ensino_medio", label: "Ensino médio" },
];

export const usaIdeb = (features = []) => features.some((f) => IDEB_FEATURES.includes(f));
