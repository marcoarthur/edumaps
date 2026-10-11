// src/features/inscricao/pages/InscricaoPublicaPage.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, cleanup } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import { resetCanaisMockState } from "@/features/gestor/mocks/canaisHandlers.js";
import {
  INSCRICAO_TOKEN_EXPIRADO,
  INSCRICAO_TOKEN_LIMITE,
  INSCRICAO_TOKEN_VALIDO,
  TELEFONE_DUPLICADO,
} from "@/features/gestor/mocks/canaisFixtures.js";
import InscricaoPublicaPage from "./InscricaoPublicaPage.svelte";

function renderPage(token = INSCRICAO_TOKEN_VALIDO) {
  return render(InscricaoPublicaPage, { props: { token } });
}

async function preencher({ nome = "Nova Pessoa", telefone = "+55 11 98888-0000" } = {}) {
  await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
    target: { value: nome },
  });
  await fireEvent.input(screen.getByPlaceholderText("(00) 00000-0000"), {
    target: { value: telefone },
  });
  await fireEvent.click(screen.getByRole("checkbox"));
}

describe("InscricaoPublicaPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    document.head.querySelectorAll('meta[name="robots"]').forEach((m) => m.remove());
  });
  afterEach(() => cleanup());

  it("carrega o formulário pelo token e marca noindex", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    expect(screen.getByText(/Escola Estadual Professora Maria/)).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Seu nome completo")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("(00) 00000-0000")).toHaveAttribute(
      "inputmode",
      "numeric",
    );
    const meta = document.querySelector('meta[name="robots"]');
    expect(meta).toHaveAttribute("content", "noindex, nofollow");
  });

  it("envia uma inscrição válida e confirma", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher();
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByTestId("inscricao-sucesso")).toBeInTheDocument();
  });

  it("mostra 'já cadastrado' quando o telefone já está na lista", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher({ telefone: TELEFONE_DUPLICADO });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByTestId("inscricao-ja-cadastrada")).toBeInTheDocument();
  });

  it("valida no cliente antes de enviar", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByText("Informe seu nome.")).toBeInTheDocument();
  });

  it("mostra link indisponível para token expirado (410)", async () => {
    renderPage(INSCRICAO_TOKEN_EXPIRADO);
    expect(await screen.findByTestId("inscricao-indisponivel")).toBeInTheDocument();
  });

  it("mostra erro de rede quando a API falha", async () => {
    server.use(http.get("/api/canais/inscricao/:token", () => HttpResponse.error()));
    renderPage();
    expect(await screen.findByTestId("inscricao-erro")).toBeInTheDocument();
  });

  it("trata o limite de usos (429) com mensagem amigável", async () => {
    const primeiro = renderPage(INSCRICAO_TOKEN_LIMITE);
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher({ telefone: "+55 11 96666-0000" });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    await screen.findByTestId("inscricao-sucesso");
    primeiro.unmount();

    renderPage(INSCRICAO_TOKEN_LIMITE);
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher({ nome: "Outra Pessoa", telefone: "+55 11 96666-0001" });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByText(/Muitas inscrições/i)).toBeInTheDocument();
  });
});
