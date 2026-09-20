// src/features/gestor/utils/reuniaoDraft.js
//
// Rascunho do wizard de reunião: normaliza entrada/saída entre o formulário
// (datetime-local, selects) e o payload do backend. O servidor é quem expande
// grupos em participantes — aqui só montamos ids e contagens para o preview.

import { REUNIAO_LIMITS as L } from "../constants/reunioes.js";

/**
 * Estado inicial do formulário (passos: 1 quando · 2 quem · 3 aviso · 4 pauta).
 */
export function estadoInicial(isEdit = false) {
  return {
    titulo: "",
    dataLocal: isEdit ? null : "",
    duracaoMin: L.DURACAO_DEFAULT,
    ondeLabel: "",
    ondeLink: "",
    avisoMetodo: "todos",
    pautaTexto: "",
    contatoIds: new Set(),
    grupoIds: new Set(),
  };
}

/** Converte "2025-01-31T14:30" (datetime-local) em payload do backend. */
export function quandoParaBackend(dataLocal) {
  if (!dataLocal) return null;
  return dataLocal.replace("T", " ").slice(0, 16);
}

/**
 * Monta o payload de create/update a partir do estado do formulário.
 * Remove o Set (o cache do frontend usa Sets para toggle); o backend recebe
 * arrays de ids.
 * @returns {object}
 */
export function buildReuniaoPayload(estado) {
  return {
    titulo: estado.titulo.trim(),
    quando: quandoParaBackend(estado.dataLocal),
    duracao_min: Number(estado.duracaoMin) || L.DURACAO_DEFAULT,
    onde_label: estado.ondeLabel.trim() || null,
    onde_link: estado.ondeLink.trim() || null,
    aviso_metodo: estado.avisoMetodo,
    pauta_texto: estado.pautaTexto.trim() || null,
    contato_ids: [...estado.contatoIds].map(Number).filter(Boolean),
    grupo_ids: [...estado.grupoIds].map(Number).filter(Boolean),
  };
}

/** Conversor de Set -> array para evitar duplicação na hora de salvar. */
export function idsParaArray(set) {
  return [...set].map(Number).filter(Boolean);
}

/**
 * Atalhos de erro do formulário (passo a passo). Devolve a mensagem do
 * primeiro passo inválido ou null.
 */
export function primeiroErro(estado) {
  if (!estado.titulo.trim() || estado.titulo.trim().length < L.TITULO_MIN) {
    return "Dê um título para a reunião (mínimo de 3 letras).";
  }
  if (!estado.dataLocal) {
    return "Escolha a data e o horário da reunião.";
  }
  if (
    (estado.duracaoMin || 0) < L.DURACAO_MIN ||
    (estado.duracaoMin || 0) > L.DURACAO_MAX
  ) {
    return `A duração deve ficar entre ${L.DURACAO_MIN} e ${L.DURACAO_MAX} minutos.`;
  }
  if (estado.contatoIds.size === 0 && estado.grupoIds.size === 0) {
    return "Selecione ao menos uma pessoa ou grupo.";
  }
  return null;
}

/** Total de participantes para o preview (pessoas diretas + membros dos grupos). */
export function participantesPreview(contatos, grupos, estado) {
  const diretos = contatos.filter((c) => estado.contatoIds.has(c.id));
  const grupoSel = grupos.filter((g) => estado.grupoIds.has(g.id));
  const nExpandidos = grupoSel.reduce((soma, g) => soma + (g.n_contatos ?? 0), 0);
  return { diretos, grupoSel, nExpandidos, total: diretos.length + nExpandidos };
}