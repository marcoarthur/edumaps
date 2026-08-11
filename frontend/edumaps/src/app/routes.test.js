// src/app/routes.test.js
import { describe, it, expect } from "vitest";
import { matchRoute } from "./routes.js";

describe("matchRoute", () => {
  it("encontra a rota /about", () => {
    const match = matchRoute("/about");
    expect(match?.path).toBe("/about");
  });

  it("encontra a rota /busca", () => {
    const match = matchRoute("/escola/search");
    expect(match?.path).toBe("/escola/search");
  });

  it("encontra a rota /escola/ranking?inep=codigo", () => {
    const match = matchRoute("/escola/ranking");
    expect(match?.path).toBe("/escola/ranking");
  });

  it("retorna null para rota inexistente", () => {
    expect(matchRoute("/nao-existe")).toBeNull();
  });
});
