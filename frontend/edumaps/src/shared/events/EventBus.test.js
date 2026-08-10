import { describe, it, expect, vi, beforeEach } from "vitest";
import { EventBus } from "./EventBus.js";

describe("EventBus", () => {
  /** @type {EventBus} */
  let bus;

  beforeEach(() => {
    bus = new EventBus();
  });

  describe("emit/on", () => {
    it("entrega o payload para o handler registrado no mesmo tipo", () => {
      const handler = vi.fn();
      bus.on("search", handler);

      bus.emit("search", { escola: "EMEF Exemplo" });

      expect(handler).toHaveBeenCalledWith(
        { escola: "EMEF Exemplo" },
        expect.objectContaining({ type: "search" }),
      );
    });

    it("não entrega o evento para handlers de outro tipo", () => {
      const handler = vi.fn();
      bus.on("clear", handler);

      bus.emit("search", {});

      expect(handler).not.toHaveBeenCalled();
    });

    it("inclui id, timestamp e source no evento completo", () => {
      const handler = vi.fn();
      bus.on("search", handler);

      bus.emit("search", {}, { source: "SchoolSearchForm" });

      const [, event] = handler.mock.calls[0];
      expect(event.id).toEqual(expect.any(String));
      expect(event.timestamp).toEqual(expect.any(Number));
      expect(event.source).toBe("SchoolSearchForm");
    });

    it("source é null quando não informado", () => {
      const handler = vi.fn();
      bus.on("search", handler);
      bus.emit("search", {});
      const [, event] = handler.mock.calls[0];
      expect(event.source).toBeNull();
    });

    it("a função devolvida por on() cancela a inscrição", () => {
      const handler = vi.fn();
      const unsubscribe = bus.on("search", handler);

      unsubscribe();
      bus.emit("search", {});

      expect(handler).not.toHaveBeenCalled();
    });

    it("suporta múltiplos handlers para o mesmo tipo", () => {
      const first = vi.fn();
      const second = vi.fn();
      bus.on("search", first);
      bus.on("search", second);

      bus.emit("search", { q: 1 });

      expect(first).toHaveBeenCalledOnce();
      expect(second).toHaveBeenCalledOnce();
    });

    it("um handler que lança erro não impede os demais de rodar", () => {
      const broken = vi.fn(() => {
        throw new Error("boom");
      });
      const healthy = vi.fn();
      bus.on("search", broken);
      bus.on("search", healthy);

      expect(() => bus.emit("search", {})).not.toThrow();
      expect(healthy).toHaveBeenCalledOnce();
    });
  });

  describe("aviso de evento órfão", () => {
    it("avisa no console quando emit() não tem nenhum handler (nem específico, nem onAny)", () => {
      const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

      bus.emit("ninguem-ouve", {});

      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('emit("ninguem-ouve")'),
      );
      warnSpy.mockRestore();
    });

    it("não avisa quando existe handler específico para o tipo", () => {
      const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
      bus.on("search", () => {});

      bus.emit("search", {});

      expect(warnSpy).not.toHaveBeenCalled();
      warnSpy.mockRestore();
    });

    it("não avisa quando existe handler onAny", () => {
      const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
      bus.onAny(() => {});

      bus.emit("qualquer-tipo", {});

      expect(warnSpy).not.toHaveBeenCalled();
      warnSpy.mockRestore();
    });
  });

  describe("once", () => {
    it("dispara apenas na primeira ocorrência", () => {
      const handler = vi.fn();
      bus.once("search", handler);

      bus.emit("search", { n: 1 });
      bus.emit("search", { n: 2 });

      expect(handler).toHaveBeenCalledOnce();
      expect(handler).toHaveBeenCalledWith({ n: 1 }, expect.anything());
    });
  });

  describe("onAny", () => {
    it("recebe eventos de qualquer tipo", () => {
      const handler = vi.fn();
      bus.onAny(handler);

      bus.emit("search", {});
      bus.emit("clear", {});

      expect(handler).toHaveBeenCalledTimes(2);
    });
  });

  describe("use (middlewares)", () => {
    it("roda os middlewares em ordem de registro antes dos handlers", () => {
      const order = [];
      bus.use((event, next) => {
        order.push("first");
        next(event);
      });
      bus.use((event, next) => {
        order.push("second");
        next(event);
      });
      bus.on("search", () => order.push("handler"));

      bus.emit("search", {});

      expect(order).toEqual(["first", "second", "handler"]);
    });

    it("um middleware pode transformar o payload antes dos handlers", () => {
      bus.use((event, next) =>
        next({ ...event, payload: { ...event.payload, enriched: true } }),
      );

      const handler = vi.fn();
      bus.on("search", handler);
      bus.emit("search", { q: "abc" });

      expect(handler).toHaveBeenCalledWith(
        { q: "abc", enriched: true },
        expect.anything(),
      );
    });

    it("um middleware que não chama next() bloqueia o evento", () => {
      bus.use((event, next) => {
        if (event.type === "search") return; // bloqueia
        next(event);
      });

      const handler = vi.fn();
      bus.on("search", handler);
      bus.emit("search", {});

      expect(handler).not.toHaveBeenCalled();
    });

    it("a função devolvida por use() remove o middleware", () => {
      const middleware = vi.fn((event, next) => next(event));
      const removeMiddleware = bus.use(middleware);

      removeMiddleware();
      bus.emit("search", {});

      expect(middleware).not.toHaveBeenCalled();
    });
  });

  describe("waitFor", () => {
    it("resolve com o payload quando o evento ocorre", async () => {
      const promise = bus.waitFor("search");
      bus.emit("search", { q: "abc" });
      await expect(promise).resolves.toEqual({ q: "abc" });
    });

    it("rejeita após o timeout se o evento não ocorrer", async () => {
      await expect(bus.waitFor("search", { timeoutMs: 20 })).rejects.toThrow(
        /expirou/,
      );
    });
  });

  describe("comandos (handle/request)", () => {
    it("request() resolve com o retorno do handler registrado", async () => {
      bus.handle("execute-search", async ({ escola }) => ({
        resultados: [escola],
      }));

      const result = await bus.request("execute-search", {
        escola: "EMEF Exemplo",
      });

      expect(result).toEqual({ resultados: ["EMEF Exemplo"] });
    });

    it("request() rejeita se não há handler registrado", async () => {
      await expect(bus.request("comando-inexistente")).rejects.toThrow(
        'Nenhum handler registrado para o comando "comando-inexistente"',
      );
    });

    it("handle() não permite registrar dois handlers para o mesmo comando", () => {
      bus.handle("execute-search", () => {});
      expect(() => bus.handle("execute-search", () => {})).toThrow(
        /Já existe um handler/,
      );
    });

    it("a função devolvida por handle() libera o comando para novo registro", () => {
      const removeHandler = bus.handle("execute-search", () => {});
      removeHandler();
      expect(() => bus.handle("execute-search", () => {})).not.toThrow();
    });
  });

  describe("destroy", () => {
    it("limpa handlers, middlewares e comandos", () => {
      const handler = vi.fn();
      bus.on("search", handler);
      bus.destroy();

      expect(() => bus.emit("search", {})).toThrow(/já foi destruído/);
      expect(handler).not.toHaveBeenCalled();
    });

    it("impede novas inscrições após destroy", () => {
      bus.destroy();
      expect(() => bus.on("search", () => {})).toThrow(/já foi destruído/);
      expect(() => bus.use(() => {})).toThrow(/já foi destruído/);
      expect(() => bus.handle("x", () => {})).toThrow(/já foi destruído/);
    });
  });
});
