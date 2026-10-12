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
  // Fase 2 (temas novos; `profundidade` no catálogo)
  {
    id: "ideb_escolas",
    titulo: "IDEB escola a escola",
    descricao: "IDEB de cada escola do município, ordenado.",
    niveis: ["municipio"],
    profundidade: "profunda",
    opcoes: { etapa: ETAPAS, rede: REDES },
  },
  {
    id: "infraestrutura_ideb",
    titulo: "Infraestrutura e IDEB",
    descricao: "O que da infraestrutura anda junto com o IDEB no estado.",
    niveis: ["uf"],
    profundidade: "profunda",
    opcoes: { etapa: ETAPAS, rede: REDES },
  },
  {
    id: "historico_escola",
    titulo: "Histórico da minha escola",
    descricao: "IDEB da escola ao longo das edições.",
    niveis: ["escola"],
    profundidade: "descritiva",
    opcoes: {},
  },
  {
    id: "escolas_parecidas",
    titulo: "Escolas parecidas com a minha",
    descricao: "Escolas públicas com perfil semelhante.",
    niveis: ["escola"],
    profundidade: "descritiva",
    opcoes: { etapa: ETAPAS },
    // etapa SEM padrão (livre): a página oferece "Todas as etapas" (#219, F2)
    padroes: {},
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

// ---------------------------------------------------------------- fase 2

/** infraestrutura_ideb: resumo, associações, tabelas recolhidas e aviso. */
export const RELATORIO_INFRAESTRUTURA_FIXTURE = {
  titulo: "Infraestrutura e IDEB — Rondônia",
  gerado_em: "2026-10-12T12:00:00Z",
  recorte: { nivel: "uf", codigo: "RO", nome: "Rondônia" },
  tema: { id: "infraestrutura_ideb", titulo: "Infraestrutura e IDEB" },
  secoes: [
    {
      id: "resumo",
      tipo: "texto",
      titulo: "Resumo",
      markdown: "Nas escolas urbanas de RO, ter **biblioteca** anda junto com IDEB maior.",
    },
    {
      id: "associacoes",
      tipo: "associacoes",
      titulo: "O que anda junto com o IDEB",
      itens: [
        { rotulo: "Biblioteca", corte: "Urbana", direcao: "maior", seguranca: "alta", n: 8123 },
        { rotulo: "Internet", corte: "Rural", direcao: "menor", seguranca: "media", n: 412 },
        { rotulo: "Nº de matrículas", direcao: "sem_relacao_clara", seguranca: "baixa", n: 8535 },
      ],
      nota: "Associação, não causa: escolas com biblioteca também diferem em outros aspectos.",
    },
    {
      id: "coeficientes",
      tipo: "tabela",
      recolhida: true,
      titulo: "Coeficientes do modelo",
      colunas: [
        { id: "termo", rotulo: "Termo", formato: "texto" },
        { id: "corte", rotulo: "Corte", formato: "texto" },
        { id: "estimativa", rotulo: "Estimativa", formato: "decimal2" },
        { id: "erro", rotulo: "Erro padrão", formato: "decimal2" },
        { id: "p_valor", rotulo: "p-valor", formato: "decimal2" },
      ],
      linhas: [
        { termo: "in_biblioteca", corte: "Urbana", estimativa: 0.31, erro: 0.05, p_valor: 0.001 },
        { termo: "in_internet", corte: "Rural", estimativa: -0.22, erro: 0.1, p_valor: 0.03 },
      ],
    },
    {
      id: "metricas",
      tipo: "tabela",
      recolhida: true,
      titulo: "Ajuste por corte",
      colunas: [
        { id: "corte", rotulo: "Corte", formato: "texto" },
        { id: "n", rotulo: "n", formato: "inteiro" },
        { id: "r2", rotulo: "R²", formato: "decimal2" },
        { id: "r2_aj", rotulo: "R² ajustado", formato: "decimal2" },
      ],
      linhas: [
        { corte: "Urbana", n: 8123, r2: 0.12, r2_aj: 0.11 },
        { corte: "Rural", n: 412, r2: 0.08, r2_aj: 0.06 },
      ],
    },
  ],
  fontes: [
    {
      ferramenta: "regressao_escolas",
      descricao: "Regressão linear por escola",
      edicao: "IDEB 2023",
      escopo: "escolas ativas de RO",
      n: 8535,
    },
  ],
  avisos: [
    {
      tipo: "associacao",
      mensagem: "Os resultados mostram associações entre fatores e o IDEB, não causas.",
    },
  ],
  rastreio: { provedor: "mock", modelo: "mock-1", llm: "ok", versao_edubr: "0.0.0.9000" },
};

/** ideb_escolas: lista com a escola do gestor em destaque. */
export const RELATORIO_IDEB_ESCOLAS_FIXTURE = {
  titulo: "IDEB escola a escola — Porto Velho (RO)",
  gerado_em: "2026-10-12T12:00:00Z",
  recorte: { nivel: "municipio", codigo: "1100205", nome: "Porto Velho", uf: "RO" },
  tema: { id: "ideb_escolas", titulo: "IDEB escola a escola" },
  secoes: [
    {
      id: "indicadores",
      tipo: "indicadores",
      titulo: "Visão geral",
      itens: [
        { rotulo: "Escolas com nota", valor: 3, formato: "inteiro" },
        { rotulo: "Mediana", valor: 5.6, formato: "decimal1" },
        { rotulo: "Posição da sua escola", valor: "2ª de 3", formato: "texto" },
      ],
    },
    {
      id: "escolas",
      tipo: "tabela",
      titulo: "Escolas do município",
      colunas: [
        { id: "nome", rotulo: "Escola", formato: "texto" },
        { id: "rede", rotulo: "Rede", formato: "texto" },
        { id: "ideb", rotulo: "IDEB", formato: "decimal1" },
      ],
      linhas: [
        { nome: "EMEF Rio Madeira", rede: "Municipal", ideb: 6.1 },
        { nome: "EEEF Professora Maria de Lourdes", rede: "Estadual", ideb: 5.6, _destaque: true },
        { nome: "EMEF Candelária", rede: "Municipal", ideb: 4.9 },
      ],
    },
  ],
  fontes: [{ ferramenta: "ideb", descricao: "IDEB por escola", edicao: "IDEB 2023", n: 3 }],
  avisos: [],
  rastreio: { provedor: "mock", modelo: "mock-1", llm: "ok" },
};

/** Resultado por tema (os demais usam o RELATORIO_RESULT_FIXTURE). */
export const RELATORIOS_POR_TEMA_FIXTURE = {
  infraestrutura_ideb: RELATORIO_INFRAESTRUTURA_FIXTURE,
  ideb_escolas: RELATORIO_IDEB_ESCOLAS_FIXTURE,
};

// ---------------------------------------------------------------- fase 4

/**
 * Assistentes (GET /assistentes): o "Relatório por tema" (modo tema, o
 * catálogo das Fases 1–3) e a "EDA do município" (modo composto, capítulos).
 */
export const ASSISTENTES_FIXTURE = [
  {
    id: "relatorio",
    titulo: "Relatório por tema",
    descricao: "Um tema por relatório, com a escolha do recorte e das opções.",
    modo: "tema",
    niveis: ["escola", "municipio", "uf", "regiao"],
    publico: ["gestor"],
    temas: TEMAS_FIXTURE.map((t) => t.id),
    opcoes: {},
    padroes: {},
  },
  {
    id: "eda_municipio",
    titulo: "EDA do município",
    descricao: "Relatório exploratório completo de um município, em capítulos.",
    modo: "composto",
    niveis: ["municipio"],
    publico: ["gestor"],
    capitulos: [
      { tema: "ideb_territorio", titulo: "IDEB do município" },
      { tema: "ideb_escolas", titulo: "Escolas do município pelo IDEB" },
      { tema: "redes_territorio", titulo: "Redes de ensino" },
      { tema: "docentes_territorio", titulo: "Professores" },
    ],
    opcoes: { etapa: ETAPAS },
    padroes: { etapa: "fundamental_i" },
  },
];

/** EDA do município (modo composto): capítulos e seções gerais. */
export const RELATORIO_EDA_FIXTURE = {
  titulo: "EDA do município — Porto Velho (RO)",
  gerado_em: "2026-10-12T12:00:00Z",
  recorte: { nivel: "municipio", codigo: "1100205", nome: "Porto Velho", uf: "RO" },
  assistente: { id: "eda_municipio", titulo: "EDA do município", modo: "composto" },
  tema: { id: "eda_municipio", titulo: "EDA do município" },
  capitulos: [
    { id: "ideb", titulo: "IDEB do município", tema: "ideb_territorio" },
    { id: "escolas", titulo: "Escolas do município pelo IDEB", tema: "ideb_escolas" },
  ],
  secoes: [
    {
      id: "resumo",
      tipo: "texto",
      titulo: "Resumo",
      markdown: "Porto Velho tem IDEB **5,6** nos anos iniciais, abaixo do estado.",
    },
    {
      id: "kpis",
      capitulo: "ideb",
      tipo: "indicadores",
      titulo: "Indicadores principais",
      itens: [{ rotulo: "IDEB 2023", valor: 5.6, formato: "decimal1", referencia: { rotulo: "RO", valor: 5.9 } }],
    },
    {
      id: "serie",
      capitulo: "ideb",
      tipo: "tabela",
      titulo: "IDEB ao longo do tempo",
      colunas: [
        { id: "ano", rotulo: "Ano", formato: "texto" },
        { id: "ideb", rotulo: "IDEB", formato: "decimal1" },
      ],
      linhas: [
        { ano: "2021", ideb: 5.0 },
        { ano: "2023", ideb: 5.6 },
      ],
    },
    {
      id: "kpis",
      capitulo: "escolas",
      tipo: "indicadores",
      titulo: "Visão geral das escolas",
      itens: [{ rotulo: "Escolas com nota", valor: 3, formato: "inteiro" }],
    },
    {
      id: "leitura",
      tipo: "texto",
      titulo: "Como ler",
      markdown: "Os capítulos descrevem o município; **não** indicam causas.",
    },
  ],
  fontes: [
    { ferramenta: "ideb_agregado", descricao: "IDEB agregado por território", edicao: "IDEB 2023" },
    { ferramenta: "ideb", descricao: "IDEB por escola", edicao: "IDEB 2023", n: 3 },
  ],
  avisos: [{ tipo: "sem_dados", mensagem: "O capítulo \"Professores\" ficou sem dados." }],
  rastreio: { provedor: "mock", modelo: "mock-1", llm: "ok" },
};
