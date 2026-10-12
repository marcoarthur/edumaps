// src/features/gestor/mocks/relatoriosFixtures.js
// Fixtures do Assistente de Relatório (issue #219), espelhando o contrato
// congelado da onda 1 (docs/specs/2026-10-12-assistente-relatorio.execucao.md).

export const INEP_RELATORIOS = "11000040";

export const RECORTE_PADRAO_FIXTURE = {
  escola: { cod_inep: "11000040", nome: "EEEF Professora Maria de Lourdes" },
  municipio: { codigo: "1100205", nome: "Porto Velho" },
  uf: { codigo: "RO", nome: "Rondônia" },
  regiao: { codigo: "N", nome: "Norte" },
};

const ETAPAS = ["fundamental_i", "fundamental_ii", "ensino_medio"];
const REDES = ["Municipal", "Estadual", "Federal", "Privada", "publica"];

export const TEMAS_FIXTURE = [
  {
    id: "ideb_territorio",
    titulo: "IDEB do território",
    descricao: "IDEB do recorte comparado ao nível de cima.",
    niveis: ["municipio", "uf", "regiao"],
    profundidade: "descritiva",
    opcoes: { etapa: ETAPAS, rede: REDES },
  },
  {
    id: "redes_territorio",
    titulo: "Redes de ensino",
    descricao: "Escolas e matrículas por rede de ensino.",
    niveis: ["municipio", "uf", "regiao"],
    profundidade: "descritiva",
    opcoes: { rede: REDES },
  },
  {
    id: "docentes_territorio",
    titulo: "Professores",
    descricao: "Perfil dos docentes por rede.",
    niveis: ["municipio", "uf", "regiao"],
    profundidade: "descritiva",
    opcoes: { rede: REDES },
  },
  {
    id: "gestores_territorio",
    titulo: "Perfil dos gestores escolares",
    descricao: "Formação e experiência dos gestores.",
    niveis: ["uf", "regiao"],
    profundidade: "descritiva",
    opcoes: { rede: REDES },
  },
  {
    id: "tendencia_ideb",
    titulo: "Tendência do IDEB",
    descricao: "Evolução do IDEB na região.",
    niveis: ["regiao"],
    profundidade: "descritiva",
    opcoes: { etapa: ETAPAS, rede: REDES },
  },
  {
    id: "minha_escola",
    titulo: "Minha escola diante do município e do estado",
    descricao: "Indicadores da escola comparados ao município e à UF.",
    niveis: ["escola"],
    profundidade: "descritiva",
    opcoes: {},
  },
];

/** ReportResult completo: as 4 seções, fontes, avisos e rastreio com LLM ok. */
export const RELATORIO_RESULT_FIXTURE = {
  titulo: "IDEB do território — Porto Velho (RO)",
  gerado_em: "2026-10-12T12:00:00Z",
  recorte: { nivel: "municipio", codigo: "1100205", nome: "Porto Velho", uf: "RO" },
  tema: { id: "ideb_territorio", titulo: "IDEB do território" },
  secoes: [
    {
      id: "resumo",
      tipo: "texto",
      titulo: "Resumo",
      markdown:
        "Em 2023 o IDEB dos anos iniciais em **Porto Velho** foi 5,6.\n\n- Rede municipal: 5,5\n- Rede estadual: 5,8",
    },
    {
      id: "kpis",
      tipo: "indicadores",
      titulo: "Indicadores principais",
      itens: [
        {
          rotulo: "IDEB 2023",
          valor: 5.6,
          formato: "decimal1",
          referencia: { rotulo: "RO", valor: 5.9 },
        },
        { rotulo: "Escolas avaliadas", valor: 12345, formato: "inteiro" },
        {
          rotulo: "Aprovação",
          valor: 0.934,
          formato: "percentual",
          referencia: { rotulo: "RO", valor: 0.951 },
        },
      ],
    },
    {
      id: "tabela_redes",
      tipo: "tabela",
      titulo: "IDEB por rede",
      colunas: [
        { id: "rede", rotulo: "Rede", formato: "texto" },
        { id: "escolas", rotulo: "Escolas", formato: "inteiro" },
        { id: "ideb", rotulo: "IDEB", formato: "decimal1" },
        { id: "nota", rotulo: "Nota SAEB", formato: "decimal2" },
        { id: "aprovacao", rotulo: "Aprovação", formato: "percentual" },
      ],
      linhas: [
        { rede: "Municipal", escolas: 1234, ideb: 5.5, nota: 5.876, aprovacao: 0.925 },
        { rede: "Estadual", escolas: 87, ideb: 5.8, nota: 6.1, aprovacao: 0.96 },
      ],
      nota: "Escolas com IDEB divulgado em 2023.",
    },
    {
      id: "grafico_serie",
      tipo: "grafico",
      grafico: "barras",
      titulo: "IDEB ao longo do tempo",
      x: { id: "ano", rotulo: "Ano" },
      series: [
        { id: "ideb", rotulo: "Porto Velho" },
        { id: "ideb_uf", rotulo: "RO" },
      ],
      dados: [
        { ano: 2019, ideb: 5.2, ideb_uf: 5.5 },
        { ano: 2021, ideb: 5.0, ideb_uf: 5.4 },
        { ano: 2023, ideb: 5.6, ideb_uf: 5.9 },
      ],
    },
    {
      id: "leitura",
      tipo: "texto",
      titulo: "Como ler",
      markdown: "O IDEB combina **aprendizado** e **fluxo**. Não indica causas.",
    },
  ],
  fontes: [
    {
      ferramenta: "ideb_agregado",
      descricao: "IDEB agregado por território",
      edicao: "IDEB 2023",
      escopo: "municípios de RO",
      n: 52,
    },
  ],
  avisos: [{ tipo: "truncado", mensagem: "A consulta de docentes foi limitada a 1000 linhas." }],
  rastreio: {
    provedor: "mock",
    modelo: "mock-1",
    llm: "ok",
    versao_edubr: "0.0.0.9000",
    chamadas: 2,
    duracao_ms: 3100,
  },
};

/** Mesmo relatório quando a redação pelo LLM falhou. */
export const RELATORIO_LLM_INDISPONIVEL_FIXTURE = {
  ...RELATORIO_RESULT_FIXTURE,
  secoes: [
    {
      id: "resumo",
      tipo: "texto",
      titulo: "Resumo",
      markdown: "Relatório gerado sem redação automática. Veja os dados abaixo.",
    },
    ...RELATORIO_RESULT_FIXTURE.secoes.slice(1, -1),
  ],
  avisos: [{ tipo: "llm", mensagem: "O serviço de redação não respondeu." }],
  rastreio: { ...RELATORIO_RESULT_FIXTURE.rastreio, llm: "indisponivel" },
};
