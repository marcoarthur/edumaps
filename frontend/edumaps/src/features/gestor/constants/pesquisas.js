// src/features/gestor/constants/pesquisas.js
//
// Constantes do módulo "Pesquisas do gestor": tipos de resposta, limites e
// rótulos. Espelham as validações do backend (EduMaps::Controller::Pesquisa).

export const ANSWER_TYPES = [
  {
    value: "unica",
    label: "Escolha única",
    hint: "Marcar uma resposta (ex.: sim / não)",
  },
  {
    value: "multipla",
    label: "Múltipla escolha",
    hint: "Marcar várias respostas",
  },
  { value: "dropdown", label: "Lista suspensa", hint: "Selecionar numa lista" },
  { value: "texto", label: "Resposta livre", hint: "Escrever um texto curto" },
];

/** @type {Record<string,string>} */
export const ANSWER_TYPE_LABELS = Object.fromEntries(
  ANSWER_TYPES.map((t) => [t.value, t.label]),
);

export const STATUS_LABELS = {
  rascunho: "Rascunho",
  publicada: "Publicada",
  arquivada: "Arquivada",
};

export const LIMITS = {
  TITULO_MIN: 3,
  TITULO_MAX: 120,
  DESCRICAO_MAX: 500,
  PERGUNTA_TEXTO_MAX: 500,
  MAX_PERGUNTAS: 30,
  MIN_OPCOES: 2,
  MAX_OPCOES: 12,
  AUTOSAVE_MS: 600,
  NOME_MIN: 2,
  NOME_MAX: 80,
  TELEFONE_MIN: 8,
  TELEFONE_MAX: 20,
  CARGO_MIN: 3,
  CARGO_MAX: 60,
  SENHA_MIN: 6,
  SENHA_MAX: 64,
};

export function isOpcaoType(tipo) {
  return tipo !== "texto";
}