// src/features/privacidade/pages/SairPage.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, cleanup, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import { resetCanaisMockState, getOptoutsMock } from "@/features/gestor/mocks/canaisHandlers.js";
import {
  CANAIS_ESCOLA_NOME,
  SAIDA_TOKEN_VALIDO,
  SAIDA_TOKEN_JA_SAIU,
  SAIDA_TOKEN_LIMITE,
} from "@/features/gestor/mocks/canaisFixtures.js";
import SairPage from "./SairPage.svelte";

const renderPage = (token = SAIDA_TOKEN_VALIDO) => render(SairPage, { props: { token } });
const BOTAO = { name: "Não quero mais receber" };

describe("SairPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    document.head.querySelectorAll('meta[name="robots"]').forEach((m) => m.remove());
  });
  afterEach(() => {
    server.events.removeAllListeners();
    cleanup();
  });

  it("mostra carregando, depois escola, lista, o que acontece e a orientação de remoção; noindex", async () => {
    renderPage();
    expect(screen.getByText("Carregando…")).toBeInTheDocument();

    const pronto = await screen.findByTestId("sair-pronto");
    expect(screen.getByTestId("sair-origem")).toHaveTextContent(CANAIS_ESCOLA_NOME);
    expect(screen.getByTestId("sair-origem")).toHaveTextContent("Lista: Família 8ºC");
    expect(pronto).toHaveTextContent(/deixa de receber e-mails desta lista/);
    expect(pronto).toHaveTextContent(/Seus dados continuam com a escola/);
    const remocao = screen.getByTestId("sair-remocao");
    expect(remocao).toHaveTextContent(/link pessoal/);
    expect(remocao).toHaveTextContent(/peça diretamente à escola/);
    expect(screen.getByRole("link", { name: "Política de privacidade" })).toHaveAttribute(
      "href",
      "/privacidade",
    );
    expect(document.querySelector('meta[name="robots"]')?.getAttribute("content")).toBe(
      "noindex, nofollow",
    );
  });

  it("confirma a saída (POST {confirmar:true}) e mostra o estado concluído", async () => {
    let corpo = null;
    server.events.on("request:start", async ({ request }) => {
      if (request.method === "POST" && request.url.includes("/api/canais/sair/")) {
        corpo = await request.clone().json();
      }
    });
    renderPage();
    await screen.findByTestId("sair-pronto");
    await fireEvent.click(screen.getByRole("button", BOTAO));

    const ok = await screen.findByTestId("sair-concluido");
    expect(ok).toHaveTextContent("Pronto, você saiu dos envios");
    expect(ok).toHaveTextContent("Família 8ºC");
    // espaço entre o nome da lista e "da escola" (bug visto no e2e)
    expect(ok.textContent).toMatch(/Família 8ºC\s+da\s+escola/);
    expect(screen.getByTestId("sair-remocao")).toBeInTheDocument();
    expect(corpo).toEqual({ confirmar: true });
    expect(getOptoutsMock().some((o) => o.email === "ana@example.org" && o.lista_id === 4)).toBe(true);
  });

  it("reabrir o link depois da saída mostra 'já tinha saído'", async () => {
    renderPage();
    await screen.findByTestId("sair-pronto");
    await fireEvent.click(screen.getByRole("button", BOTAO));
    await screen.findByTestId("sair-concluido");
    cleanup();

    renderPage();
    expect(await screen.findByTestId("sair-ja-saiu")).toHaveTextContent("Você já tinha saído dos envios");
    expect(screen.queryByRole("button", BOTAO)).not.toBeInTheDocument();
  });

  it("token de quem já saiu abre direto em 'já tinha saído'", async () => {
    renderPage(SAIDA_TOKEN_JA_SAIU);
    expect(await screen.findByTestId("sair-ja-saiu")).toBeInTheDocument();
  });

  it("POST idempotente (ja_saiu) também termina em 'já tinha saído'", async () => {
    server.use(http.post("/api/canais/sair/:token", () => HttpResponse.json({ ok: 1, ja_saiu: true })));
    renderPage();
    await screen.findByTestId("sair-pronto");
    await fireEvent.click(screen.getByRole("button", BOTAO));
    expect(await screen.findByTestId("sair-ja-saiu")).toBeInTheDocument();
  });

  it("token desconhecido (404) mostra link inválido", async () => {
    renderPage("ffffffffffffffffffffffffffffffff");
    expect(await screen.findByTestId("sair-invalido")).toHaveTextContent("Link inválido");
  });

  it("404 no POST (lista apagada) mostra link inválido", async () => {
    server.use(
      http.post("/api/canais/sair/:token", () => HttpResponse.json({ error: "x" }, { status: 404 })),
    );
    renderPage();
    await screen.findByTestId("sair-pronto");
    await fireEvent.click(screen.getByRole("button", BOTAO));
    expect(await screen.findByTestId("sair-invalido")).toBeInTheDocument();
  });

  it("429 no POST avisa para aguardar e mantém o botão", async () => {
    renderPage(SAIDA_TOKEN_LIMITE);
    await screen.findByTestId("sair-pronto");
    await fireEvent.click(screen.getByRole("button", BOTAO));
    expect(await screen.findByRole("alert")).toHaveTextContent(/Muitas tentativas/);
    expect(screen.getByRole("button", BOTAO)).toBeEnabled();
  });

  it("falha do servidor no GET mostra erro com 'Tentar de novo'", async () => {
    let falhar = true;
    server.use(
      http.get("/api/canais/sair/:token", () =>
        falhar
          ? HttpResponse.json({ error: "boom" }, { status: 500 })
          : HttpResponse.json({ escola_nome: "Escola X", lista_nome: "Lista Y", ja_saiu: false }),
      ),
    );
    renderPage();
    expect(await screen.findByTestId("sair-erro")).toBeInTheDocument();
    falhar = false;
    await fireEvent.click(screen.getByRole("button", { name: "Tentar de novo" }));
    await waitFor(() => expect(screen.getByTestId("sair-origem")).toHaveTextContent("Escola X"));
  });

  it("falha do servidor no POST mostra erro sem sair da tela", async () => {
    server.use(
      http.post("/api/canais/sair/:token", () => HttpResponse.json({ error: "boom" }, { status: 500 })),
    );
    renderPage();
    await screen.findByTestId("sair-pronto");
    await fireEvent.click(screen.getByRole("button", BOTAO));
    expect(await screen.findByRole("alert")).toHaveTextContent(/Não foi possível concluir/);
    expect(screen.getByTestId("sair-pronto")).toBeInTheDocument();
  });
});
