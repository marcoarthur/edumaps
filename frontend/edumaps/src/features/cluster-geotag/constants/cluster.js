// src/features/cluster-geotag/constants/cluster.js
//
// Contratos e listas curadas usadas pela página de clusterização por geotag.
// Os nomes das features espelham colunas de clean.censo_escolas.

export const ALGORITHMS = [
  { value: "kmeans", label: "K-Means" },
  { value: "gmm", label: "Gaussian Mixture (GMM)" },
  { value: "dbscan", label: "DBSCAN" },
  { value: "spectral", label: "Spectral" },
];

// Recorte mínimo: região (1-5), UF (2 dígitos) e município (7 dígitos),
// seguindo a validação do Controller::Cluster.
export const GEO_HINTS = {
  regiao: "Código da região (1-5): Norte, Nordeste, Sudeste, Sul, Centro-Oeste",
  uf: "Código da UF com 2 dígitos (ex.: 35 = SP)",
  municipio: "Código do município (IBGE) com 7 dígitos (ex.: 3550308 = São Paulo)",
};

// Conjunto curado de indicadores do Censo Escolar usados como features
// padrão da clusterização. Os rótulos são exibidos na página.
export const DEFAULT_FEATURES = [
  { value: "qt_comp_portatil_aluno", label: "Computadores portáteis p/ aluno" },
  { value: "qt_desktop_aluno", label: "Desktops p/ aluno" },
  { value: "qt_tablet_aluno", label: "Tablets p/ aluno" },
  { value: "qt_salas_utilizadas", label: "Salas utilizadas" },
  { value: "qt_prof_pedagogia", label: "Profissionais de pedagogia" },
  { value: "qt_prof_gestao", label: "Profissionais de gestão" },
  { value: "qt_prof_servicos_gerais", label: "Profissionais de serviços gerais" },
  { value: "in_acessibilidade_rampas", label: "Acessibilidade: rampas" },
  { value: "in_acesso_internet_computador", label: "Internet via computador" },
  { value: "in_alimentacao", label: "Alimentação" },
  { value: "in_biblioteca", label: "Biblioteca" },
  { value: "in_laboratorio_informatica", label: "Laboratório de informática" },
];

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