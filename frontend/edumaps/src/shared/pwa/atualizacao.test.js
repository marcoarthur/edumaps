import { describe, it, expect, vi, afterEach } from "vitest";
import {
  decidirReloadUnico,
  ehErroDeChunk,
  instalarRecargaDeChunk,
  criarAtualizador,
  CHAVE_RELOAD,
  VALIDADE_MARCADOR_MS,
} from "./atualizacao.js";

function memoria() {
  const m = new Map();
  return {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: (k) => m.delete(k),
  };
}

const quebrado = {
  getItem() {
    throw new Error("SecurityError");
  },
  setItem() {
    throw new Error("SecurityError");
  },
};

describe("decidirReloadUnico", () => {
  it("sem marcador: recarrega e grava o marcador", () => {
    const s = memoria();
    expect(decidirReloadUnico({ storage: s, agora: 1000 })).toBe(true);
    expect(s.getItem(CHAVE_RELOAD)).toBe("1000");
  });

  it("com marcador válido: não recarrega de novo (sem laço)", () => {
    const s = memoria();
    s.setItem(CHAVE_RELOAD, "1000");
    expect(decidirReloadUnico({ storage: s, agora: 1000 + 5_000 })).toBe(false);
  });

  it("marcador expirado: recarrega de novo e renova o marcador", () => {
    const s = memoria();
    s.setItem(CHAVE_RELOAD, "1000");
    const agora = 1000 + VALIDADE_MARCADOR_MS + 1;
    expect(decidirReloadUnico({ storage: s, agora })).toBe(true);
    expect(s.getItem(CHAVE_RELOAD)).toBe(String(agora));
  });

  it("sessionStorage indisponível: não recarrega", () => {
    expect(decidirReloadUnico({ storage: quebrado, agora: 1 })).toBe(false);
    expect(decidirReloadUnico({ storage: null, agora: 1 })).toBe(false);
  });

  it("gravação que não persiste: não recarrega", () => {
    const s = { getItem: () => null, setItem: () => {} };
    expect(decidirReloadUnico({ storage: s, agora: 1 })).toBe(false);
  });
});

describe("ehErroDeChunk", () => {
  it("reconhece as mensagens dos navegadores", () => {
    expect(ehErroDeChunk(new TypeError("Failed to fetch dynamically imported module: /assets/x-1.js"))).toBe(true);
    expect(ehErroDeChunk(new Error("error loading dynamically imported module"))).toBe(true);
    expect(ehErroDeChunk(new TypeError("Importing a module script failed."))).toBe(true);
    expect(ehErroDeChunk(new Error("boom"))).toBe(false);
    expect(ehErroDeChunk(undefined)).toBe(false);
  });
});

describe("instalarRecargaDeChunk", () => {
  function preparar(storage = memoria()) {
    const recarregar = vi.fn();
    const aoFalhar = vi.fn();
    const desligar = instalarRecargaDeChunk({
      win: window,
      storage,
      recarregar,
      aoFalhar,
      agora: () => 5000,
    });
    return { recarregar, aoFalhar, desligar, storage };
  }

  let desligar;
  afterEach(() => desligar?.());

  it("vite:preloadError → recarrega uma vez e evita o throw", () => {
    const p = preparar();
    desligar = p.desligar;
    const ev = new Event("vite:preloadError", { cancelable: true });
    window.dispatchEvent(ev);
    expect(p.recarregar).toHaveBeenCalledTimes(1);
    expect(ev.defaultPrevented).toBe(true);

    // segunda falha dentro da validade: não recarrega, mostra o aviso
    window.dispatchEvent(new Event("vite:preloadError", { cancelable: true }));
    expect(p.recarregar).toHaveBeenCalledTimes(1);
    expect(p.aoFalhar).toHaveBeenCalledTimes(1);
  });

  it("rejeição de import dinâmico → recarrega; outras rejeições são ignoradas", () => {
    const p = preparar();
    desligar = p.desligar;
    const outra = new Event("unhandledrejection");
    outra.reason = new Error("qualquer");
    window.dispatchEvent(outra);
    expect(p.recarregar).not.toHaveBeenCalled();

    const chunk = new Event("unhandledrejection");
    chunk.reason = new TypeError("Failed to fetch dynamically imported module");
    window.dispatchEvent(chunk);
    expect(p.recarregar).toHaveBeenCalledTimes(1);
  });

  it("sessionStorage indisponível → não recarrega, mostra o aviso", () => {
    const p = preparar(quebrado);
    desligar = p.desligar;
    window.dispatchEvent(new Event("vite:preloadError", { cancelable: true }));
    expect(p.recarregar).not.toHaveBeenCalled();
    expect(p.aoFalhar).toHaveBeenCalledTimes(1);
  });
});

// --- Fluxo do aviso -------------------------------------------------------

class FakeTarget {
  constructor() {
    this.l = {};
  }
  addEventListener(t, fn) {
    (this.l[t] ||= new Set()).add(fn);
  }
  removeEventListener(t, fn) {
    this.l[t]?.delete(fn);
  }
  emit(t) {
    for (const fn of this.l[t] || []) fn({ type: t });
  }
}

