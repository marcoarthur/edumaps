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

// jsdom não implementa `SVGElement.transform` (SVGAnimatedTransformList) —
// o `@carbon/charts` usa `el.transform.baseVal.consolidate()` quando aplica
// zoom/pan em gráficos. Sem o polyfill, o acesso a `baseVal` estoura a cada
// frame de animação e o erro vira *unhandled* no vitest: todos os testes
// passam, mas o processo sai com exit 1 (falso negativo no CI).
if (typeof globalThis.SVGElement !== "undefined" && !globalThis.SVGElement.prototype.transform) {
  Object.defineProperty(globalThis.SVGElement.prototype, "transform", {
    get() {
      return {
        baseVal: {
          // Sem transform aplicado no gráfico de teste: devolve null e o
          // carbon trata como matriz identidade.
          consolidate() {
            return null;
          },
        },
      };
    },
  });
}

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
