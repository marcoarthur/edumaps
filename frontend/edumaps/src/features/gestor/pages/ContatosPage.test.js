// src/features/gestor/pages/ContatosPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import ContatosPage from "./ContatosPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("ContatosPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
  });
  afterEach(() => {
    window.history.replaceState({}, "", "/");
    setApiToken(null);
  });

  it("lista contatos e grupos da agenda", async () => {
    render(ContatosPage);

    await screen.findByText("Ana Professora");
    expect(screen.getByText("João Pai")).toBeInTheDocument();
    expect(screen.getByText("Professores")).toBeInTheDocument();
    expect(screen.getByText(/6/)).toBeInTheDocument(); // n_contatos do grupo
    // grupos pré-listados pela folha ganham selo e não podem ser excluídos
    expect(screen.getAllByText("folha").length).toBeGreaterThan(0);
    const profess = screen.getByText("Professores").closest("span");
    expect(profess).not.toHaveTextContent("✕");
    expect(screen.getByRole("link", { name: "Reuniões →" })).toBeInTheDocument();
  });

  it("adiciona um novo contato", async () => {
    render(ContatosPage);
    await screen.findByText("Ana Professora");

    await fireEvent.click(screen.getByRole("button", { name: "+ Novo contato" }));
    const nomeInput = screen.getByPlaceholderText("Nome *");
    await fireEvent.input(nomeInput, { target: { value: "Paula Inspetora" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith("Contato salvo.", "success"),
    );
    expect(await screen.findByText("Paula Inspetora")).toBeInTheDocument();
  });

  it("importa contatos colados (nome; email; telefone; grupo)", async () => {
    render(ContatosPage);
    await screen.findByText("Ana Professora");

    const textarea = screen.getByPlaceholderText(/Maria da Silva/);
    await fireEvent.input(textarea, {
      target: {
        value: "Novato; novo@edu.gov.br; +5511999990099; Conselho atualizado",
      },
    });
    expect(screen.getByText(/1 contato\(s\) reconhecido/)).toBeInTheDocument();

    await fireEvent.click(screen.getByRole("button", { name: "Importar" }));

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith("1 contato(s) importado(s).", "success"),
    );
    expect(await screen.findByText("Novato")).toBeInTheDocument();
  });
});