// src/features/gestor/mocks/reunioesFixtures.js
// Fixtures para contatos, grupos e reuniões (compatíveis com o backend).

export const CONTATOS_FIXTURE = [
  {
    id: 1,
    nome: "Ana Professora",
    email: "ana@edu.gov.br",
    telefone: "+5511999990001",
    cargo: "Professora",
    grupo_id: 1,
    grupo_nome: "Professores",
    updated_at: "2026-09-18T10:00:00",
  },
  {
    id: 2,
    nome: "João Pai",
    email: "joao@edu.gov.br",
    telefone: "+5511999990002",
    cargo: null,
    grupo_id: 2,
    grupo_nome: "Pais e responsáveis",
    updated_at: "2026-09-18T10:00:00",
  },
  {
    id: 3,
    nome: "Marina Responsável",
    email: "marina@edu.gov.br",
    telefone: "+5511999990003",
    cargo: null,
    grupo_id: null,
    grupo_nome: null,
    updated_at: "2026-09-18T10:00:00",
  },
];

export const GRUPOS_FIXTURE = [
  { id: 1, nome: "Professores", origem: "folha", n_contatos: 6, created_at: "2026-09-18T09:00:00" },
  { id: 2, nome: "Pais e responsáveis", origem: "manual", n_contatos: 12, created_at: "2026-09-18T09:00:00" },
];

export const REUNIOES_FIXTURE = [
  {
    id: 51,
    titulo: "Reunião de planejamento pedagógico",
    quando: "2026-10-10T14:30:00",
    duracao_min: 90,
    aviso_metodo: "todos",
    status: "agendada",
    n_participantes: 8,
    tem_ata: 0,
  },
  {
    id: 50,
    titulo: "Semana de ciências: temas de interesse",
    quando: "2026-09-05T09:00:00",
    duracao_min: 60,
    aviso_metodo: "whatsapp",
    status: "realizada",
    n_participantes: 12,
    tem_ata: 1,
  },
];

export const REUNIAO_DETAIL = {
  id: 51,
  cod_inep: 11000040,
  gestor_id: 7,
  titulo: "Reunião de planejamento pedagógico",
  quando: "2026-10-10T14:30:00",
  duracao_min: 90,
  onde_label: "Google Meet",
  onde_link: "https://meet.google.com/abc-defg-hij",
  aviso_metodo: "todos",
  status: "agendada",
  pauta_texto: "1. Metas do bimestre\n2. Calendário escolar\n3. Conselho de classe",
  ata_texto: null,
  created_at: "2026-09-18T09:00:00",
  updated_at: "2026-09-18T09:00:00",
  gestor: { nome: "Marina Souza" },
  anexos: [
    {
      id: 1,
      tipo: "pauta",
      nome_original: "pauta-setembro.pdf",
      mime: "application/pdf",
      tamanho: 24512,
      criado_em: "2026-09-18T09:05:00",
    },
  ],
  participantes: [
    { id: 1, nome: "Ana Professora", email: "ana@edu.gov.br", telefone: "+5511999990001", cargo: "Professora", via_grupo_id: null, via_grupo_nome: null },
    { id: 2, nome: "João Pai", email: "joao@edu.gov.br", telefone: "+5511999990002", cargo: null, via_grupo_id: 2, via_grupo_nome: "Pais e responsáveis" },
  ],
};

export const INEP_REUNIOES = "11000040";