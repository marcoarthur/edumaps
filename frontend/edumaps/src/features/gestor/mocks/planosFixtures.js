// src/features/gestor/mocks/planosFixtures.js — planos de gestão (#371, #372).
// Mesmo INEP da sessão de teste (SESSION_GESTOR.cod_inep).

export const INEP_PLANOS = "11000040";
// "Hoje" dos mocks: a ação com prazo antes disto é atrasada.
export const HOJE_PLANOS = "2026-03-10";

export const INDICADORES_PLANOS = [
  { codigo: "ideb_ai", grupo: "desempenho", rotulo: "IDEB — anos iniciais", unidade: "pontos (0 a 10)",
    fonte: "INEP — IDEB", sentido_sugerido: "aumentar", ultimo: { ano: 2023, valor: 5.4 } },
  { codigo: "ideb_em", grupo: "desempenho", rotulo: "IDEB — ensino médio", unidade: "pontos (0 a 10)",
    fonte: "INEP — IDEB", sentido_sugerido: "aumentar", ultimo: null },
  { codigo: "matriculas_total", grupo: "matriculas", rotulo: "Matrículas — total da educação básica",
    unidade: "alunos", fonte: "INEP — Censo Escolar", sentido_sugerido: "aumentar", ultimo: { ano: 2025, valor: 320 } },
  { codigo: "infra_quadra", grupo: "infraestrutura", rotulo: "Tem quadra de esportes", unidade: "sim/não",
    fonte: "INEP — Censo Escolar", sentido_sugerido: "aumentar", ultimo: null },
];

export const PLANOS_PLANOS = [
  {
    id: 1, tipo: "acao", titulo: "Plano de ação 2026", descricao: "Prioridades do ano letivo.",
    inicio: "2026-02-01", fim: "2026-12-15", situacao: "vigente", documento_id: null,
    alertas_ativos: true, arquivado: false,
    objetivos: [
      {
        id: 10, titulo: "Melhorar a aprendizagem", descricao: null, ordem: 1,
        metas: [
          { id: 100, objetivo_id: 10, descricao: "Subir o IDEB dos anos iniciais", unidade: "pontos (0 a 10)",
            sentido: "aumentar", indicador_codigo: "ideb_ai", linha_base: 5.0, alvo: 6.0, prazo: "2027-12-31",
            medicoes: [
              { id: 1000, origem: "oficial", data_ref: "2021-12-31", ano_ref: 2021, valor: 5.0, nota: null },
              { id: 1001, origem: "oficial", data_ref: "2023-12-31", ano_ref: 2023, valor: 5.4, nota: null },
            ] },
          { id: 101, objetivo_id: 10, descricao: "Reduzir faltas", unidade: "%", sentido: "reduzir",
            indicador_codigo: null, linha_base: 20, alvo: 12, prazo: "2026-12-15", medicoes: [],
            evidencias: [
              { id: 3001, tipo: "nota", titulo: null, texto: "Chamada conferida pela secretaria.",
                reuniao_id: null, quando: null, documento_id: null, documento_versao_id: null, versao: null,
                origem_removida: false, criado_em: "2026-03-02T10:00:00" },
            ] },
        ],
        acoes: [
          { id: 200, objetivo_id: 10, meta_id: 100, descricao: "Reforço de leitura", responsavel: "Coordenação",
            inicio: "2026-02-10", prazo: "2026-03-05", situacao: "em_andamento", concluida_em: null,
            custo_previsto: 1500, fonte_recurso: "pdde",
            evidencias: [
              { id: 3000, tipo: "ata", titulo: "Conselho escolar de fevereiro", texto: null,
                reuniao_id: 70, quando: "2026-02-20T19:00:00", documento_id: null, documento_versao_id: null,
                versao: null, origem_removida: false, criado_em: "2026-02-21T10:00:00" },
              { id: 3002, tipo: "documento", titulo: "Projeto de leitura (v1)", texto: null,
                reuniao_id: null, quando: null, documento_id: null, documento_versao_id: null, versao: null,
                origem_removida: true, criado_em: "2026-02-22T10:00:00" },
            ] },
          { id: 201, objetivo_id: 10, meta_id: null, descricao: "Busca ativa", responsavel: null,
            inicio: null, prazo: "2026-03-14", situacao: "nao_iniciada", concluida_em: null,
            custo_previsto: null, fonte_recurso: null },
        ],
      },
    ],
  },
  {
    id: 2, tipo: "ppp", titulo: "PPP 2025", descricao: null, inicio: "2025-02-01", fim: "2025-12-15",
    situacao: "encerrado", documento_id: null, alertas_ativos: false, arquivado: false, objetivos: [],
  },
];

// Reuniões e versões de documento da escola que podem virar evidência (#372).
export const ORIGENS_PLANOS = {
  reunioes: [
    { id: 70, titulo: "Conselho escolar de fevereiro", quando: "2026-02-20T19:00:00", status: "realizada", tem_ata: true },
    { id: 71, titulo: "Reunião de pais do 5º ano", quando: "2026-03-03T18:00:00", status: "realizada", tem_ata: false },
  ],
  documentos: [
    { versao_id: 81, documento_id: 8, nome: "PPP 2026", versao: 2, nome_original: "ppp-2026-v2.pdf", criado_em: "2026-03-01T09:00:00" },
    { versao_id: 80, documento_id: 8, nome: "PPP 2026", versao: 1, nome_original: "ppp-2026.pdf", criado_em: "2026-02-01T09:00:00" },
  ],
};
