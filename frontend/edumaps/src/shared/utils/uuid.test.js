// src/shared/utils/uuid.test.js
import { describe, it, expect, vi, afterEach } from "vitest";
import { uuid } from "./uuid.js";

// UUID v4 canônico (dígito de versão = 4, variante em [89ab]).
const UUID_V4 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

describe("uuid", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("gera um UUID v4 valido (caminho crypto.randomUUID)", () => {
    expect(uuid()).toMatch(UUID_V4);
  });

  it("gera ids unicos", () => {
    const ids = new Set(Array.from({ length: 100 }, () => uuid()));
    expect(ids.size).toBe(100);
  });

  it("funciona sem crypto.randomUUID (fallback getRandomValues)", () => {
    let n = 0;
    vi.stubGlobal("crypto", {
      getRandomValues: (arr) => {
        for (let i = 0; i < arr.length; i++) arr[i] = n++ & 0xff;
        return arr;
      },
    });

    expect(uuid()).toMatch(UUID_V4);
  });

  it("funciona sem Web Crypto (fallback final)", () => {
    vi.stubGlobal("crypto", undefined);
    expect(uuid()).toMatch(UUID_V4);
  });
});
