// src/features/config/pages/ConsentimentoVersoesPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import ConsentimentoVersoesPage from "./ConsentimentoVersoesPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN, SESSION_GESTOR } from "@/features/gestor/mocks/fixtures.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { resetConfigMockState, getConsentimentoVersoesMock } from "../mocks/configHandlers.js";
import { resetCanaisMockState } from "@/features/gestor/mocks/canaisHandlers.js";
import { consentimentoVigente } from "@/features/inscricao/api/canaisPublicApi.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const linhas = () => screen.getAllByTestId("versao-row");
const linhaDa = (versao) =>
  linhas().find((tr) => within(tr).queryByText(versao, { selector: "td" }));

describe("ConsentimentoVersoesPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
    resetCanaisMockState();
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("lista as versões com status e data de publicação", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    expect(linhas()).toHaveLength(2);
    expect(within(linhaDa("1.0")).getByTestId("versao-status")).toHaveTextContent("Vigente");
    expect(within(linhaDa("1.1")).getByTestId("versao-status")).toHaveTextContent("Rascunho");
    expect(screen.getByRole("link", { name: "← Configurações" })).toHaveAttribute("href", "/config");
    // publicada não tem editar/publicar
    expect(screen.queryByRole("button", { name: "Editar versão 1.0" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Ver versão 1.0" })).toBeInTheDocument();
  });

  it("versão publicada abre só leitura", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "Ver versão 1.0" }));
    const editor = screen.getByTestId("versao-editor");
    expect(editor).toHaveTextContent("não podem ser editadas");
    expect(within(editor).queryByRole("textbox")).not.toBeInTheDocument();
  });

  it("cria um rascunho com pré-visualização segura", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "+ Nova versão" }));

    await fireEvent.input(screen.getByRole("textbox", { name: "Versão" }), { target: { value: "1.2" } });
    await fireEvent.input(screen.getByRole("textbox", { name: /Texto/ }), {
      target: { value: "Texto **novo**.\n\n- item um\n- item dois\n\n<b>cru</b>" },
    });
    const preview = screen.getByTestId("versao-preview");
    expect(within(preview).getByText("novo").tagName).toBe("STRONG");
    expect(within(preview).getAllByRole("listitem")).toHaveLength(2);
    expect(preview.querySelector("b")).toBeNull();
    expect(preview).toHaveTextContent("<b>cru</b>");

    await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Rascunho 1.2 criado.", "success"));
    await screen.findByText("Versões (3)");
    expect(within(linhaDa("1.2")).getByTestId("versao-status")).toHaveTextContent("Rascunho");
    expect(screen.queryByTestId("versao-editor")).not.toBeInTheDocument();
  });

  it("valida campos vazios sem chamar a API", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "+ Nova versão" }));
    await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
    expect(screen.getByRole("alert")).toHaveTextContent("Informe a versão e o texto.");
    expect(getConsentimentoVersoesMock()).toHaveLength(2);
  });

  it("409 (versão repetida) mostra a mensagem do backend", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "+ Nova versão" }));
    await fireEvent.input(screen.getByRole("textbox", { name: "Versão" }), { target: { value: "1.0" } });
    await fireEvent.input(screen.getByRole("textbox", { name: /Texto/ }), { target: { value: "Outro texto." } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("A versão 1.0 já existe.");
    expect(screen.getByTestId("versao-editor")).toBeInTheDocument();
  });

  it("400 do backend aparece no editor", async () => {
    server.use(
      http.post("/api/admin/consentimento/versoes", () =>
        HttpResponse.json({ error: "Versão em formato inválido." }, { status: 400 }),
      ),
    );
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "+ Nova versão" }));
    await fireEvent.input(screen.getByRole("textbox", { name: "Versão" }), { target: { value: "x" } });
    await fireEvent.input(screen.getByRole("textbox", { name: /Texto/ }), { target: { value: "Texto." } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Versão em formato inválido.");
  });

  it("edita um rascunho (PUT)", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "Editar versão 1.1" }));
    const texto = screen.getByRole("textbox", { name: /Texto/ });
    expect(texto.value).toMatch(/telefone e e-mail/);
    await fireEvent.input(texto, { target: { value: "Texto revisado." } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar alterações" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Rascunho 1.1 salvo.", "success"));
    expect(getConsentimentoVersoesMock().find((v) => v.versao === "1.1").texto).toBe("Texto revisado.");
  });

  it("409 ao editar (já publicado em outra aba) mostra a mensagem", async () => {
    server.use(
      http.put("/api/admin/consentimento/versoes/:id", () =>
        HttpResponse.json({ error: "Só rascunhos podem ser editados; versões publicadas são imutáveis." }, { status: 409 }),
      ),
    );
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "Editar versão 1.1" }));
    await fireEvent.click(screen.getByRole("button", { name: "Salvar alterações" }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/versões publicadas são imutáveis/);
  });

  it("publica com confirmação: a vigente vira arquivada e o texto público muda", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "Publicar versão 1.1" }));

    const dlg = screen.getByRole("alertdialog", { name: "Publicar a versão 1.1?" });
    expect(dlg).toHaveAccessibleDescription(/versão vigente \(1\.0\) será arquivada/);
    expect(dlg).toHaveAccessibleDescription(/não podem ser editadas/);
    await fireEvent.click(within(dlg).getByRole("button", { name: "Publicar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Versão 1.1 publicada.", "success"));
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    await waitFor(() =>
      expect(within(linhaDa("1.1")).getByTestId("versao-status")).toHaveTextContent("Vigente"),
    );
    expect(within(linhaDa("1.0")).getByTestId("versao-status")).toHaveTextContent("Arquivada");
    expect((await consentimentoVigente()).versao).toBe("1.1");
  });

  it("cancelar a publicação não muda nada", async () => {
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "Publicar versão 1.1" }));
    await fireEvent.click(screen.getByRole("button", { name: "Cancelar" }));
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(getConsentimentoVersoesMock().find((v) => v.versao === "1.1").status).toBe("rascunho");
  });

  it("409 ao publicar fica no diálogo com a mensagem do backend", async () => {
    server.use(
      http.post("/api/admin/consentimento/versoes/:id/publicar", () =>
        HttpResponse.json({ error: "Só rascunhos podem ser publicados." }, { status: 409 }),
      ),
    );
    render(ConsentimentoVersoesPage);
    await screen.findByText("Versões (2)");
    await fireEvent.click(screen.getByRole("button", { name: "Publicar versão 1.1" }));
    await fireEvent.click(within(screen.getByRole("alertdialog")).getByRole("button", { name: "Publicar" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Só rascunhos podem ser publicados.");
    expect(screen.getByRole("alertdialog")).toBeInTheDocument();
  });

  it("sem sessão mostra o login", async () => {
    clearSessaoToken();
    setApiToken(null);
    render(ConsentimentoVersoesPage);
    expect(await screen.findByText("Entrar como administrador")).toBeInTheDocument();
  });

  it("gestor sem perfil admin não acessa", async () => {
    server.use(
      http.get("/api/gestor/me", () => HttpResponse.json({ ...SESSION_GESTOR, access_role: "gestor" })),
    );
    render(ConsentimentoVersoesPage);
    expect(await screen.findByText(/restrita a administradores/)).toBeInTheDocument();
  });
});
