// src/shared/constants/events.js
//
// Eventos cross-feature: usados por mais de uma feature ou pelo shell da
// aplicação (ex.: um sistema de toasts em shared/ui reagindo a qualquer
// feature que precise notificar o usuário).
//
// Eventos específicos de UMA feature (ex.: busca de escolas) NÃO ficam
// aqui — vivem em features/<feature>/constants/events.js. Centralizar
// tudo neste arquivo criaria um enum gigante e acoplaria todas as
// features entre si só por compartilharem um arquivo de constantes.
export const EVENTS = {
  ERROR: "error",
  API_ERROR: "api:error",
  // Navegação do SPA (shell). Emitido por App.svelte a cada mudança de rota;
  // consumido pela telemetria (shared/telemetry) e, no futuro, por qualquer
  // observador que precise saber "a tela mudou" sem se acoplar ao roteador.
  NAVIGATE: "app:navigate",
  TOAST_ADD: "toast-add",
  TOAST_REMOVE: "toast-remove",
};
