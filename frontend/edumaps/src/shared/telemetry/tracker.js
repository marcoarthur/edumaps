// src/shared/telemetry/tracker.js
//
// Buffer + transporte dos eventos de telemetria do navegador. Genérico: não
// conhece domínio (gestor, escolas) — quem traduz evento-do-bus ->
// evento-de-cliente é o composition root (src/app/telemetry.js). O lote sai
// para `POST /api/session/events` (etapa 1 do backend).
//
// Por que buffer: a telemetria não pode virar um POST por clique. Os eventos
// se acumulam em memória e saem em lote (por tempo, por volume, ou no
// unload). Se o envio falhar, o lote é descartado — telemetria é fogo-e-
// esqueça e nunca deve crescer sem limite nem quebrar a aplicação.
//
// Privacidade: a ALLOWLIST abaixo espelha EduMaps::Controller::Session#type_map.
// Mesmo que um mapa mal configurado tente enviar outra chave (ex.: o texto
// digitado numa busca), ela é descartada AQUI, antes de sair do navegador.

/** tipo do cliente -> chaves aceitas do payload (espelha o backend). */
export const CLIENT_EVENT_TYPES = {
  navigate: ["route"],
  "schools:search": ["q_len", "result_count"],
  "gestor:login": ["ok"],
  "gestor:logout": [],
  "api:error": ["status", "route"],
};

/**
 * Normaliza um evento de cliente: descarta tipo fora da allowlist e copia só
 * as chaves permitidas. Devolve `null` se o tipo não for aceito.
 * @param {{type?: string, payload?: object}} raw
 * @returns {{type: string, payload: object}|null}
 */
export function sanitizeClientEvent(raw) {
  if (!raw || typeof raw !== "object") return null;
  const keys = CLIENT_EVENT_TYPES[raw.type];
  if (!keys) return null;

  const source = raw.payload && typeof raw.payload === "object" ? raw.payload : {};
  const payload = {};
  for (const key of keys) {
    if (source[key] !== undefined) payload[key] = source[key];
  }
  return { type: raw.type, payload };
}

function defaultLifecycle(onHidden) {
  if (typeof document === "undefined" || typeof window === "undefined") {
    return () => {};
  }
  const onVisibility = () => {
    if (document.visibilityState === "hidden") onHidden(true);
  };
  const onPageHide = () => onHidden(true);
  document.addEventListener("visibilitychange", onVisibility);
  window.addEventListener("pagehide", onPageHide);
  return () => {
    document.removeEventListener("visibilitychange", onVisibility);
    window.removeEventListener("pagehide", onPageHide);
  };
}

/**
 * Cria o tracker. Todas as dependências (tempo, timers, ciclo de vida, envio)
 * são injetáveis para os testes não tocarem em rede nem em timers reais.
 *
 * @param {object} options
 * @param {(batch: object[], ctx: {beacon: boolean}) => void} options.send
 * @param {number} [options.flushMs=30000]
 * @param {number} [options.maxBuffer=200]
 * @param {() => number} [options.now]
 * @param {{setInterval: Function, clearInterval: Function}} [options.timers]
 * @param {(onHidden: (beacon: boolean) => void) => (() => void)} [options.lifecycle]
 * @param {(err: unknown) => void} [options.onError]
 */
export function createTelemetryTracker({
  send,
  flushMs = 30000,
  maxBuffer = 200,
  now = () => Date.now(),
  timers = {
    setInterval: (fn, ms) => setInterval(fn, ms),
    clearInterval: (id) => clearInterval(id),
  },
  lifecycle = defaultLifecycle,
  onError = () => {},
} = {}) {
  let buffer = [];
  let timer = null;
  let stopped = false;

  function flush({ beacon = false } = {}) {
    if (stopped || buffer.length === 0) return;

    // não deixa o buffer passar do teto aceito pelo backend num único envio
    const batch = buffer.slice(0, maxBuffer);
    buffer = buffer.slice(batch.length);

    try {
      send(batch, { beacon });
    } catch (error) {
      onError(error);
    }
  }

  function record(raw) {
    if (stopped) return;
    const clean = sanitizeClientEvent(raw);
    if (!clean) return;

    buffer.push({ ...clean, ts: now() });
    if (buffer.length >= maxBuffer) flush();
  }

  function start() {
    if (stopped || timer) return;
    timer = timers.setInterval(() => flush(), flushMs);
  }

  function stop() {
    stopped = true;
    if (timer) {
      timers.clearInterval(timer);
      timer = null;
    }
  }

  // No unload (aba escondida / página saindo) o fetch pode ser abortado; o
  // caminho de beacon é acionado para o que já está no buffer.
  const offLifecycle = lifecycle((beacon) => flush({ beacon }));

  return {
    record,
    flush,
    start,
    stop,
    size: () => buffer.length,
    offLifecycle,
  };
}
