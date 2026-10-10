// src/shared/telemetry/tracker.test.js
import { describe, it, expect, vi } from "vitest";
import { createTelemetryTracker, sanitizeClientEvent } from "./tracker.js";

describe("sanitizeClientEvent", () => {
  it("descarta tipo fora da allowlist e entradas inválidas", () => {
    expect(sanitizeClientEvent({ type: "toast-add", payload: { x: 1 } })).toBeNull();
    expect(sanitizeClientEvent({ type: "desconhecido" })).toBeNull();
    expect(sanitizeClientEvent(null)).toBeNull();
    expect(sanitizeClientEvent("navigate")).toBeNull();
  });

  it("copia só as chaves permitidas — o texto da busca não sai do navegador", () => {
    const out = sanitizeClientEvent({
      type: "schools:search",
      payload: { q_len: 6, result_count: 25, escola: "Brasil", municipio: "Ubatuba" },
    });
    expect(out).toEqual({ type: "schools:search", payload: { q_len: 6, result_count: 25 } });
  });

  it("ignora chaves undefined e payload não-objeto", () => {
    expect(sanitizeClientEvent({ type: "navigate", payload: undefined })).toEqual({
      type: "navigate",
      payload: {},
    });
    expect(sanitizeClientEvent({ type: "navigate", payload: { route: undefined } })).toEqual({
      type: "navigate",
      payload: {},
    });
  });

  it("aceita tipos sem chaves (gestor:logout)", () => {
    expect(sanitizeClientEvent({ type: "gestor:logout", payload: { extra: 1 } })).toEqual({
      type: "gestor:logout",
      payload: {},
    });
  });
});

describe("createTelemetryTracker", () => {
  function harness(overrides = {}) {
    const sends = [];
    let intervalCb = null;
    let hiddenCb = null;
    let cleared = 0;

    const tracker = createTelemetryTracker({
      send: (batch, ctx) => sends.push({ batch, ctx }),
      now: () => 1000,
      timers: {
        setInterval: (fn) => {
          intervalCb = fn;
          return 7;
        },
        clearInterval: () => {
          cleared += 1;
        },
      },
      lifecycle: (onHidden) => {
        hiddenCb = onHidden;
        return () => {};
      },
      ...overrides,
    });

    return {
      tracker,
      sends,
      fireInterval: () => intervalCb(),
      fireHidden: () => hiddenCb(true),
      cleared: () => cleared,
    };
  }

  const navigate = (route = "/") => ({ type: "navigate", payload: { route } });

  it("bufferiza e envia no flush explícito, carimbando ts", () => {
    const { tracker, sends } = harness();
    tracker.record(navigate("/escola/panel"));

    expect(tracker.size()).toBe(1);

    tracker.flush();

    expect(sends).toHaveLength(1);
    expect(sends[0].batch).toEqual([
      { type: "navigate", payload: { route: "/escola/panel" }, ts: 1000 },
    ]);
    expect(sends[0].ctx).toEqual({ beacon: false });
    expect(tracker.size()).toBe(0);
  });

  it("não envia nada com o buffer vazio", () => {
    const { tracker, sends } = harness();
    tracker.flush();
    expect(sends).toHaveLength(0);
  });

  it("descarrega automaticamente ao atingir o teto do buffer", () => {
    const { tracker, sends } = harness({ maxBuffer: 2 });

    tracker.record(navigate("/a"));
    expect(sends).toHaveLength(0);

    tracker.record(navigate("/b"));
    expect(sends).toHaveLength(1);
    expect(sends[0].batch).toHaveLength(2);
    expect(tracker.size()).toBe(0);
  });

  it("descarrega no intervalo periódico", () => {
    const { tracker, sends, fireInterval } = harness();
    tracker.start();
    tracker.record(navigate("/a"));

    fireInterval();

    expect(sends).toHaveLength(1);
    expect(tracker.size()).toBe(0);
  });

  it("marca beacon=true quando a aba é escondida / página sai", () => {
    const { tracker, sends, fireHidden } = harness();
    tracker.record(navigate("/a"));

    fireHidden();

    expect(sends).toHaveLength(1);
    expect(sends[0].ctx).toEqual({ beacon: true });
  });

  it("descarta o lote e não propaga quando o envio falha", () => {
    const onError = vi.fn();
    const tracker = createTelemetryTracker({
      send: () => {
        throw new Error("rede fora");
      },
      now: () => 1,
      timers: { setInterval: () => 1, clearInterval: () => {} },
      lifecycle: () => () => {},
      onError,
    });

    tracker.record(navigate("/a"));

    expect(() => tracker.flush()).not.toThrow();
    expect(onError).toHaveBeenCalledTimes(1);
    expect(tracker.size()).toBe(0);
  });

  it("stop() para o timer e ignora novos registros", () => {
    const { tracker, sends, cleared } = harness();
    tracker.start();
    tracker.stop();

    tracker.record(navigate("/a"));
    tracker.flush();

    expect(cleared()).toBe(1);
    expect(sends).toHaveLength(0);
  });
});
