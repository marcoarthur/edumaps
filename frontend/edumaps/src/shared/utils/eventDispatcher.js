// src/shared/utils/eventDispatcher.js
import { createEventDispatcher } from "svelte";
import { EVENTS } from "@/shared/constants/events";

/**
 * Cria um dispatcher tipado para eventos comuns.
 *
 * @param {any} component - O componente Svelte (geralmente `this` ou o contexto)
 * @returns {Object} Objeto com funções de dispatch para cada evento
 */
export function createTypedDispatcher(component) {
  const dispatch = createEventDispatcher();

  return {
    /**
     * Dispara evento de busca
     * @param {Object} payload - { escola, municipio }
     */
    dispatchSearch(payload) {
      dispatch(EVENTS.SEARCH, payload);
    },

    /** Dispara evento de limpeza */
    dispatchClear() {
      dispatch(EVENTS.CLEAR);
    },

    /**
     * Dispara mudança de página
     * @param {number} page
     */
    dispatchPageChange(page) {
      dispatch(EVENTS.PAGE_CHANGE, page);
    },

    /**
     * Dispara mudança de itens por página
     * @param {number} perPage
     */
    dispatchPerPageChange(perPage) {
      dispatch(EVENTS.PER_PAGE_CHANGE, perPage);
    },

    /**
     * Dispara erro genérico
     * @param {string|Error} error
     */
    dispatchError(error) {
      dispatch(EVENTS.ERROR, error);
    },

    /**
     * Dispara ação personalizada
     * @param {string} action
     * @param {any} payload
     */
    dispatchAction(action, payload) {
      dispatch(EVENTS.ACTION, { action, payload });
    },
  };
}
