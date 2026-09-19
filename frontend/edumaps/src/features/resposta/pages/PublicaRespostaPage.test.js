// src/features/resposta/pages/PublicaRespostaPage.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, cleanup } from "@testing-library/svelte";
import { PUBLIC_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import PublicaRespostaPage from "./PublicaRespostaPage.svelte";

function renderPage(token = PUBLIC_TOKEN) {
  return render(PublicaRespostaPage, { props: { token } });
}

async function responderTema(selectText) {
  // pergunta 1 (obrigatória, unica) e pergunta 2 (texto livre)
  await fireEvent.click(screen.getAllByRole("radio")[selectText]);
  await fireEvent.input(screen.getByPlaceholderText("Escreva aqui…"), {
    target: { value: "Feira de foguetes!" },
  });
  await fireEvent.click(screen.getByRole("button", { name: "Enviar resposta" }));
}

describe("PublicaRespostaPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });
  afterEach(() => cleanup());

  it("carrega o formulário público pelo token", async () => {
    renderPage();
    await screen.findByRole("heading", { name: /Semana de ciências/ });
    expect(screen.getByText(/Qual tema você mais quer/)).toBeInTheDocument();
    expect(screen.getAllByRole("radio")).toHaveLength(3);
    expect(screen.getByPlaceholderText("Escreva aqui…")).toBeInTheDocument();
  });

  it("envia a resposta válida e mostra o agradecimento", async () => {
    renderPage();
    await screen.findByRole("heading", { name: /Semana de ciências/ });
    await responderTema(0);
    await waitFor(() =>
      expect(screen.getByTestId("resposta-enviada")).toBeInTheDocument(),
    );
    expect(screen.getByText(/Obrigado por responder!/)).toBeInTheDocument();
  });

  it("exige as perguntas obrigatórias antes de enviar", async () => {
    renderPage();
    await screen.findByRole("heading", { name: /Semana de ciências/ });
    await fireEvent.click(screen.getByRole("button", { name: "Enviar resposta" }));

    expect(screen.getByText(/Responda a pergunta obrigatória 1/)).toBeInTheDocument();
    expect(
      screen.queryByTestId("resposta-enviada"),
    ).not.toBeInTheDocument();
  });

  it("bloqueia a segunda resposta do mesmo dispositivo (409)", async () => {
    const first = renderPage();
    await screen.findByRole("heading", { name: /Semana de ciências/ });
    await responderTema(1);
    await waitFor(() =>
      expect(screen.getByTestId("resposta-enviada")).toBeInTheDocument(),
    );
    first.unmount();

    renderPage();
    await screen.findByRole("heading", { name: /Semana de ciências/ });
    await responderTema(2);

    await waitFor(() =>
      expect(
        screen.getByText(/Você já respondeu esta pesquisa neste dispositivo/),
      ).toBeInTheDocument(),
    );
  });

  it("mostra erro amigável para link que não abre pesquisa", async () => {
    renderPage("token-inexistente");
    await screen.findByText(/não encontrada ou não publicada/);
    expect(screen.getByText(/Verifique se o link/)).toBeInTheDocument();
  });
});