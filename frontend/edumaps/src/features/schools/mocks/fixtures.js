// src/features/schools/mocks/fixtures.js
export const DEMO_SCHOOL_COD_INEP = "35123456";

export const INDICATORS_FIXTURE = [
  { id: "ideb_anos_finais", label: "IDEB – Anos Finais", available: true },
  { id: "ideb_anos_iniciais", label: "IDEB – Anos Iniciais", available: true },
  { id: "infraestrutura", label: "Infraestrutura", available: true },
  {
    id: "capacidade_atendimento",
    label: "Capacidade de Atendimento",
    available: true,
  },
  { id: "capacitacao_docente", label: "Capacitação Docente", available: true },
  {
    id: "diversidade_discente",
    label: "Diversidade Discente",
    available: true,
  },
  { id: "capacidade_gestora", label: "Capacidade Gestora", available: true },
  { id: "sustentabilidade", label: "Sustentabilidade", available: true },
  { id: "ideb_ensino_medio", label: "IDEB – Ensino Médio", available: false },
];

export const RANKING_FIXTURES = {  ideb_anos_finais: {
    indicador: {
      id: "ideb_anos_finais",
      label: "IDEB – Anos Finais",
      valor: 6.8,
    },
    ano: 2023,
    rede: null,
    ranking: {
      municipio: { posicao: 2, total: 40, percentil: 95 },
      estado: { posicao: 15, total: 900, percentil: 85 },
      nacional: null,
    },
  },
  infraestrutura: {
    indicador: {
      id: "infraestrutura",
      label: "Infraestrutura",
      valor: 8.2,
    },
    ano: 2023,
    rede: null,
    ranking: {
      municipio: { posicao: 1, total: 40, percentil: 99 },
      estado: { posicao: 8, total: 900, percentil: 92 },
      nacional: null,
    },
  },
  // Adicionar mais se necessário
};

// Payload do GET /api/school/:cod_inep/profile (issue #105). Espelha o
// contrato real do endpoint analítico /school_profile.
export const PROFILE_FIXTURE = {
  analysis: "school_profile",
  parameters: { co_entidade: DEMO_SCHOOL_COD_INEP },
  data: [],
  metrics: {
    cluster_size: 42,
    n_indicadores: 3,
    n_peers: 2,
    n_flags: 1,
    total_escolas_municipio: 10,
    total_escolas_rede: 20,
    total_escolas_brasil: 100,
  },
  metadata: {
    co_entidade: DEMO_SCHOOL_COD_INEP,
    no_entidade: "EMEF Exemplo",
    co_municipio: 3550308,
    no_municipio: "São Paulo",
    sg_uf: "SP",
    nu_ano_censo: 2025,
    cluster_id: 3,
    cluster_label: "Alta perfil escolar",
    cluster_source: "fallback_kmeans",
    cluster_scope: "municipio",
    cluster_size: 42,
    peers_source: "gower_municipio",
    n_municipio: 10,
    n_rede: 20,
    n_brasil: 100,
    cached: false,
    computed_at: "2026-09-28 21:00:00",
    cluster_run_id: "run_123",
  },
  tables: {
    indicadores_comparados: [
      {
        indicador: "prop_licenciatura",
        label: "Docentes com licenciatura",
        escola: 0.87,
        municipio: 0.72,
        rede: 0.68,
        brasil: 0.79,
        cluster: 0.81,
        quartil_no_cluster: 3,
        atencao: false,
      },
      {
        indicador: "ratio_aluno_docente",
        label: "Relação aluno/docente",
        escola: 32.1,
        municipio: 24.5,
        rede: 22.0,
        brasil: 15.0,
        cluster: 25.1,
        quartil_no_cluster: 1,
        atencao: true,
      },
      {
        indicador: "ideb_observado",
        label: "IDEB observado",
        escola: 4.7,
        municipio: 5.2,
        rede: 5.3,
        brasil: 5.2,
        cluster: 5.0,
        quartil_no_cluster: 2,
        atencao: false,
      },
    ],
    cluster_resumo: [
      {
        indicador: "prop_licenciatura",
        label: "Docentes com licenciatura",
        media: 0.8,
        p25: 0.7,
        p50: 0.81,
        p75: 0.9,
        n: 42,
      },
      {
        indicador: "ratio_aluno_docente",
        label: "Relação aluno/docente",
        media: 25.5,
        p25: 22.0,
        p50: 25.1,
        p75: 29.0,
        n: 42,
      },
      {
        indicador: "ideb_observado",
        label: "IDEB observado",
        media: 5.0,
        p25: 4.5,
        p50: 5.0,
        p75: 5.6,
        n: 42,
      },
    ],
    peers: [
      {
        co_entidade: "35003111",
        no_entidade: "EMEF Vizinha",
        similarity: 0.94,
        ideb_observado: 6.1,
      },
      {
        co_entidade: "35003112",
        no_entidade: "EMEF Central",
        similarity: 0.9,
        ideb_observado: 5.8,
      },
    ],
    flags: [
      {
        indicador: "ratio_aluno_docente",
        codigo: "ratio_aluno_docente_alta",
        severidade: "media",
        mensagem: "Relação aluno/docente no quartil inferior do cluster",
        escola: 32.1,
        quartil_no_cluster: 1,
      },
    ],
  },
};
