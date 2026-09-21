// src/features/gestor/mocks/relacoesFixtures.js
// Fixtures das Relações Institucionais (compatíveis com o backend).

export const INEP_RELACOES = "11000040";

export const CATEGORIAS_RELACOES = [
  { id: 1, eixo: "entidade", nome: "Órgãos públicos", origem: "padrao", n_entidades: 1 },
  { id: 2, eixo: "entidade", nome: "Outras escolas", origem: "padrao", n_entidades: 0 },
  { id: 3, eixo: "entidade", nome: "Fornecedores", origem: "padrao", n_entidades: 1 },
  { id: 4, eixo: "entidade", nome: "Famílias", origem: "padrao", n_entidades: 0 },
  { id: 5, eixo: "entidade", nome: "Comunidade", origem: "padrao", n_entidades: 0 },
  { id: 6, eixo: "entidade", nome: "Instituições parceiras", origem: "padrao", n_entidades: 0 },
  { id: 7, eixo: "entidade", nome: "Conselhos e representação", origem: "padrao", n_entidades: 0 },
  { id: 8, eixo: "finalidade", nome: "Obrigação/regulação", origem: "padrao", n_entidades: 0 },
  { id: 9, eixo: "finalidade", nome: "Solicitação", origem: "padrao", n_entidades: 0 },
  { id: 10, eixo: "finalidade", nome: "Prestação de contas", origem: "padrao", n_entidades: 0 },
  { id: 11, eixo: "finalidade", nome: "Contratação", origem: "padrao", n_entidades: 0 },
  { id: 12, eixo: "finalidade", nome: "Comunicação", origem: "padrao", n_entidades: 0 },
  { id: 13, eixo: "finalidade", nome: "Parceria", origem: "padrao", n_entidades: 0 },
  { id: 14, eixo: "finalidade", nome: "Participação", origem: "padrao", n_entidades: 0 },
  { id: 15, eixo: "finalidade", nome: "Resolução de problema", origem: "padrao", n_entidades: 0 },
  { id: 16, eixo: "finalidade", nome: "Projeto", origem: "padrao", n_entidades: 0 },
  { id: 17, eixo: "finalidade", nome: "Acompanhamento", origem: "padrao", n_entidades: 0 },
];

export const ENTIDADES_RELACOES = [
  {
    id: 1,
    tipo: "Órgãos públicos",
    nome: "Prefeitura de Porto Velho",
    identificador: null,
    responsavel_externo: "Secretaria de Obras",
    email: "gabinete@pref.test",
    telefone: "6933330000",
    site: null,
    endereco: null,
    observacoes: null,
    atributos: { ramal: 42 },
    n_relacoes: 1,
    updated_at: "2026-09-20T10:00:00",
  },
  {
    id: 2,
    tipo: "Fornecedores",
    nome: "Alimenta Merenda LTDA",
    identificador: "12.345.678/0001-90",
    responsavel_externo: "Comercial",
    email: "vendas@alimenta.test",
    telefone: "6933331111",
    site: null,
    endereco: null,
    observacoes: null,
    atributos: {},
    n_relacoes: 1,
    updated_at: "2026-09-20T10:00:00",
  },
];

export const RELACOES_RELACOES = [
  {
    id: 1,
    entidade_id: 1,
    entidade_nome: "Prefeitura de Porto Velho",
    entidade_tipo: "Órgãos públicos",
    finalidade: "Solicitação",
    assunto: "Conserto do telhado da quadra",
    descricao: "Infiltração no telhado da quadra.",
    status: "aberta",
    prioridade: "alta",
    responsavel_interno: "Coordenador administrativo",
    inicio: "2026-09-10",
    proxima_acao: "Cobrar orçamento",
    prazo: "2020-01-01",
    vencida: 1,
    atributos: {},
    updated_at: "2026-09-20T10:00:00",
  },
  {
    id: 2,
    entidade_id: 2,
    entidade_nome: "Alimenta Merenda LTDA",
    entidade_tipo: "Fornecedores",
    finalidade: "Contratação",
    assunto: "Contrato de merenda 2026",
    descricao: null,
    status: "em_andamento",
    prioridade: "media",
    responsavel_interno: "Direção",
    inicio: null,
    proxima_acao: "Conferir entrega do mês",
    prazo: null,
    vencida: 0,
    atributos: {},
    updated_at: "2026-09-20T10:00:00",
  },
];

// Interações e documentos da relação 1 (timeline do detalhe).
export const INTERACOES_RELACAO = [
  {
    id: 1,
    data: "2026-09-15",
    canal: "reunião",
    participante: "Secretaria de Obras",
    assunto: "Reunião inicial",
    descricao: "Apresentamos o problema do telhado.",
    resultado: "Enviar ofício com o pedido",
    created_at: "2026-09-15T10:00:00",
    updated_at: "2026-09-15T10:00:00",
  },
];

export const DOCUMENTOS_RELACAO = [
  {
    id: 1,
    tipo: "ofício",
    data: "2026-09-15",
    referencia: "OF-123",
    nome_original: "oficio-telhado.pdf",
    mime: "application/pdf",
    tamanho: 1234,
    created_at: "2026-09-15T10:00:00",
  },
];
