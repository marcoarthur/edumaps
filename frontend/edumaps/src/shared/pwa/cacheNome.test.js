import { describe, it, expect } from "vitest";
import {
  nomeDoCache,
  hashDoManifesto,
  cachesObsoletos,
  ehAssetComHash,
  PREFIXO_CACHE,
} from "./cacheNome.js";

const build1 = [
  { url: "index.html", revision: "aaa" },
  { url: "assets/index-Ab12Cd34.js", revision: null },
];

describe("nomeDoCache", () => {
  it("tem o prefixo edumaps- e é estável para o mesmo manifesto", () => {
    const n = nomeDoCache(build1);
    expect(n).toMatch(/^edumaps-[0-9a-f]{8}$/);
    expect(nomeDoCache([...build1])).toBe(n);
  });

  it("independe da ordem das entradas", () => {
    expect(nomeDoCache([...build1].reverse())).toBe(nomeDoCache(build1));
  });

  it("muda quando muda a revisão (index.html novo)", () => {
    const build2 = [{ ...build1[0], revision: "bbb" }, build1[1]];
    expect(nomeDoCache(build2)).not.toBe(nomeDoCache(build1));
  });

  it("muda quando muda a URL com hash", () => {
    const build2 = [build1[0], { url: "assets/index-Zz99Yy88.js", revision: null }];
    expect(nomeDoCache(build2)).not.toBe(nomeDoCache(build1));
  });

  it("aceita manifesto vazio/ausente e entradas string", () => {
    expect(hashDoManifesto(undefined)).toBe(hashDoManifesto([]));
    expect(nomeDoCache(["a.js"])).not.toBe(nomeDoCache(["b.js"]));
  });
});

describe("cachesObsoletos", () => {
  it("apaga só os edumaps-* de outros builds", () => {
    const atual = nomeDoCache(build1);
    const chaves = ["edumaps-v2", atual, "edumaps-deadbeef", "outro-cache"];
    expect(cachesObsoletos(chaves, atual)).toEqual(["edumaps-v2", "edumaps-deadbeef"]);
    expect(PREFIXO_CACHE).toBe("edumaps-");
  });
});

describe("ehAssetComHash", () => {
  it("reconhece assets do Vite com hash", () => {
    expect(ehAssetComHash("/assets/index-Ab12Cd34.js")).toBe(true);
    expect(ehAssetComHash("/assets/vendor-leaflet-B_x9-kQz.css")).toBe(true);
  });
  it("rejeita arquivos sem hash", () => {
    expect(ehAssetComHash("/favicon.svg")).toBe(false);
    expect(ehAssetComHash("/index.html")).toBe(false);
    expect(ehAssetComHash("/icons/icon-192.png")).toBe(false);
  });
});
