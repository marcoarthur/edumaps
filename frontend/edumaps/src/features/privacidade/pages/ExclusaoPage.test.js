// src/features/privacidade/pages/ExclusaoPage.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, cleanup, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import {
  resetCanaisMockState,
  getExclusoesMock,
} from "@/features/gestor/mocks/canaisHandlers.js";
import {
  CANAIS_ESCOLA_NOME,
  EXCLUSAO_TOKEN_VALIDO,
  EXCLUSAO_TOKEN_JA_EXCLUIDO,
  EXCLUSAO_TOKEN_LIMITE,
} from "@/features/gestor/mocks/canaisFixtures.js";
import ExclusaoPage from "./ExclusaoPage.svelte";

const renderPage = (token = EXCLUSAO_TOKEN_VALIDO) => render(ExclusaoPage, { props: { token } });

describe("ExclusaoPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    document.head.querySelectorAll('meta[name="robots"]').forEach((m) => m.remove());
  });
  afterEach(() => cleanup());

  it("mostra carregando e depois escola, lista e o que será removido; marca noindex", async () => {
    renderPage();
    expect(screen.getByText("Carregando…")).toBeInTheDocument();

    const pronto = await screen.findByTestId("exclusao-pronto");
    expect(screen.getByTestId("exclusao-origem")).toHaveTextContent(CANAIS_ESCOLA_NOME);
    expect(screen.getByTestId("exclusao-origem")).toHaveTextContent("Lista: Responsáveis 6ºA");
    expect(pronto).toHaveTextContent(/todas as listas desta escola/);
    expect(pronto).toHaveTextContent(/sem dados pessoais/);
    expect(document.querySelector('meta[name="robots"]')?.getAttribute("content")).toBe(
      "noindex, nofollow",
    );
  });

  it("confirma a exclusão (POST {confirmar:true}) e mostra o estado concluído", async () => {
    let corpo = null;
    server.events.on("request:start", async ({ request }) => {
      if (request.method === "POST" && request.url.includes("/api/canais/exclusao/")) {
        corpo = await request.clone().json();
      }
    });
    renderPage();
    await screen.findByTestId("exclusao-pronto");

    await fireEvent.click(screen.getByRole("button", { name: /Confirmar e remover/ }));

    expect(await screen.findByTestId("exclusao-concluida")).toHaveTextContent(
      "Seus dados foram removidos",
    );
    expect(corpo).toEqual({ confirmar: true });
    expect(getExclusoesMock()[0]).toMatchObject({ origem: "titular", contatos: 1 });
    server.events.removeAllListeners();
  });

  it("reabrir o link depois da exclusão mostra 'já excluído'", async () => {
    renderPage();
    await screen.findByTestId("exclusao-pronto");
    await fireEvent.click(screen.getByRole("button", { name: /Confirmar e remover/ }));
    await screen.findByTestId("exclusao-concluida");
    cleanup();

    renderPage();
    expect(await screen.findByTestId("exclusao-ja-excluida")).toHaveTextContent(
      "Seus dados já foram removidos",
    );
    expect(screen.queryByRole("button", { name: /Confirmar e remover/ })).not.toBeInTheDocument();
  });

  it("token já anonimizado abre direto em 'já excluído'", async () => {
    renderPage(EXCLUSAO_TOKEN_JA_EXCLUIDO);
    expect(await screen.findByTestId("exclusao-ja-excluida")).toBeInTheDocument();
  });

  it("POST idempotente (ja_excluido) também termina em 'já excluído'", async () => {
    server.use(
      http.post("/api/canais/exclusao/:token", () => HttpResponse.json({ ok: 1, ja_excluido: true })),
    );
    renderPage();
    await screen.findByTestId("exclusao-pronto");
    await fireEvent.click(screen.getByRole("button", { name: /Confirmar e remover/ }));
    expect(await screen.findByTestId("exclusao-ja-excluida")).toBeInTheDocument();
  });

  it("token desconhecido (404) mostra link inválido", async () => {
    renderPage("ffffffffffffffffffffffffffffffff");
    expect(await screen.findByTestId("exclusao-invalido")).toHaveTextContent("Link inválido");
  });

  it("429 no POST avisa para aguardar e mantém o botão", async () => {
    renderPage(EXCLUSAO_TOKEN_LIMITE);
    await screen.findByTestId("exclusao-pronto");
    await fireEvent.click(screen.getByRole("button", { name: /Confirmar e remover/ }));

    expect(await screen.findByRole("alert")).toHaveTextContent(/Muitas tentativas/);
    expect(screen.getByRole("button", { name: /Confirmar e remover/ })).toBeEnabled();
  });

  it("falha do servidor no GET mostra erro com 'Tentar de novo'", async () => {
    let falhar = true;
    server.use(
      http.get("/api/canais/exclusao/:token", () =>
        falhar
          ? HttpResponse.json({ error: "boom" }, { status: 500 })
          : HttpResponse.json({ escola_nome: "Escola X", lista_nome: "Lista Y", ja_excluido: false }),
      ),
    );
    renderPage();
    expect(await screen.findByTestId("exclusao-erro")).toBeInTheDocument();

    falhar = false;
    await fireEvent.click(screen.getByRole("button", { name: "Tentar de novo" }));
    await waitFor(() => expect(screen.getByTestId("exclusao-origem")).toHaveTextContent("Escola X"));
  });

  it("falha do servidor no POST mostra erro sem sair da tela", async () => {
    server.use(
      http.post("/api/canais/exclusao/:token", () =>
        HttpResponse.json({ error: "boom" }, { status: 500 }),
      ),
    );
    renderPage();
    await screen.findByTestId("exclusao-pronto");
    await fireEvent.click(screen.getByRole("button", { name: /Confirmar e remover/ }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/Não foi possível concluir/);
    expect(screen.getByTestId("exclusao-pronto")).toBeInTheDocument();
  });
});
