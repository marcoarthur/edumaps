// src/shared/sentry.test.js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { initSentry, resolveConfig, scrub } from "./sentry.js";
import { eventBus, EVENTS } from "@/shared/events";

const mocks = vi.hoisted(() => ({
  init: vi.fn(),
  captureException: vi.fn(),
  setTag: vi.fn(),
}));

// O SDK só é importado dinamicamente quando há DSN; aqui simulamos o módulo.
vi.mock("@sentry/svelte", () => ({
  init: (...args) => mocks.init(...args),
  captureException: (...args) => mocks.captureException(...args),
  setTag: (...args) => mocks.setTag(...args),
}));

beforeEach(() => {
  mocks.init.mockClear();
  mocks.captureException.mockClear();
  mocks.setTag.mockClear();
});

describe("resolveConfig", () => {
  it("sem DSN nem overrides resolve para desenvolvimento/no-op", () => {
    const cfg = resolveConfig();
    expect(cfg.dsn).toBe("");
    expect(cfg.environment).toBe("development");
  });

  it("overrides vencem o ambiente", () => {
    const cfg = resolveConfig({
      dsn: "https://key@o1.ingest.sentry.io/1",
      release: "abc1234",
      environment: "test",
    });
    expect(cfg).toMatchObject({
      dsn: "https://key@o1.ingest.sentry.io/1",
      release: "abc1234",
      environment: "test",
    });
  });
});

describe("initSentry", () => {
  it("sem DSN retorna null e não toca o SDK (no-op)", async () => {
    const result = await initSentry();
    expect(result).toBeNull();
    expect(mocks.init).not.toHaveBeenCalled();
  });

  it("com DSN inicializa o SDK com privacidade e redação", async () => {
    const result = await initSentry({
      dsn: "https://key@o1.ingest.sentry.io/1",
      release: "abc1234",
    });
    expect(result).not.toBeNull();
    expect(mocks.init).toHaveBeenCalledOnce();
    const [opts] = mocks.init.mock.calls[0];
    expect(opts.dsn).toBe("https://key@o1.ingest.sentry.io/1");
    expect(opts.sendDefaultPii).toBe(false);
    expect(opts.tracesSampleRate).toBe(0);
    expect(typeof opts.beforeSend).toBe("function");
    expect(mocks.setTag).toHaveBeenCalledWith("app", "frontend");
  });
});

describe("ponte api:error (client.js) → Sentry", () => {
  it("captura ApiError >= 500 com contexto http", async () => {
    const sentry = await initSentry({ dsn: "https://key@o1.ingest.sentry.io/1" });

    const err = new Error("Boom interno");
    eventBus.emit(EVENTS.API_ERROR, {
      status: 503,
      url: "/api/gestor/me",
      message: "Boom interno",
      error: err,
    });

    expect(mocks.captureException).toHaveBeenCalledOnce();
    const [captured, ctx] = mocks.captureException.mock.calls[0];
    expect(captured).toBe(err);
    expect(ctx.tags).toMatchObject({ kind: "http", http_status: "503" });
    expect(ctx.contexts.http).toMatchObject({ url: "/api/gestor/me", status_code: 503 });
  });
});

describe("scrub", () => {
  it("redige chaves sensíveis em qualquer profundidade", () => {
    const event = {
      message: "ok",
      user: { email: "a@b.c", cpf: "123.456.789-01" },
      extra: { request: { headers: { authorization: "Bearer x" } }, safe: 1 },
      tags: { token: "abc", status: "500" },
    };
    const out = scrub(event);
    expect(out.message).toBe("ok");
    expect(out.user.email).toBe("a@b.c");
    expect(out.user.cpf).toBe("[redigido]");
    expect(out.extra.request.headers.authorization).toBe("[redigido]");
    expect(out.extra.safe).toBe(1);
    expect(out.tags.token).toBe("[redigido]");
    expect(out.tags.status).toBe("500");
  });

  it("mantém arrays intactos (sem chave sensível)", () => {
    expect(scrub(["a", { b: 1 }])).toEqual(["a", { b: 1 }]);
  });
});