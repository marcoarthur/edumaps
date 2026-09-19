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