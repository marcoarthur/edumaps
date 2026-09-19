// src/features/gestor/utils/pesquisaDraft.js
//
// Modelo e helpers do rascunho de pesquisa no wizard. Uma pergunta local tem
// sempre {id, texto, tipo, obrigatoria, opcoes:[{id,label}]} — o id é estável
// (uuid) para reordenação/preview e é aceito pelo backend (que o preserva).
import { uuid } from "@/shared/utils/uuid.js";
import { LIMITS, isOpcaoType } from "../constants/pesquisas.js";

/** Rascunho vazio. */
export function emptyDraft() {
  return { id: null, titulo: "", descricao: "", status: "rascunho", perguntas: [] };
}

/** Nova pergunta em branco, já com as opções mínimas padrão. */
export function newPergunta() {
  return {
    id: uuid(),
    texto: "",
    tipo: "unica",
    obrigatoria: false,
    opcoes: [{ id: uuid(), label: "" }, { id: uuid(), label: "" }],
  };
}

/**
 * Converte a resposta da API (GET/POST/PUT) no formato local do wizard.
 * @param {object} survey Shape de EduMaps::Roles::Business::Pesquisa::Surveys.
 */
export function surveyToDraft(survey) {
  return {
    id: survey.id,
    titulo: survey.titulo ?? "",
    descricao: survey.descricao ?? "",
    status: survey.status ?? "rascunho",
    perguntas: (survey.perguntas ?? []).map((p) => ({
      id: String(p.id),
      texto: p.texto,
      tipo: p.tipo,
      obrigatoria: !!p.obrigatoria,
      opcoes: (p.opcoes ?? []).map((o) => ({ id: String(o.id), label: o.label })),
    })),
  };
}

/** Converte o rascunho local no payload para o backend. */
export function draftToPayload(draft) {
  return {
    titulo: draft.titulo,
    descricao: draft.descricao,
    perguntas: draft.perguntas.map((p) => ({
      texto: p.texto,
      tipo: p.tipo,
      obrigatoria: p.obrigatoria,
      opcoes: isOpcaoType(p.tipo) ? p.opcoes.map((o) => ({ id: o.id, label: o.label })) : undefined,
    })),
  };
}

/** Validações por pergunta. Retorna array de mensagens (vazio = ok). */
export function perguntaErros(pergunta) {
  const erros = [];
  if (!pergunta.texto.trim()) erros.push("Escreva o texto da pergunta.");
  if (pergunta.texto.trim().length > LIMITS.PERGUNTA_TEXTO_MAX) {
    erros.push(`Texto com mais de ${LIMITS.PERGUNTA_TEXTO_MAX} caracteres.`);
  }
  if (isOpcaoType(pergunta.tipo)) {
    const labels = pergunta.opcoes.map((o) => o.label.trim());
    const filled = labels.filter(Boolean);
    if (filled.length < LIMITS.MIN_OPCOES) {
      erros.push(
        `Preencha pelo menos ${LIMITS.MIN_OPCOES} opções (${labels
          .map((l) => (l ? `"${l}"` : "vazia"))
          .join(", ")}).`,
      );
    } else if (filled.length > LIMITS.MAX_OPCOES) {
      erros.push(`Máximo de ${LIMITS.MAX_OPCOES} opções.`);
    } else if (new Set(filled).size !== filled.length) {
      erros.push("As opções não podem se repetir.");
    }
  }
  return erros;
}

/** títulos/descrição válidos para entrar numa etapa avançada. */
export function tituloValido(titulo) {
  return titulo.trim().length >= LIMITS.TITULO_MIN;
}

export function draftValidoParaFinalizar(draft) {
  if (!draft.id) return "A pesquisa ainda não foi salva.";
  if (!tituloValido(draft.titulo)) return "Dê um título à pesquisa.";
  if (tituloNotInLimit(draft.titulo)) return `Título com mais de ${LIMITS.TITULO_MAX} caracteres.`;
  if (draft.perguntas.length < 1) return "Adicione pelo menos uma pergunta.";
  if (draft.perguntas.length > LIMITS.MAX_PERGUNTAS) return `Máximo de ${LIMITS.MAX_PERGUNTAS} perguntas.`;
  for (const [i, p] of draft.perguntas.entries()) {
    const erros = perguntaErros(p);
    if (erros.length) return `Pergunta ${i + 1}: ${erros[0]}`;
  }
  return null;
}

function tituloNotInLimit(titulo) {
  return titulo.trim().length > LIMITS.TITULO_MAX;
}