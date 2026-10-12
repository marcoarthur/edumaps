// src/features/gestor/mocks/canaisFixtures.js
// Fixtures do módulo Listas & QR (autoinscrição de contatos via telefone).
// Espelha o contrato congelado da Fase 0 (issue #208) + confirmação de posse
// do telefone (issue #212, onda 1: `exige_confirmacao`, estado do membro):
//   gestão  /api/gestor/:cod_inep/canais/listas (Bearer + posse do cod_inep)
//   público /api/canais/inscricao/:token        (sem auth)

export const INEP_CANAIS = "11000040";

export const CANAIS_ESCOLA_NOME = "Escola Estadual Professora Maria de Lourdes";

// ---------------------------------------------------------------------------
// Listas nomeadas (gestão)
// ---------------------------------------------------------------------------

export const LISTAS_CANAIS_FIXTURE = [
  {
    id: 1,
    cod_inep: 11000040,
    nome: "Responsáveis 6ºA",
    canal: "telefone",
    descricao: "Responsáveis dos alunos do 6ºA.",
    ativo: true,
    n_membros: 2,
    exige_confirmacao: false,
    membros_confirmados: 0,
    membros_pendentes: 0,
    qrcode: null,
    created_at: "2026-10-10T09:00:00",
    updated_at: "2026-10-10T09:00:00",
  },
  {
    id: 2,
    cod_inep: 11000040,
    nome: "Professores",
    canal: "telefone",
    descricao: null,
    ativo: true,
    n_membros: 0,
    exige_confirmacao: false,
    membros_confirmados: 0,
    membros_pendentes: 0,
    qrcode: {
      token: "abcdabcd-1234-4abc-8def-abcdefabcdef",
      url: "http://localhost:5173/inscricao/abcdabcd-1234-4abc-8def-abcdefabcdef",
      expira_em: null,
      usos: 3,
      max_usos: null,
      status: "ativo",
    },
    created_at: "2026-10-10T09:30:00",
    updated_at: "2026-10-10T09:30:00",
  },
  {
    id: 3,
    cod_inep: 11000040,
    nome: "Responsáveis 7ºB",
    canal: "telefone",
    descricao: "Lista que exige confirmação do telefone.",
    ativo: true,
    n_membros: 2,
    exige_confirmacao: true,
    membros_confirmados: 1,
    membros_pendentes: 1,
    qrcode: null,
    created_at: "2026-10-11T08:00:00",
    updated_at: "2026-10-11T08:00:00",
  },
];

// Membros por lista (GET /listas/:id/inscricoes).
export const MEMBROS_CANAIS_FIXTURE = {
  1: [
    {
      id: 11,
      contato_id: 101,
      nome: "João Pai",
      telefone: "+55 11 99999-0002",
      quando: "2026-10-10T10:15:00",
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
    },
    {
      id: 12,
      contato_id: 102,
      nome: "Marina Responsável",
      telefone: "+5511999990003",
      quando: "2026-10-10T18:40:00",
      validado: false,
      conflito: true,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
    },
  ],
  2: [],
  3: [
    {
      id: 31,
      contato_id: 301,
      nome: "Carla Confirmada",
      telefone: "+55 11 99999-0004",
      quando: "2026-10-11T09:00:00",
      validado: true,
      conflito: false,
      origem: "qrcode",
      confirmado_via: "telegram",
      confirmado_em: "2026-10-11T09:02:00",
    },
    {
      id: 32,
      contato_id: 302,
      nome: "Paulo Pendente",
      telefone: "+55 11 99999-0005",
      quando: "2026-10-11T09:30:00",
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
    },
  ],
};

// `estado` do membro é derivado (contrato #212): confirmado se confirmado_em,
// senão pendente se a lista exige, senão nao_exigida. Os handlers calculam.

// Resposta de POST /listas/:id/qrcode (novo QR ou rotação).
export const QRCODE_CANAIS_FIXTURE = {
  token: "12341234-5678-4abc-8def-123412341234",
  url: "http://localhost:5173/inscricao/12341234-5678-4abc-8def-123412341234",
  expira_em: null,
  usos: 0,
  max_usos: null,
  status: "ativo",
};

// ---------------------------------------------------------------------------
// Página pública (sem auth)
// ---------------------------------------------------------------------------

export const INSCRICAO_PUBLICA_FORM = {
  lista_nome: "Responsáveis 6ºA",
  escola_nome: CANAIS_ESCOLA_NOME,
  canal: "telefone",
  campos: ["nome", "telefone"],
  expira_em: null,
};

// Tokens usados nos testes e no estado inicial do mock.
export const INSCRICAO_TOKEN_VALIDO = "11111111-1111-4111-8111-111111111111";
export const INSCRICAO_TOKEN_EXPIRADO = "22222222-2222-4222-8222-222222222222";
export const INSCRICAO_TOKEN_REVOGADO = "33333333-3333-4333-8333-333333333333";
// O primeiro POST passa; os seguintes recebem 429 (limite de usos).
export const INSCRICAO_TOKEN_LIMITE = "44444444-4444-4444-8444-444444444444";

// Telefone já inscrito na lista do token válido — dispara `duplicado` no POST.
export const TELEFONE_DUPLICADO = "+55 11 99999-0002";

// ---------------------------------------------------------------------------
// Confirmação de posse do telefone (issue #212)
// ---------------------------------------------------------------------------

// Token público da lista 3 (exige confirmação).
export const INSCRICAO_TOKEN_CONFIRMACAO = "55555555-5555-4555-8555-555555555555";
// Telefone já confirmado na lista 3 — reinscrição devolve {estado:"confirmado"}.
export const TELEFONE_CONFIRMADO = "+55 11 99999-0004";
// Telefone pendente na lista 3 — reinscrição gera nova ref.
export const TELEFONE_PENDENTE = "+55 11 99999-0005";
// Bot público de confirmação (deep link t.me/<bot>?start=<ref>).
export const TELEGRAM_BOT_CONFIRMACAO = "EduMapsConfirmaBot";
// Código de 6 dígitos que o mock do WhatsApp "envia".
export const WHATSAPP_CODIGO_MOCK = "123456";
