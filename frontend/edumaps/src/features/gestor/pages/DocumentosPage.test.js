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

  describe("excluir pasta", () => {
    it("com arquivos: não pede confirmação, avisa o que há dentro e não exclui", async () => {
      render(DocumentosPage);
      await screen.findByText(/Conselho de Classe/);

      await fireEvent.click(screen.getByRole("button", { name: "Excluir pasta Conselho de Classe" }));

      expect(window.confirm).not.toHaveBeenCalled();
      expect(addToast).toHaveBeenCalledWith(
        'A pasta "Conselho de Classe" não está vazia (1 arquivo). Mova ou exclua o conteúdo antes de excluí-la.',
        "warning",
      );
      expect(screen.getByText(/Conselho de Classe/)).toBeInTheDocument();
    });

    it("com subpasta: idem, contando a subpasta", async () => {
      render(DocumentosPage);
      await screen.findByText(/Planejamento/);

      await fireEvent.click(screen.getByRole("button", { name: "Excluir pasta Planejamento" }));

      expect(window.confirm).not.toHaveBeenCalled();
      // contagem exata coberta em constants/documentos.test.js; o mock guarda
      // estado entre testes (outro teste cria subpasta em Planejamento)
      expect(addToast).toHaveBeenCalledWith(expect.stringMatching(/não está vazia \(\d+ subpastas?\)/), "warning");
    });

    it("vazia: confirmação honesta (sem prometer preservar nada) e exclui", async () => {
      render(DocumentosPage);
      await screen.findByText(/Planejamento/);
      await fireEvent.click(screen.getByRole("button", { name: /Nova pasta na raiz/ }));
      await fireEvent.input(screen.getByPlaceholderText("Nome da pasta"), {
        target: { value: "Pasta para excluir" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Criar" }));
      await screen.findByText(/Pasta para excluir/);

      await fireEvent.click(screen.getByRole("button", { name: "Excluir pasta Pasta para excluir" }));

      expect(window.confirm).toHaveBeenCalledWith(
        'Excluir a pasta vazia "Pasta para excluir"? Esta ação não pode ser desfeita.',
      );
      expect(window.confirm.mock.calls[0][0]).not.toMatch(/preservad/);
      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Pasta excluída.", "success"));
      await waitFor(() => expect(screen.queryByText(/Pasta para excluir/)).toBeNull());
    });
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