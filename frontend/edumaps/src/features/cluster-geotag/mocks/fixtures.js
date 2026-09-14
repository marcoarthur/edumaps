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

// Fixture do backend GET /api/cluster/presets.
export const PRESETS_FIXTURE = [
  {
    id: "infraestrutura",
    name: "Infraestrutura escolar",
    description: "Água, energia, esgoto, banheiros, biblioteca, laboratórios, quadra, internet e acessibilidade",
    year_filter: 0,
    features: [
      "in_agua_potavel", "in_energia_rede_publica", "in_esgoto_rede_publica",
      "in_lixo_servico_coleta", "in_banheiro", "in_biblioteca",
      "in_laboratorio_ciencias", "in_laboratorio_informatica",
      "in_quadra_esportes", "in_internet", "in_acessibilidade_rampas",
    ],
  },
  {
    id: "docencia",
    name: "Qualidade de docência",
    description: "Formação (licenciatura/mestrado/doutorado), efetividade e especialização dos docentes",
    year_filter: 0,
    features: [
      "prop_licenciatura", "prop_mestrado", "prop_doutorado",
      "prop_efetivos", "prop_sem_especializacao",
    ],
  },
  {
    id: "desempenho",
    name: "Desempenho dos alunos",
    description: "Proficiências SAEB, IDEB observado e aprovação (escolha o ano)",
    year_filter: 1,
    features: ["nota_media", "nota_matematica", "nota_portugues", "ideb_observado", "aprovacao_si_4"],
  },
];

// Fixture do backend GET /api/cluster/columns — subconjunto para testes.
export const COLUMNS_FIXTURE = [
  // Censo
  { column_name: "in_agua_potavel",            data_type: "boolean",          comment: "Possui água potável",                  table_name: "censo_escolas" },
  { column_name: "in_energia_rede_publica",    data_type: "boolean",          comment: "Possui energia da rede pública",        table_name: "censo_escolas" },
  { column_name: "in_esgoto_rede_publica",     data_type: "boolean",          comment: "Possui esgoto da rede pública",         table_name: "censo_escolas" },
  { column_name: "in_lixo_servico_coleta",     data_type: "boolean",          comment: "Possui serviço de coleta de lixo",      table_name: "censo_escolas" },
  { column_name: "in_banheiro",                data_type: "boolean",          comment: "Possui banheiro",                       table_name: "censo_escolas" },
  { column_name: "in_biblioteca",              data_type: "boolean",          comment: "Possui biblioteca",                     table_name: "censo_escolas" },
  { column_name: "in_laboratorio_ciencias",    data_type: "boolean",          comment: "Possui laboratório de ciências",        table_name: "censo_escolas" },
  { column_name: "in_laboratorio_informatica", data_type: "boolean",          comment: "Possui laboratório de informática",     table_name: "censo_escolas" },
  { column_name: "in_quadra_esportes",         data_type: "boolean",          comment: "Possui quadra de esportes",             table_name: "censo_escolas" },
  { column_name: "in_internet",                data_type: "boolean",          comment: "Possui internet",                       table_name: "censo_escolas" },
  { column_name: "in_acessibilidade_rampas",  data_type: "boolean",          comment: "Possui rampas de acessibilidade",       table_name: "censo_escolas" },
  // Docentes
  { column_name: "qt_doc_bas",                 data_type: "integer",          comment: "Docentes na educação básica (total)",   table_name: "censo_docentes" },
  { column_name: "prop_licenciatura",          data_type: "double precision", comment: "Proporção de docentes com licenciatura", table_name: "censo_docentes" },
  { column_name: "prop_mestrado",              data_type: "double precision", comment: "Proporção de docentes com mestrado",    table_name: "censo_docentes" },
  { column_name: "prop_doutorado",             data_type: "double precision", comment: "Proporção de docentes com doutorado",   table_name: "censo_docentes" },
  { column_name: "prop_efetivos",              data_type: "double precision", comment: "Proporção de docentes concursados",     table_name: "censo_docentes" },
  { column_name: "prop_sem_especializacao",    data_type: "double precision", comment: "Proporção de docentes sem especialização", table_name: "censo_docentes" },
  // IDEB
  { column_name: "ano_ideb",                   data_type: "integer",          comment: "Ano IDEB/SAEB usado no build",          table_name: "ideb_notas_escolas" },
  { column_name: "nota_media",                 data_type: "numeric",          comment: "Média das proficiências (SAEB)",        table_name: "ideb_notas_escolas" },
  { column_name: "nota_matematica",            data_type: "numeric",          comment: "Proficiência em Matemática",            table_name: "ideb_notas_escolas" },
  { column_name: "nota_portugues",             data_type: "numeric",          comment: "Proficiência em Língua Portuguesa",     table_name: "ideb_notas_escolas" },
  { column_name: "ideb_observado",             data_type: "numeric",          comment: "IDEB observado no ano",                 table_name: "ideb_notas_escolas" },
  { column_name: "aprovacao_si_4",             data_type: "numeric",          comment: "Taxa de aprovação ajustada",            table_name: "ideb_notas_escolas" },
];

// Fixture do backend GET /api/cluster/years.
export const YEARS_FIXTURE = [{ ano: 2023 }, { ano: 2021 }, { ano: 2019 }];