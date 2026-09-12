import "@testing-library/jest-dom/vitest";
import { beforeAll, afterEach, afterAll } from "vitest";
import { server } from "./mocks/server.js";

// jsdom não implementa ResizeObserver — @carbon/charts usa na inicialização
// (opção default `resizable: true`) para observar o holder do gráfico.
if (typeof globalThis.ResizeObserver === "undefined") {
  class ResizeObserverPolyfill {
    constructor(callback) {
      this._callback = callback;
    }
    observe() {}
    unobserve() {}
    disconnect() {}
  }
  globalThis.ResizeObserver = ResizeObserverPolyfill;
}

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
