// src/features/gestor/api/gestorEnviosApi.js
//
// Envio por e-mail para listas com QR (issue #216, Fase 3 — contrato congelado
// da onda 1). Base /api/gestor/:cod_inep/canais — Bearer + posse do :cod_inep.
//
// Envios:
//   GET    /envios                       ?status&page&per_page → {items,total,page,per_page}
//   POST   /envios                       {alvo_tipo, alvo_id, operacao, assunto, corpo} → 201
//   GET    /envios/limites               saldo do dia, cota, suspensão, SMTP
//   GET    /envios/:id                   envio
//   PATCH  /envios/:id                   campos do POST (só rascunho; 409 senão)
//   DELETE /envios/:id                   {ok:1} (só rascunho)
//   POST   /envios/:id/previa            {assunto, texto, estimativa}
//   POST   /envios/:id/teste             202 {enviado, para} · 409 {motivo} · 429 · 502
//   POST   /envios/:id/disparar          {agendado_para?} → 202 envio · 400 · 409 {motivo, saldo?, teto?}
//   POST   /envios/:id/cancelar          envio · 409
//   GET    /envios/:id/destinatarios     ?status&page&per_page → {items,total,page,per_page}
//
// Segmentos (listas dinâmicas):
//   GET    /segmentos                    [segmento]
//   POST   /segmentos                    {nome, criterios} → 201 · 400 · 409
//   GET/PUT/DELETE /segmentos/:id
//   POST   /segmentos/previa             {criterios} → {destinatarios, amostra, listas_ignoradas}
//   GET    /segmentos/:id/previa         idem
import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/canais`;
const ENVIOS = (inep) => `${BASE(inep)}/envios`;
const SEGMENTOS = (inep) => `${BASE(inep)}/segmentos`;

const CAMPOS_ENVIO = ["alvo_tipo", "alvo_id", "operacao", "assunto", "corpo"];

const comoPagina = (data) => ({
  items: data?.items ?? [],
  total: data?.total ?? 0,
  page: data?.page ?? 1,
  per_page: data?.per_page ?? 20,
});

// ---------------------------------------------------------------- envios

/**
 * @param {{status?: string, page?: number, per_page?: number}} [filtro]
 * @returns {Promise<{items: Array, total: number, page: number, per_page: number}>}
 */
export function listEnvios(inep, { status, page, per_page } = {}) {
  return apiClient.get(ENVIOS(inep), { status, page, per_page }).then(comoPagina);
}

/** @returns {Promise<object>} envio criado (rascunho) */
export function createEnvio(inep, { alvo_tipo, alvo_id, operacao, assunto, corpo }) {
  return apiClient.post(ENVIOS(inep), {
    alvo_tipo,
    alvo_id: Number(alvo_id),
    operacao,
    assunto,
    corpo,
  });
}

/** Altera um rascunho. Só envia os campos passados. */
export function atualizarEnvio(inep, id, mudancas = {}) {
  const body = {};
  for (const campo of CAMPOS_ENVIO) {
    if (mudancas[campo] !== undefined) {
      body[campo] = campo === "alvo_id" ? Number(mudancas[campo]) : mudancas[campo];
    }
  }
  return apiClient.patch(`${ENVIOS(inep)}/${id}`, body);
}

export function getEnvio(inep, id) {
  return apiClient.get(`${ENVIOS(inep)}/${id}`);
}

export function deleteEnvio(inep, id) {
  return apiClient.delete(`${ENVIOS(inep)}/${id}`);
}

/**
 * @returns {Promise<{enabled: boolean, smtp_disponivel: boolean, ritmo_por_minuto: number,
 *   cota_diaria: number, max_destinatarios: number, enviados_hoje: number, saldo_hoje: number,
 *   suspensao: null|{motivo: string, suspenso_em: string}}>}
 */
export function getLimitesEnvio(inep) {
  return apiClient.get(`${ENVIOS(inep)}/limites`);
}

/** @returns {Promise<{assunto: string, texto: string, estimativa: {destinatarios: number, ignorados_optout: number, ignorados_duplicado: number}}>} */
export function previaEnvio(inep, id) {
  return apiClient.post(`${ENVIOS(inep)}/${id}/previa`);
}

/** @returns {Promise<{enviado: number, para: string}>} */
export function testeEnvio(inep, id) {
  return apiClient.post(`${ENVIOS(inep)}/${id}/teste`);
}

/**
 * Dispara agora (sem data) ou agenda (`agendado_para` ISO UTC).
 * @param {string|null} [agendado_para]
 */
export function dispararEnvio(inep, id, agendado_para = null) {
  return apiClient.post(
    `${ENVIOS(inep)}/${id}/disparar`,
    agendado_para ? { agendado_para } : {},
  );
}

export function cancelarEnvio(inep, id) {
  return apiClient.post(`${ENVIOS(inep)}/${id}/cancelar`);
}

/**
 * Destinatários mascarados do envio.
 * @param {{status?: string, page?: number, per_page?: number}} [filtro]
 */
export function listDestinatarios(inep, id, { status, page, per_page } = {}) {
  return apiClient
    .get(`${ENVIOS(inep)}/${id}/destinatarios`, { status, page, per_page })
    .then(comoPagina);
}

// ------------------------------------------------------------- segmentos

/** Normaliza os critérios para o formato do contrato. */
export function normalizarCriterios(c = {}) {
  return {
    listas: (c.listas ?? []).map(Number),
    estado: [...(c.estado ?? [])],
    email_confirmado:
      c.email_confirmado === true || c.email_confirmado === false ? c.email_confirmado : null,
    inscritos_desde: c.inscritos_desde || null,
    inscritos_ate: c.inscritos_ate || null,
  };
}

export function listSegmentos(inep) {
  return apiClient
    .get(SEGMENTOS(inep))
    .then((d) => (Array.isArray(d) ? d : (d?.items ?? d?.segmentos ?? [])));
}

export function getSegmento(inep, id) {
  return apiClient.get(`${SEGMENTOS(inep)}/${id}`);
}

export function createSegmento(inep, { nome, criterios }) {
  return apiClient.post(SEGMENTOS(inep), { nome, criterios: normalizarCriterios(criterios) });
}

export function atualizarSegmento(inep, id, { nome, criterios }) {
  return apiClient.put(`${SEGMENTOS(inep)}/${id}`, {
    nome,
    criterios: normalizarCriterios(criterios),
  });
}

export function deleteSegmento(inep, id) {
  return apiClient.delete(`${SEGMENTOS(inep)}/${id}`);
}

/** @returns {Promise<{destinatarios: number, amostra: Array<{nome: string|null, email: string}>, listas_ignoradas: number[]}>} */
export function previaCriterios(inep, criterios) {
  return apiClient.post(`${SEGMENTOS(inep)}/previa`, {
    criterios: normalizarCriterios(criterios),
  });
}

export function previaSegmento(inep, id) {
  return apiClient.get(`${SEGMENTOS(inep)}/${id}/previa`);
}
