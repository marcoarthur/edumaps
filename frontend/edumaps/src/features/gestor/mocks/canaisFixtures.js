// src/features/gestor/mocks/canaisFixtures.js
// Fixtures do módulo Listas & QR (autoinscrição de contatos via telefone).
// Espelha o contrato congelado da Fase 0 (issue #208) + confirmação de posse
// do telefone (issue #212, onda 1: `exige_confirmacao`, estado do membro) +
// e-mail e LGPD (issue #214, onda 1: `coleta`, estado por contato, `parcial`,
// consentimento versionado, `exclusao_url`, QR com validade/limite):
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
    coleta: "telefone",
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
    coleta: "telefone",
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
    coleta: "telefone",
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
  {
    id: 4,
    cod_inep: 11000040,
    nome: "Família 8ºC",
    canal: "telefone",
    coleta: "ambos",
    descricao: "Coleta telefone e e-mail; exige confirmação.",
    ativo: true,
    n_membros: 3,
    exige_confirmacao: true,
    membros_confirmados: 1,
    membros_pendentes: 2,
    qrcode: null,
    created_at: "2026-10-12T08:00:00",
    updated_at: "2026-10-12T08:00:00",
  },
  {
    id: 5,
    cod_inep: 11000040,
    nome: "Comunidade escolar",
    canal: "telefone",
    coleta: "qualquer",
    descricao: "Telefone ou e-mail, à escolha de quem se inscreve.",
    ativo: true,
    n_membros: 1,
    exige_confirmacao: false,
    membros_confirmados: 0,
    membros_pendentes: 0,
    qrcode: null,
    created_at: "2026-10-12T08:30:00",
    updated_at: "2026-10-12T08:30:00",
  },
  {
    id: 6,
    cod_inep: 11000040,
    nome: "Boletim por e-mail",
    canal: "telefone",
    coleta: "email",
    descricao: null,
    ativo: true,
    n_membros: 1,
    exige_confirmacao: true,
    membros_confirmados: 0,
    membros_pendentes: 1,
    qrcode: null,
    created_at: "2026-10-12T09:00:00",
    updated_at: "2026-10-12T09:00:00",
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
  // coleta "ambos": confirmado_em/confirmado_via = telefone; email_confirmado_em = e-mail
  4: [
    {
      id: 41,
      contato_id: 401,
      nome: "Ana Parcial",
      telefone: "+55 11 99999-0041",
      email: "ana@example.org",
      quando: "2026-10-12T09:00:00",
      validado: true,
      conflito: false,
      origem: "qrcode",
      confirmado_via: "telegram",
      confirmado_em: "2026-10-12T09:01:00",
      email_confirmado_em: null,
    },
    {
      id: 42,
      contato_id: 402,
      nome: "Bruno Completo",
      telefone: "+55 11 99999-0042",
      email: "bruno@example.org",
      quando: "2026-10-12T09:10:00",
      validado: true,
      conflito: false,
      origem: "qrcode",
      confirmado_via: "whatsapp",
      confirmado_em: "2026-10-12T09:11:00",
      email_confirmado_em: "2026-10-12T09:12:00",
    },
    {
      id: 43,
      contato_id: 403,
      nome: "Clara Pendente",
      telefone: "+55 11 99999-0043",
      email: "clara@example.org",
      quando: "2026-10-12T09:20:00",
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
      email_confirmado_em: null,
    },
  ],
  5: [
    {
      id: 51,
      contato_id: 501,
      nome: "Diego Só E-mail",
      telefone: null,
      email: "diego@example.org",
      quando: "2026-10-12T10:00:00",
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
      email_confirmado_em: null,
    },
  ],
  6: [
    {
      id: 61,
      contato_id: 601,
      nome: "Eva Leitora",
      telefone: null,
      email: "eva@example.org",
      quando: "2026-10-12T10:30:00",
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
      email_confirmado_em: null,
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
  obrigatorios: ["nome", "telefone"],
  expira_em: null,
};

// `campos`/`obrigatorios` por `coleta` (contrato #214, onda 1).
export const CAMPOS_POR_COLETA = {
  telefone: { campos: ["nome", "telefone"], obrigatorios: ["nome", "telefone"] },
  email: { campos: ["nome", "email"], obrigatorios: ["nome", "email"] },
  ambos: { campos: ["nome", "telefone", "email"], obrigatorios: ["nome", "telefone", "email"] },
  qualquer: { campos: ["nome", "telefone", "email"], obrigatorios: ["nome"] },
};

export const COLETAS_VALIDAS = Object.keys(CAMPOS_POR_COLETA);

// Texto de consentimento vigente (GET /api/canais/consentimento e embutido no
// GET público). Markdown simples: parágrafos, listas e **negrito**.
export const CONSENTIMENTO_VIGENTE = {
  versao: "1.0",
  texto: [
    "Ao se inscrever, você autoriza a **escola** a guardar seu nome e seus contatos.",
    "",
    "Usamos esses dados para:",
    "",
    "- avisos da escola;",
    "- convites para reuniões.",
    "",
    "Você pode pedir a **remoção dos seus dados** a qualquer momento.",
  ].join("\n"),
  publicada_em: "2026-10-12T00:00:00Z",
};

// Versão nova (para simular o 409 de consentimento desatualizado).
export const CONSENTIMENTO_NOVO = {
  versao: "1.1",
  texto: "Texto **revisado** do consentimento.\n\nInclui o uso do e-mail.",
  publicada_em: "2026-10-13T00:00:00Z",
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

// ---------------------------------------------------------------------------
// E-mail e LGPD (issue #214, onda 1)
// ---------------------------------------------------------------------------

// Token público da lista 4 (coleta "ambos", exige confirmação).
export const INSCRICAO_TOKEN_AMBOS = "66666666-6666-4666-8666-666666666666";
// Token público da lista 5 (coleta "qualquer", não exige).
export const INSCRICAO_TOKEN_QUALQUER = "77777777-7777-4777-8777-777777777777";
// Token público da lista 6 (coleta "email", exige confirmação).
export const INSCRICAO_TOKEN_EMAIL = "88888888-8888-4888-8888-888888888888";
// Código de 6 dígitos que o mock do e-mail "envia".
export const EMAIL_CODIGO_MOCK = "654321";

// ---------------------------------------------------------------------------
// Exclusão e retenção (issue #214, onda 2)
// ---------------------------------------------------------------------------

// Tokens de exclusão (32 hex, os da `exclusao_url`).
// Válido: inscrição do João Pai (lista 1, membro 11, contato 101).
export const EXCLUSAO_TOKEN_VALIDO = "a1b2c3d4e5f60718293a4b5c6d7e8f90";
// Inscrição já anonimizada antes (GET devolve ja_excluido).
export const EXCLUSAO_TOKEN_JA_EXCLUIDO = "b1b2c3d4e5f60718293a4b5c6d7e8f90";
// Antiabuso: o POST responde 429.
export const EXCLUSAO_TOKEN_LIMITE = "c1b2c3d4e5f60718293a4b5c6d7e8f90";

// Prazos de retenção expostos em GET /api/canais/consentimento (`retencao`).
export const RETENCAO_PUBLICA = {
  enabled: true,
  metadados_dias: 90,
  pendentes_dias: 180,
  listas_inativas_meses: 12,
};

// Histórico de exclusões da escola (GET /canais/exclusoes), mais recentes primeiro.
export const EXCLUSOES_FIXTURE = [
  {
    id: 3,
    origem: "titular",
    regra: null,
    motivo: null,
    gestor_id: null,
    contatos: 1,
    inscricoes: 1,
    membros: 1,
    created_at: "2026-10-11T14:00:00",
  },
  {
    id: 2,
    origem: "retencao",
    regra: "pendentes",
    motivo: null,
    gestor_id: null,
    contatos: 0,
    inscricoes: 0,
    membros: 0,
    created_at: "2026-10-11T03:00:00",
  },
  {
    id: 1,
    origem: "gestor",
    regra: null,
    motivo: "Pedido feito na secretaria",
    gestor_id: 7,
    contatos: 1,
    inscricoes: 2,
    membros: 2,
    created_at: "2026-10-10T16:30:00",
  },
];
