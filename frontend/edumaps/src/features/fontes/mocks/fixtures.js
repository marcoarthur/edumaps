// src/features/fontes/mocks/fixtures.js
export const FONTES_FIXTURE = [
  {
    id: "censo", nome: "Censo Escolar", orgao: "INEP",
    descricao: "Escolas, matrículas, docentes, gestores e infraestrutura.",
    url: "https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/censo-escolar",
    metodologia: "https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar",
    telas: ["comparacao_redes", "perfil_escola", "ranking", "agrupamento", "busca"],
    periodo: { inicio: "2025", fim: "2025", texto: "2025" },
    carga: { data: "2026-10-14", arquivos: [] },
    licenca: null,
  },
  {
    id: "ideb", nome: "IDEB e SAEB", orgao: "INEP",
    descricao: "IDEB e notas do SAEB por escola e etapa.",
    url: "https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/ideb",
    metodologia: "https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/ideb/resultados",
    telas: ["comparacao_redes", "perfil_escola", "ranking", "agrupamento"],
    periodo: { inicio: "2005", fim: "2023", texto: "2005–2023" },
    carga: null,
    licenca: null,
  },
  {
    id: "siope", nome: "Folha de pagamento da educação (SIOPE)", orgao: "FNDE",
    descricao: "Remuneração dos profissionais da educação. Cobertura parcial.",
    url: "https://www.gov.br/fnde/pt-br/assuntos/sistemas/siope",
    metodologia: "https://www.gov.br/fnde/pt-br/assuntos/sistemas/siope",
    telas: ["financeiro", "folha"],
    periodo: { inicio: "2024", fim: "2026", texto: "2024–2026" },
    carga: {
      data: "2026-11-01",
      arquivos: [{ url: "https://exemplo/siope.csv", sha256: "ab12cd34ef56", bytes: 1048576, baixado_em: "2026-11-01T10:00:00+0000" }],
    },
    licenca: "Domínio público",
  },
];
