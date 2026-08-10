// logger.js
//
// Middleware de log: cada evento passa por aqui antes de chegar aos
// handlers. Registrar com eventBus.use(logger) uma vez, na inicialização
// da app (ver main.js) — nenhuma feature precisa saber que o log existe.
export function logger(event, next) {
  if (import.meta.env?.DEV) {
    console.debug(
      `[event] ${event.type}`,
      event.payload,
      `(source: ${event.source ?? "?"})`,
    );
  }
  next(event);
}
