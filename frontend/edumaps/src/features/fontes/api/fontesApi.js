// src/features/fontes/api/fontesApi.js
//
// Catálogo público das fontes (#428). Uma busca por carga de página: todos
// os selos de fonte da tela compartilham a mesma promessa.
import { apiClient } from "@/shared/api/client.js";

let promessa = null;

/** @returns {Promise<Array<object>>} */
export function getFontes() {
  if (!promessa) {
    promessa = apiClient.get("/api/fontes").catch((err) => {
      promessa = null; // tenta de novo na próxima tela
      throw err;
    });
  }
  return promessa;
}

/** Só para testes: esquece a promessa guardada. */
export function _resetFontes() {
  promessa = null;
}
