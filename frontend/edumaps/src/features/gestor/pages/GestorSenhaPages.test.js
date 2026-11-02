// src/features/gestor/pages/GestorSenhaPages.test.js — esqueci minha senha (#336)
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import GestorEsqueciSenhaPage from "./GestorEsqueciSenhaPage.svelte";
import GestorRedefinirSenhaPage from "./GestorRedefinirSenhaPage.svelte";
import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const TOKEN = "t".repeat(43);

afterEach(() => window.history.replaceState({}, "", "/"));

describe("link 'Esqueci minha senha' no login", () => {
  it("aparece quando o e-mail da plataforma está configurado", async () => {
    render(GestorLoginCard, { props: { onLogin: () => {} } });
    const link = await screen.findByRole("link", { name: "Esqueci minha senha" });
    expect(link.getAttribute("href")).toBe("/gestor/esqueci-senha");
  });

  it("fica escondido quando não está", async () => {
    server.use(http.get("/api/gestor/senha/disponivel", () => HttpResponse.json({ disponivel: 0 })));
    render(GestorLoginCard, { props: { onLogin: () => {} } });
    await screen.findByRole("button", { name: "Entrar" });
    await new Promise((r) => setTimeout(r, 50));
    expect(screen.queryByRole("link", { name: "Esqueci minha senha" })).not.toBeInTheDocument();
  });
});

describe("GestorEsqueciSenhaPage", () => {
  it("pede o link e mostra a mensagem genérica do servidor", async () => {
    render(GestorEsqueciSenhaPage);
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Enviar link" }));

    await screen.findByText(/Se houver uma conta com esse e-mail/);
    expect(screen.getByText(/vale por 30 minutos/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Enviar link" })).not.toBeInTheDocument();
  });

  it("recusa e-mail inválido sem chamar o servidor", async () => {
    render(GestorEsqueciSenhaPage);
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), { target: { value: "x" } });
    await fireEvent.click(screen.getByRole("button", { name: "Enviar link" }));
    expect(screen.getByText("Informe um e-mail válido.")).toBeInTheDocument();
  });

  it("mostra a espera do 429", async () => {
    server.use(
      http.post("/api/gestor/senha/esqueci", () =>
        HttpResponse.json({ error: "Muitas tentativas. Tente de novo em 60 minutos." }, { status: 429 }),
      ),
    );
    render(GestorEsqueciSenhaPage);
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Enviar link" }));
    await screen.findByText("Muitas tentativas. Tente de novo em 60 minutos.");
  });
});

describe("GestorRedefinirSenhaPage", () => {
  beforeEach(() => window.history.replaceState({}, "", `/gestor/redefinir-senha#${TOKEN}`));

  it("tira o token da barra de endereço ao abrir", async () => {
    render(GestorRedefinirSenhaPage);
    await screen.findByRole("button", { name: "Salvar senha nova" });
    expect(window.location.hash).toBe("");
    expect(window.location.pathname).toBe("/gestor/redefinir-senha");
  });

  it("salva a senha nova e manda entrar de novo", async () => {
    render(GestorRedefinirSenhaPage);
    const [nova, repete] = await screen.findAllByDisplayValue("");
    await fireEvent.input(nova, { target: { value: "novinha456" } });
    await fireEvent.input(repete, { target: { value: "novinha456" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar senha nova" }));

    await screen.findByText("Senha alterada.");
    expect(screen.getByText(/saiu de todos os aparelhos/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Entrar" }).getAttribute("href")).toBe("/gestor");
  });

  it("senhas diferentes não vão ao servidor", async () => {
    render(GestorRedefinirSenhaPage);
    const [nova, repete] = await screen.findAllByDisplayValue("");
    await fireEvent.input(nova, { target: { value: "novinha456" } });
    await fireEvent.input(repete, { target: { value: "outra4567" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar senha nova" }));
    expect(screen.getByText("As duas senhas não são iguais.")).toBeInTheDocument();
  });

  it("link vencido: explica e oferece pedir outro", async () => {
    window.history.replaceState({}, "", `/gestor/redefinir-senha#${"v".repeat(43)}`);
    render(GestorRedefinirSenhaPage);
    const [nova, repete] = await screen.findAllByDisplayValue("");
    await fireEvent.input(nova, { target: { value: "novinha456" } });
    await fireEvent.input(repete, { target: { value: "novinha456" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar senha nova" }));

    await screen.findByText(/não vale mais/);
    expect(screen.getByRole("link", { name: "Pedir um link novo" })).toBeInTheDocument();
  });

  it("sem token: avisa que o link está incompleto", async () => {
    window.history.replaceState({}, "", "/gestor/redefinir-senha");
    render(GestorRedefinirSenhaPage);
    await screen.findByText(/Este link está incompleto/);
  });
});
