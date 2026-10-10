// src/app/telemetry.js
//
// Composition root da telemetria de sessão (etapa 2 — tracker do navegador).
// Aqui vive o único pedaço que conhece o domínio: o mapa de "evento do bus"
// -> "evento de cliente" aceito pelo backend (POST /api/session/events). O
// motor em `shared/telemetry` é genérico e não importa nenhuma feature.
//
// Regra de ouro de privacidade: NADA de texto digitado. A busca vira só
// `q_len` (comprimento) + `result_count`; a navegação vira o PADRÃO da rota
// (ex.: /p/:token), sem token nem query string.
import { eventBus, EVENTS } from "@/shared/events";
import { createTelemetryTracker } from "@/shared/telemetry";
import { SCHOOL_EVENTS } from "@/features/schools/constants/events.js";
import { GESTOR_EVENTS } from "@/features/gestor/constants/events.js";

export const SESSION_EVENTS_ENDPOINT = "/api/session/events";

// tipo no bus -> (payload) => evento de cliente. A allowlist do tracker corta
// qualquer chave a mais; aqui só montamos o mínimo.
const BUS_TO_CLIENT = {
  [EVENTS.NAVIGATE]: (p) => ({ type: "navigate", payload: { route: p?.route } }),
  [SCHOOL_EVENTS.SEARCH_DONE]: (p) => ({
    type: "schools:search",
    payload: { q_len: p?.q_len, result_count: p?.result_count },
  }),
  [GESTOR_EVENTS.LOGIN]: (p) => ({ type: "gestor:login", payload: { ok: p?.ok } }),
  [GESTOR_EVENTS.LOGOUT]: () => ({ type: "gestor:logout", payload: {} }),
  [EVENTS.API_ERROR]: (p) => ({
    type: "api:error",
    payload: { status: p?.status, route: p?.url },
  }),
};

/**
 * Traduz um evento do bus num evento de cliente, ou `null` se o tipo não for
 * de interesse da telemetria.
 * @param {{type: string, payload: *}} event
 */
export function mapBusEvent(event) {
  const mapper = BUS_TO_CLIENT[event?.type];
  return mapper ? mapper(event.payload) : null;
}

/** Envia o lote ao backend. Fogo-e-esqueça: erros são engolidos. */
export function sendBatch(batch, { beacon = false } = {}) {
  const body = JSON.stringify(batch);

  // No unload o fetch pode ser abortado; sendBeacon (quando disponível)
  // entrega o lote mesmo assim.
  if (beacon && typeof navigator !== "undefined" && navigator.sendBeacon) {
    try {
      const blob = new Blob([body], { type: "application/json" });
      navigator.sendBeacon(SESSION_EVENTS_ENDPOINT, blob);
      return;
    } catch {
      // sem beacon — cai no fetch abaixo
    }
  }

  fetch(SESSION_EVENTS_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    keepalive: true,
  }).catch(() => {});
}

/**
 * Liga o tracker ao barramento: todo evento mapeado vira um registro no
 * buffer. Devolve a função que desfaz a inscrição.
 */
export function createBusTelemetry({ bus = eventBus, tracker } = {}) {
  return bus.onAny((payload, event) => {
    const clientEvent = mapBusEvent(event);
    if (clientEvent) tracker.record(clientEvent);
  });
}

/**
 * Sobe a telemetria: cria o tracker, começa o flush periódico, liga no bus e
 * registra o comando `telemetry.flush`. Chamar uma vez na inicialização
 * (main.js), antes de montar o app.
 */
export function startTelemetry({ bus = eventBus, send = sendBatch, ...trackerOptions } = {}) {
  const tracker = createTelemetryTracker({ send, ...trackerOptions });
  tracker.start();
  const unsubscribe = createBusTelemetry({ bus, tracker });
  bus.handle("telemetry.flush", () => tracker.flush());

  return { tracker, unsubscribe };
}
