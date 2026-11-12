// src/features/rede/api/redeApi.js
//
// Espelha EduMaps::Plugin::API::Rede (#394). Convite: anônimo. Demais: sessão
// com papel `rede`; as escolas vêm dos vínculos ativos da conta.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/rede";

/** @returns {Promise<{situacao: "valido"|"usado"|"vencido"|"substituido", nome: string, email: string}>} */
export function getConviteRede(token) {
  return apiClient.get(`${BASE}/convite/${token}`);
}

export function aceitarConviteRede(token, senha) {
  return apiClient.post(`${BASE}/convite/${token}`, { senha });
}

/** Conta e vínculos ativos. */
export function getRedeMe() {
  return apiClient.get(`${BASE}/me`);
}

/** @returns {Promise<{escolas: Array}>} escolas em atividade das redes da conta */
export function getRedeEscolas() {
  return apiClient.get(`${BASE}/escolas`);
}

/** Painel da rede (#396): por escola, o plano vigente e o andamento; e os totais. */
export function getRedePainel() {
  return apiClient.get(`${BASE}/painel`);
}

/** Planos não arquivados de uma escola da rede. */
export function getRedeEscolaPlanos(inep) {
  return apiClient.get(`${BASE}/escolas/${inep}/planos`);
}

/** Relatório de acompanhamento do plano, só leitura (o mesmo que a escola imprime). */
export function getRedeRelatorio(inep, planoId) {
  return apiClient.get(`${BASE}/escolas/${inep}/planos/${planoId}/relatorio`);
}
