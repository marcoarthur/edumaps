// src/features/gestor/mocks/enviosFixtures.js
// Fixtures do envio por e-mail para listas (issue #216, Fase 3, onda 1).
// Espelha o contrato congelado (docs/specs/2026-10-12-envio-email-listas-qr.execucao.md):
//   gestão /api/gestor/:cod_inep/canais/{envios,segmentos} (Bearer + posse)
//
// As listas são as de canaisFixtures.js (mesma escola INEP_CANAIS). Aqui fica,
// por lista, quem tem e-mail (só esses viram destinatários), com o estado geral
// do membro, se o e-mail foi confirmado e o dia da inscrição.

export const ENVIOS_GESTOR = { id: 2, nome: "Diretora Helena" };

/** Membros com e-mail por lista (listas 1–3 coletam só telefone). */
export const DESTINATARIOS_LISTAS_FIXTURE = {
  4: [
    { nome: "Ana Parcial", email: "ana@example.org", estado: "parcial", email_confirmado: false, inscrito_em: "2026-10-12" },
    { nome: "Bruno Completo", email: "bruno@example.org", estado: "confirmado", email_confirmado: true, inscrito_em: "2026-10-12" },
    { nome: "Clara Pendente", email: "clara@example.org", estado: "pendente", email_confirmado: false, inscrito_em: "2026-10-12" },
  ],
  // Bruno também está na lista 5: na união, conta uma vez (duplicado)
  5: [
    { nome: "Diego Só E-mail", email: "diego@example.org", estado: "nao_exigida", email_confirmado: false, inscrito_em: "2026-10-12" },
    { nome: "Bruno Completo", email: "bruno@example.org", estado: "confirmado", email_confirmado: true, inscrito_em: "2026-10-11" },
  ],
  6: [
    { nome: "Eva E-mail", email: "eva@example.org", estado: "pendente", email_confirmado: false, inscrito_em: "2026-10-12" },
  ],
};

export const LIMITES_ENVIO_FIXTURE = {
  enabled: true,
  smtp_disponivel: true,
  ritmo_por_minuto: 60,
  cota_diaria: 500,
  max_destinatarios: 2000,
  enviados_hoje: 12,
  saldo_hoje: 488,
  suspensao: null,
};

const contadores = (o = {}) => ({
  destinatarios: 0,
  enviados: 0,
  falhas: 0,
  ignorados: 0,
  pendentes: 0,
  cancelados: 0,
  optouts: 0,
  ...o,
});

export const ENVIOS_FIXTURE = [
  {
    id: 1,
    cod_inep: 11000040,
    alvo: { tipo: "lista", id: 4, nome: "Família 8ºC" },
    canal: "email",
    operacao: "aviso",
    assunto: "Reunião de pais na sexta",
    corpo: "Olá!\n\nA reunião de pais será **sexta, às 19h**.\n\n- Local: auditório\n- Duração: 1h",
    status: "rascunho",
    agendado_para: null,
    iniciado_em: null,
    concluido_em: null,
    cancelado_em: null,
    contadores: contadores(),
    autor: ENVIOS_GESTOR,
    created_at: "2026-10-12T12:00:00Z",
    updated_at: "2026-10-12T12:00:00Z",
  },
  {
    id: 2,
    cod_inep: 11000040,
    alvo: { tipo: "segmento", id: 1, nome: "Confirmados" },
    canal: "email",
    operacao: "lembrete",
    assunto: "Lembrete: entrega de documentos",
    corpo: "Lembramos que a entrega dos documentos termina amanhã.",
    status: "enviando",
    agendado_para: null,
    iniciado_em: "2026-10-12T13:00:00Z",
    concluido_em: null,
    cancelado_em: null,
    contadores: contadores({ destinatarios: 3, enviados: 1, pendentes: 2, ignorados: 1, optouts: 1 }),
    autor: ENVIOS_GESTOR,
    created_at: "2026-10-12T12:30:00Z",
    updated_at: "2026-10-12T13:00:00Z",
  },
  {
    id: 3,
    cod_inep: 11000040,
    alvo: { tipo: "lista", id: 5, nome: "Comunidade escolar" },
    canal: "email",
    operacao: "convite",
    assunto: "Convite: festa junina",
    corpo: "Venha para a nossa festa!",
    status: "concluido",
    agendado_para: null,
    iniciado_em: "2026-10-10T10:00:00Z",
    concluido_em: "2026-10-10T10:02:00Z",
    cancelado_em: null,
    contadores: contadores({ destinatarios: 2, enviados: 1, falhas: 1 }),
    autor: ENVIOS_GESTOR,
    created_at: "2026-10-10T09:00:00Z",
    updated_at: "2026-10-10T10:02:00Z",
  },
  {
    id: 4,
    cod_inep: 11000040,
    alvo: { tipo: "lista", id: 6, nome: "Boletim por e-mail" },
    canal: "email",
    operacao: "informacao",
    assunto: "Boletim de outubro",
    corpo: "Segue o boletim.",
    status: "pausado_cota",
    agendado_para: null,
    iniciado_em: "2026-10-11T10:00:00Z",
    concluido_em: null,
    cancelado_em: null,
    contadores: contadores({ destinatarios: 1, pendentes: 1 }),
    autor: ENVIOS_GESTOR,
    created_at: "2026-10-11T09:00:00Z",
    updated_at: "2026-10-11T10:00:00Z",
  },
];

/** Destinatários (já mascarados) dos envios disparados. */
export const DESTINATARIOS_ENVIOS_FIXTURE = {
  2: [
    { id: 201, nome: "Bruno Completo", email: "b***@e***.org", lista_id: 4, status: "enviado", erro: null, processado_em: "2026-10-12T13:00:10Z" },
    { id: 202, nome: "Diego Só E-mail", email: "d***@e***.org", lista_id: 5, status: "pendente", erro: null, processado_em: null },
    { id: 203, nome: "Eva E-mail", email: "e***@e***.org", lista_id: 6, status: "pendente", erro: null, processado_em: null },
    { id: 204, nome: "[removido]", email: "a***@e***.org", lista_id: 4, status: "ignorado_optout", erro: null, processado_em: null },
  ],
  3: [
    { id: 301, nome: "Diego Só E-mail", email: "d***@e***.org", lista_id: 5, status: "enviado", erro: null, processado_em: "2026-10-10T10:01:00Z" },
    { id: 302, nome: "Bruno Completo", email: "b***@e***.org", lista_id: 5, status: "falhou", erro: "550 caixa inexistente", processado_em: "2026-10-10T10:01:05Z" },
  ],
  4: [
    { id: 401, nome: "Eva E-mail", email: "e***@e***.org", lista_id: 6, status: "pendente", erro: null, processado_em: null },
  ],
};

export const SEGMENTOS_FIXTURE = [
  {
    id: 1,
    nome: "Confirmados",
    criterios: {
      listas: [4, 5],
      estado: ["confirmado"],
      email_confirmado: null,
      inscritos_desde: null,
      inscritos_ate: null,
    },
    created_at: "2026-10-12T11:00:00Z",
    updated_at: "2026-10-12T11:00:00Z",
  },
  {
    id: 2,
    nome: "Lista antiga",
    criterios: {
      listas: [6, 77],
      estado: [],
      email_confirmado: null,
      inscritos_desde: null,
      inscritos_ate: null,
    },
    created_at: "2026-10-12T11:30:00Z",
    updated_at: "2026-10-12T11:30:00Z",
  },
];

export const PRIVACIDADE_BASE = "http://localhost:5173";
