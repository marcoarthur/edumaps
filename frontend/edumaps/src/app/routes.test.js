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

  it("encontra a rota de política de privacidade /privacidade", () => {
    const match = matchRoute("/privacidade");
    expect(match?.path).toBe("/privacidade");
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

  it("encontra a rota do painel de configuração /config", () => {
    const match = matchRoute("/config");
    expect(match?.path).toBe("/config");
  });

  it("encontra a rota do histórico de chat /chat/historico", () => {
    const match = matchRoute("/chat/historico");
    expect(match?.path).toBe("/chat/historico");
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

  it("encontra a lista de gestão /gestor/listas", () => {
    expect(matchRoute("/gestor/listas")?.path).toBe("/gestor/listas");
  });

  it("encontra os envios por e-mail /gestor/envios (com query do alvo)", () => {
    expect(matchRoute("/gestor/envios")?.path).toBe("/gestor/envios");
    expect(matchRoute("/gestor/envios?novo=1&alvo_tipo=lista&alvo_id=4")?.path).toBe(
      "/gestor/envios",
    );
  });

  it("encontra as listas dinâmicas /gestor/segmentos", () => {
    expect(matchRoute("/gestor/segmentos")?.path).toBe("/gestor/segmentos");
  });

  it("captura o token na rota pública de inscrição /inscricao/:token", () => {
    const match = matchRoute("/inscricao/9f8f36e2-1234-4abc-8def-000000000000");
    expect(match?.path).toBe("/inscricao/:token");
    expect(match?.params.token).toBe("9f8f36e2-1234-4abc-8def-000000000000");
  });

  it("captura o token na rota pública de exclusão /privacidade/exclusao/:token", () => {
    const match = matchRoute("/privacidade/exclusao/a1b2c3d4e5f60718293a4b5c6d7e8f90");
    expect(match?.path).toBe("/privacidade/exclusao/:token");
    expect(match?.params.token).toBe("a1b2c3d4e5f60718293a4b5c6d7e8f90");
    expect(matchRoute("/privacidade")?.path).toBe("/privacidade");
  });

  it("encontra a rota admin de versões do consentimento /config/consentimento", () => {
    expect(matchRoute("/config/consentimento")?.path).toBe("/config/consentimento");
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
