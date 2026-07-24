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

export const RANKING_FIXTURES = {
  ideb_anos_finais: {
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
