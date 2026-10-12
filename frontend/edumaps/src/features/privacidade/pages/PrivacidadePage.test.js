// src/features/privacidade/pages/PrivacidadePage.test.js
import { render, screen, within, waitFor } from "@testing-library/svelte";
import { describe, it, expect, beforeEach } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import {
  resetCanaisMockState,
  setRetencaoPublicaMock,
} from "@/features/gestor/mocks/canaisHandlers.js";
import PrivacidadePage from "./PrivacidadePage.svelte";

describe("PrivacidadePage", () => {
  beforeEach(() => resetCanaisMockState());

  it("renderiza o título principal", () => {
    render(PrivacidadePage);
    expect(
      screen.getByRole("heading", { level: 1, name: /política de privacidade/i }),
    ).toBeInTheDocument();
  });

  it("explica o uso de nome e contatos na autoinscrição", () => {
    render(PrivacidadePage);
    expect(screen.getByRole("heading", { name: "Autoinscrição em listas" })).toBeInTheDocument();
    expect(screen.getByText(/Nome e contatos são usados apenas/)).toBeInTheDocument();
  });

  it("mostra o texto de consentimento vigente com versão e data, sem HTML cru", async () => {
    server.use(
      http.get("/api/canais/consentimento", () =>
        HttpResponse.json({
          versao: "1.1",
          texto: "Você autoriza a **escola**.\n\n- avisos;\n- reuniões.\n\n<script>alert(1)</script>",
          publicada_em: "2026-10-13T12:00:00Z",
          retencao: { enabled: true, metadados_dias: 90, pendentes_dias: 180, listas_inativas_meses: 12 },
        }),
      ),
    );
    render(PrivacidadePage);

    const secao = await screen.findByTestId("privacidade-consentimento");
    expect(screen.getByTestId("privacidade-versao")).toHaveTextContent("Versão 1.1");
    expect(screen.getByTestId("privacidade-versao")).toHaveTextContent(
      new Date("2026-10-13T12:00:00Z").toLocaleDateString("pt-BR"),
    );
    expect(within(secao).getByText("escola").tagName).toBe("STRONG");
    expect(within(secao).getAllByRole("listitem")).toHaveLength(2);
    // HTML vira texto puro
    expect(secao.querySelector("script")).toBeNull();
    expect(secao).toHaveTextContent("<script>alert(1)</script>");
  });

  it("mostra os prazos de retenção em linguagem simples", async () => {
    render(PrivacidadePage);
    const ret = await screen.findByTestId("privacidade-retencao");
    expect(ret).toHaveTextContent(/apagados após 90 dias/);
    expect(ret).toHaveTextContent(/removidas após 180 dias/);
    expect(ret).toHaveTextContent(/removidos após 12 meses/);
  });

  it("singular: 1 dia / 1 mês", async () => {
    setRetencaoPublicaMock({ metadados_dias: 1, listas_inativas_meses: 1 });
    render(PrivacidadePage);
    const ret = await screen.findByTestId("privacidade-retencao");
    expect(ret).toHaveTextContent(/após 1 dia\./);
    expect(ret).toHaveTextContent(/após 1 mês/);
  });

  it("não mostra prazos quando a retenção está desligada", async () => {
    setRetencaoPublicaMock({ enabled: false });
    render(PrivacidadePage);
    await screen.findByTestId("privacidade-consentimento");
    expect(screen.queryByTestId("privacidade-retencao")).not.toBeInTheDocument();
  });

  it("explica como excluir os dados (link pessoal ou pedido à escola)", () => {
    render(PrivacidadePage);
    const secao = screen.getByTestId("privacidade-como-excluir");
    expect(within(secao).getByRole("heading", { name: "Como excluir seus dados" })).toBeInTheDocument();
    expect(secao).toHaveTextContent(/Remover meus dados/);
    expect(secao).toHaveTextContent(/peça a remoção à escola/);
  });

  it("fallback estático quando a API falha", async () => {
    server.use(
      http.get("/api/canais/consentimento", () =>
        HttpResponse.json({ error: "boom" }, { status: 500 }),
      ),
    );
    render(PrivacidadePage);
    await screen.findByRole("heading", { name: "Como excluir seus dados" });
    await waitFor(() => expect(screen.queryByText(/Carregando o termo/)).not.toBeInTheDocument());
    expect(screen.queryByTestId("privacidade-consentimento")).not.toBeInTheDocument();
    expect(screen.queryByTestId("privacidade-retencao")).not.toBeInTheDocument();
    expect(screen.queryByText(/Carregando o termo/)).not.toBeInTheDocument();
    expect(screen.getByText(/Nome e contatos são usados apenas/)).toBeInTheDocument();
  });
});