function fakeSW({ controller = {} } = {}) {
  const sw = new FakeTarget();
  sw.controller = controller;
  const reg = new FakeTarget();
  reg.waiting = null;
  reg.installing = null;
  reg.update = vi.fn(() => Promise.resolve());
  sw.register = vi.fn(() => Promise.resolve(reg));
  return { sw, reg };
}

function worker() {
  const w = new FakeTarget();
  w.state = "installing";
  w.postMessage = vi.fn();
  return w;
}

describe("criarAtualizador", () => {
  it("onNeedRefresh → aviso visível; Depois → esconde", () => {
    const { sw } = fakeSW();
    const a = criarAtualizador({ sw, recarregar: vi.fn(), doc: null });
    const vistos = [];
    a.subscribe((v) => vistos.push(v));
    expect(vistos.at(-1).visivel).toBe(false);
    a.onNeedRefresh(worker());
    expect(vistos.at(-1)).toEqual({ visivel: true, motivo: "nova-versao" });
    a.adiar();
    expect(vistos.at(-1).visivel).toBe(false);
  });

  it("Atualizar → SKIP_WAITING ao SW em espera e reload único no controllerchange", () => {
    const { sw } = fakeSW();
    const recarregar = vi.fn();
    const a = criarAtualizador({ sw, recarregar, doc: null });
    const w = worker();
    a.onNeedRefresh(w);
    a.atualizar();
    expect(w.postMessage).toHaveBeenCalledWith({ type: "SKIP_WAITING" });
    expect(recarregar).not.toHaveBeenCalled();
    sw.emit("controllerchange");
    sw.emit("controllerchange");
    expect(recarregar).toHaveBeenCalledTimes(1);
  });

  it("sem clique não recarrega em controllerchange (outra aba atualizou)", () => {
    const { sw } = fakeSW();
    const recarregar = vi.fn();
    const a = criarAtualizador({ sw, recarregar, doc: null });
    a.onNeedRefresh(worker());
    sw.emit("controllerchange");
    expect(recarregar).not.toHaveBeenCalled();
  });

  it("erro de chunk → aviso; Atualizar só recarrega", () => {
    const { sw } = fakeSW();
    const recarregar = vi.fn();
    const a = criarAtualizador({ sw, recarregar, doc: null });
    let v;
    a.subscribe((x) => (v = x));
    a.mostrarErroChunk();
    expect(v).toEqual({ visivel: true, motivo: "erro-chunk" });
    a.atualizar();
    expect(recarregar).toHaveBeenCalledTimes(1);
  });

  it("registrar: SW já em espera mostra o aviso; updatefound → installed também", async () => {
    const { sw, reg } = fakeSW();
    const w0 = worker();
    reg.waiting = w0;
    const a = criarAtualizador({ sw, recarregar: vi.fn(), doc: null, intervaloMs: 1e9 });
    let v;
    a.subscribe((x) => (v = x));
    await a.registrar("/sw.js");
    expect(sw.register).toHaveBeenCalledWith("/sw.js", { scope: "/" });
    expect(v.visivel).toBe(true);

    a.adiar();
    const w1 = worker();
    reg.installing = w1;
    reg.emit("updatefound");
    w1.state = "installed";
    w1.emit("statechange");
    expect(v.visivel).toBe(true);
    a.destruir();
  });

  it("primeira instalação (sem controlador) não mostra aviso", async () => {
    const { sw, reg } = fakeSW({ controller: null });
    const a = criarAtualizador({ sw, recarregar: vi.fn(), doc: null, intervaloMs: 1e9 });
    let v;
    a.subscribe((x) => (v = x));
    await a.registrar();
    const w1 = worker();
    reg.installing = w1;
    reg.emit("updatefound");
    w1.state = "installed";
    w1.emit("statechange");
    expect(v.visivel).toBe(false);
    a.destruir();
  });

  it("verifica atualizações a cada intervalo e ao voltar à aba", async () => {
    vi.useFakeTimers();
    try {
      const { sw, reg } = fakeSW();
      const doc = new FakeTarget();
      doc.visibilityState = "visible";
      const a = criarAtualizador({ sw, recarregar: vi.fn(), doc, intervaloMs: 1000 });
      await a.registrar();
      expect(reg.update).not.toHaveBeenCalled();
      vi.advanceTimersByTime(1000);
      expect(reg.update).toHaveBeenCalledTimes(1);
      doc.emit("visibilitychange");
      expect(reg.update).toHaveBeenCalledTimes(2);
      doc.visibilityState = "hidden";
      doc.emit("visibilitychange");
      expect(reg.update).toHaveBeenCalledTimes(2);
      a.destruir();
      vi.advanceTimersByTime(5000);
      expect(reg.update).toHaveBeenCalledTimes(2);
    } finally {
      vi.useRealTimers();
    }
  });

  it("sem suporte a service worker: registrar não faz nada", async () => {
    const a = criarAtualizador({ sw: undefined, doc: null });
    expect(await a.registrar()).toBeNull();
  });
});
