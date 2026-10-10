// src/features/school/constans/events.js
//
// Eventos (fatos) e comandos (intenções com resposta) da feature schools.
// Namespace "schools/" no valor das strings evita colisão com eventos de
// mesmo nome em outras features (ex.: um futuro "map/search").
export const SCHOOL_EVENTS = {
  SEARCH: "schools/search",
  // Busca do usuário concluída (transição loading -> pronto), com o RESUMO
  // do resultado — e nunca o texto digitado: `q_len` é só o comprimento do
  // termo e `result_count` o total de escolas. Consumido pela telemetria.
  SEARCH_DONE: "schools/search-done",
  CLEAR: "schools/clear",
  PAGE_CHANGE: "schools/page-change",
  PER_PAGE_CHANGE: "schools/per-page-change",
};

// Comandos: intenção com resposta, exatamente um handler (ver
// eventBus.handle()/eventBus.request() em shared/events/EventBus.js).
export const SCHOOL_COMMANDS = {
  EXECUTE_SEARCH: "schools/execute-search",
};
