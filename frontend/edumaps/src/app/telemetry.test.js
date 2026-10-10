// src/app/telemetry.test.js
import { describe, it, expect } from "vitest";
import { EventBus, EVENTS } from "@/shared/events";
import { SCHOOL_EVENTS } from "@/features/schools/constants/events.js";
import { GESTOR_EVENTS } from "@/features/gestor/constants/events.js";
import { createBusTelemetry, mapBusEvent, startTelemetry } from "./telemetry.js";

const noopTimers = { setInterval: () => 1, clearInterval: () => {} };
const noLifecycle = () => () => {};

describe("mapBusEvent", () => {
  it("navegação -> navigate com o PADRÃO da rota (sem token/query)", () => {
    expect(mapBusEvent({ type: EVENTS.NAVIGATE, payload: { route: "/p/:token" } })).toEqual({
      type: "navigate",
      payload: { route: "/p/:token" },
    });
  });

  it("busca -> schools:search só com q_len/result_count", () => {
    expect(
      mapBusEvent({
        type: SCHOOL_EVENTS.SEARCH_DONE,
        payload: { q_len: 6, result_count: 25, escola: "Brasil" },
      }),
    ).toEqual({ type: "schools:search", payload: { q_len: 6, result_count: 25 } });
  });

  it("login/logout do gestor", () => {
    expect(mapBusEvent({ type: GESTOR_EVENTS.LOGIN, payload: { ok: false } })).toEqual({
      type: "gestor:login",
      payload: { ok: false },
    });
    expect(mapBusEvent({ type: GESTOR_EVENTS.LOGOUT, payload: undefined })).toEqual({
      type: "gestor:logout",
      payload: {},
    });
  });

  it("erro de API usa a url como rota", () => {
    expect(
      mapBusEvent({ type: EVENTS.API_ERROR, payload: { status: 503, url: "/api/gestor/me" } }),
    ).toEqual({ type: "api:error", payload: { status: 503, route: "/api/gestor/me" } });
  });

  it("ignora eventos sem interesse", () => {
    expect(mapBusEvent({ type: EVENTS.TOAST_ADD, payload: {} })).toBeNull();
  });
});

describe("createBusTelemetry", () => {
  it("registra no tracker apenas os eventos mapeados", () => {
    const bus = new EventBus();
    const recorded = [];
    createBusTelemetry({ bus, tracker: { record: (e) => recorded.push(e) } });

    bus.emit(EVENTS.NAVIGATE, { route: "/about" });
    bus.emit(EVENTS.TOAST_ADD, { message: "oi" });
    bus.emit(SCHOOL_EVENTS.SEARCH_DONE, { q_len: 4, result_count: 2 });

    expect(recorded).toEqual([
      { type: "navigate", payload: { route: "/about" } },
      { type: "schools:search", payload: { q_len: 4, result_count: 2 } },
    ]);
  });
});

describe("startTelemetry", () => {
  it("liga o bus ao tracker e descarrega o lote no comando telemetry.flush", async () => {
    const bus = new EventBus();
    const sends = [];

    startTelemetry({
      bus,
      send: (batch) => sends.push(batch),
      timers: noopTimers,
      lifecycle: noLifecycle,
    });

    bus.emit(EVENTS.NAVIGATE, { route: "/escola/panel" });
    bus.emit(SCHOOL_EVENTS.SEARCH_DONE, { q_len: 6, result_count: 25, escola: "Brasil" });

    await bus.request("telemetry.flush");

    expect(sends).toHaveLength(1);
    expect(sends[0]).toEqual([
      { type: "navigate", payload: { route: "/escola/panel" }, ts: expect.any(Number) },
      { type: "schools:search", payload: { q_len: 6, result_count: 25 }, ts: expect.any(Number) },
    ]);
    // garantia de privacidade: o texto digitado nunca aparece no lote
    expect(JSON.stringify(sends)).not.toContain("Brasil");
  });
});
