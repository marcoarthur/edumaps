// src/features/gestor/pages/DocumentosPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import DocumentosPage from "./DocumentosPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("DocumentosPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("lista pastas, subpastas e documentos", async () => {
    render(DocumentosPage);

    expect(await screen.findByText("Documentos e planos escolares")).toBeInTheDocument();
    expect(await screen.findByText(/Planejamento/)).toBeInTheDocument();
    expect(await screen.findByText(/2026/)).toBeInTheDocument();
    expect(screen.getByText(/PPP da escola\.pdf/)).toBeInTheDocument();
    expect(screen.getByText(/Ata do conselho\.txt/)).toBeInTheDocument();
  });

  it("cria uma pasta na raiz", async () => {
    render(DocumentosPage);
    await screen.findByText(/Planejamento/);

    await fireEvent.click(screen.getByRole("button", { name: /Nova pasta na raiz/ }));
    await fireEvent.input(screen.getByPlaceholderText("Nome da pasta"), {
      target: { value: "Projetos 2027" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Criar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Pasta criada.", "success"));
    expect(await screen.findByText(/Projetos 2027/)).toBeInTheDocument();
  });

  it("cria uma subpasta dentro de uma pasta", async () => {
    render(DocumentosPage);
    await screen.findByText(/Planejamento/);

    await fireEvent.click(screen.getByRole("button", { name: "Nova pasta em Planejamento" }));
    await fireEvent.input(screen.getByPlaceholderText("Nome da subpasta"), {
      target: { value: "Replanejamento" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Criar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Pasta criada.", "success"));
    expect(await screen.findByText(/Replanejamento/)).toBeInTheDocument();
  });

  it("exclui um documento (com confirmação)", async () => {
    render(DocumentosPage);
    await screen.findByText(/Planejamento/);

    await fireEvent.click(screen.getByRole("button", { name: /Excluir documento Ata do conselho\.txt/ }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Documento excluído.", "success"));
    expect(window.confirm).toHaveBeenCalled();
    await waitFor(() =>
      expect(screen.queryByText(/Ata do conselho\.txt/)).not.toBeInTheDocument(),
    );
  });

  it("abre as versões e o histórico de um documento", async () => {
    render(DocumentosPage);
    await screen.findByText(/Planejamento/);

    await fireEvent.click(screen.getByRole("button", { name: /Ver versões de PPP da escola\.pdf/ }));
    expect(await screen.findByText("Versões")).toBeInTheDocument();
    expect(screen.getByText("Versão 2")).toBeInTheDocument();
    expect(screen.getByText("Versão 1")).toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Fechar" }));

    await fireEvent.click(screen.getByRole("button", { name: /Ver histórico de PPP da escola\.pdf/ }));
    expect(await screen.findByText("Histórico")).toBeInTheDocument();
    expect((await screen.findAllByText(/nova versão/i)).length).toBeGreaterThan(0);
  });

  it("edita tags de um documento", async () => {
    render(DocumentosPage);
    await screen.findByText(/Planejamento/);

    await fireEvent.click(screen.getByRole("button", { name: /Editar tags de PPP da escola\.pdf/ }));
    const editor = await screen.findByPlaceholderText("Nova tag + Enter");
    await fireEvent.input(editor, { target: { value: "equipe" } });
    await fireEvent.keyDown(editor, { key: "Enter" });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar tags" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Tags salvas.", "success"));
  });

  it("mostra o feed de atividade recente", async () => {
    render(DocumentosPage);
    await screen.findByText(/Planejamento/);

    await fireEvent.click(screen.getByRole("button", { name: /Atividade recente/ }));
    expect((await screen.findAllByText(/Marina Souza/)).length).toBeGreaterThan(0);
  });
});