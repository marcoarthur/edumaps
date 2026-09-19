// src/app/routes.test.js
import { describe, it, expect } from "vitest";
import { matchRoute } from "./routes.js";

describe("matchRoute", () => {
  it("encontra a rota da landpage /", () => {
    const match = matchRoute("/");
    expect(match?.path).toBe("/");
  });

  it("encontra a rota /about", () => {
    const match = matchRoute("/about");
    expect(match?.path).toBe("/about");
  });

  it("encontra a rota de análise de clusters /cluster/geotag", () => {
    const match = matchRoute("/cluster/geotag");
    expect(match?.path).toBe("/cluster/geotag");
  });

  it("encontra a rota /busca", () => {
    const match = matchRoute("/escola/search");
    expect(match?.path).toBe("/escola/search");
  });

  it("encontra a rota /escola/ranking?inep=codigo", () => {
    const match = matchRoute("/escola/ranking");
    expect(match?.path).toBe("/escola/ranking");
  });

  it("encontra a rota do painel financeiro /escola/financeiro", () => {
    const match = matchRoute("/escola/financeiro");
    expect(match?.path).toBe("/escola/financeiro");
  });

  it("encontra a rota do painel do gestor /gestor/painel", () => {
    const match = matchRoute("/gestor/painel");
    expect(match?.path).toBe("/gestor/painel");
  });

  it("encontra a rota de pesquisas do gestor /gestor/pesquisas", () => {
    const match = matchRoute("/gestor/pesquisas");
    expect(match?.path).toBe("/gestor/pesquisas");
  });

  it("encontra a rota de nova pesquisa /gestor/pesquisas/nova", () => {
    const match = matchRoute("/gestor/pesquisas/nova");
    expect(match?.path).toBe("/gestor/pesquisas/nova");
  });

  it("encontra a rota de edição /gestor/pesquisas/editar", () => {
    const match = matchRoute("/gestor/pesquisas/editar");
    expect(match?.path).toBe("/gestor/pesquisas/editar");
  });

  it("retorna null para rota inexistente", () => {
    expect(matchRoute("/nao-existe")).toBeNull();
  });
});
