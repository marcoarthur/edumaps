// src/features/gestor/mocks/fixtures.js
// Fixtures para as pesquisas do gestor (compatíveis com o backend).

export const GESTOR_SURVEY_PERFIL = {
  id: 7,
  cod_inep: 11000040,
  nome: "Marina Souza",
  email: "marina@edu.gov.br",
  telefone: "(69) 99999-0001",
  cargo: "Diretora",
  cpf_masc: "***.***.***-123",
  created_at: "2026-09-18T10:00:00",
  updated_at: "2026-09-18T10:00:00",
};

export const SURVEY_FIXTURES = [
  {
    id: 1,
    cod_inep: 11000040,
    gestor_id: 7,
    titulo: "Pesquisa de clima escolar",
    descricao: "Levantamento da percepção de pais e alunos.",
    status: "rascunho",
    token: "bbbbbbbb-cccc-0ddd-9abc-aaaaaaaaaaaa",
    gestor: { nome: "Marina Souza" },
    n_perguntas: 2,
    created_at: "2026-09-18T09:00:00",
    updated_at: "2026-09-18T09:30:00",
  },
  {
    id: 2,
    cod_inep: 11000040,
    gestor_id: 7,
    titulo: "Semana de ciências: temas de interesse",
    descricao: null,
    status: "publicada",
    token: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
    gestor: { nome: "Marina Souza" },
    n_perguntas: 1,
    created_at: "2026-09-10T14:00:00",
    updated_at: "2026-09-11T08:00:00",
  },
];

export const SURVEY_DETAIL = {
  id: 1,
  cod_inep: 11000040,
  gestor_id: 7,
  titulo: "Pesquisa de clima escolar",
  descricao: "Levantamento da percepção de pais e alunos.",
  status: "rascunho",
  token: "bbbbbbbb-cccc-0ddd-9abc-aaaaaaaaaaaa",
  created_at: "2026-09-18T09:00:00",
  updated_at: "2026-09-18T09:30:00",
  gestor: { nome: "Marina Souza", email: "marina@edu.gov.br" },
  perguntas: [
    {
      id: 11,
      ordem: 1,
      texto: "Você se sente acolhido pela escola?",
      tipo: "unica",
      obrigatoria: true,
      opcoes: [
        { id: "a", label: "Sim" },
        { id: "b", label: "Não" },
      ],
    },
    {
      id: 12,
      ordem: 2,
      texto: "Sugestões para melhorar o clima?",
      tipo: "texto",
      obrigatoria: false,
      opcoes: null,
    },
  ],
};

// Formulário público de uma pesquisa publicada (GET /publica/:token).
export const SURVEY_PUBLIC_FORM = {
  id: 2,
  titulo: "Semana de ciências: temas de interesse",
  descricao: "Quais atividades você gostaria na semana de ciências?",
  perguntas: [
    {
      id: 21,
      ordem: 1,
      texto: "Qual tema você mais quer?",
      tipo: "unica",
      obrigatoria: true,
      opcoes: [
        { id: "o1", label: "Tema 1" },
        { id: "o2", label: "Tema 2" },
        { id: "o3", label: "Tema 3" },
      ],
    },
    {
      id: 22,
      ordem: 2,
      texto: "Dê uma sugestão de atividade",
      tipo: "texto",
      obrigatoria: false,
      opcoes: null,
    },
  ],
};

export const PUBLIC_TOKEN = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

export const SESSION_GESTOR = {
  id: 7,
  cod_inep: 11000040,
  nome: "Marina Souza",
  email: "marina@edu.gov.br",
};

export const SESSION_TOKEN = "88888888-9999-4aaa-8bbb-cccccccccccc";

export const RESULTADOS_FIXTURE = {
  n_respostas: 4,
  perguntas: [
    {
      id: 21,
      ordem: 1,
      texto: "Qual tema você mais quer?",
      tipo: "unica",
      n_respondidas: 4,
      pct: 100,
      opcoes: [
        { id: "o1", label: "Tema 1", count: 2, pct: 50 },
        { id: "o2", label: "Tema 2", count: 1, pct: 25 },
        { id: "o3", label: "Tema 3", count: 1, pct: 25 },
      ],
    },
    {
      id: 22,
      ordem: 2,
      texto: "Dê uma sugestão de atividade",
      tipo: "texto",
      n_respondidas: 2,
      pct: 50,
      respostas_texto: [
        { texto: "Feira de foguetes!", respondida_em: "2026-09-12T10:00:00" },
        { texto: "Robótica com sucata", respondida_em: "2026-09-12T11:00:00" },
      ],
    },
  ],
};