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

  it("encontra a rota de acesso do gestor /gestor", () => {
    const match = matchRoute("/gestor");
    expect(match?.path).toBe("/gestor");
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

  it("captura o token na rota dinâmica /p/:token", () => {
    const match = matchRoute("/p/9f8f36e2-1234-4abc-8def-000000000000");
    expect(match?.path).toBe("/p/:token");
    expect(match?.params.token).toBe("9f8f36e2-1234-4abc-8def-000000000000");
  });

  it("não casa /p sem token nem token extra em outra rota", () => {
    expect(matchRoute("/p")).toBeNull();
    expect(matchRoute("/p/a/b")).toBeNull();
    expect(matchRoute("/escola/search/1")).toBeNull();
  });

  it("retorna null para rota inexistente", () => {
    expect(matchRoute("/nao-existe")).toBeNull();
  });
});
