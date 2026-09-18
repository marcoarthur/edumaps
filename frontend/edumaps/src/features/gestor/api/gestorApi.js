// src/features/gestor/api/gestorApi.js
//
// Espelha EduMaps::Plugin::API::Gestor / EduMaps::Controller::Gestor.
// Toda chamada da feature passa por aqui (facilita mock e troca de endpoint).
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/gestor";

/**
 * Raio-x da escola para o gestor.
 * @param {string|number} codInep
 * @returns {Promise<object>} ver EduMaps::Roles::Business::Gestor::Overview
 */
export function getGestorPanel(codInep) {
  return apiClient.get(`${BASE}/${codInep}/painel`);
}
