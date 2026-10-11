// src/features/gestor/pages/ListasPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetCanaisMockState } from "../mocks/canaisHandlers.js";
import ListasPage from "./ListasPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("ListasPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
    vi.spyOn(window, "confirm").mockReturnValue(true);
  });
  afterEach(() => {
    window.history.replaceState({}, "", "/");
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("lista as listas da escola com o status do QR", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");
    expect(screen.getByText("Professores")).toBeInTheDocument();
    expect(screen.getByText("QR ativo")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Contatos →" })).toBeInTheDocument();
  });

  it("cria uma nova lista nomeada", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");

    await fireEvent.click(screen.getByRole("button", { name: "+ Nova lista" }));
    await fireEvent.input(screen.getByPlaceholderText(/Nome da lista/), {
      target: { value: "Conselho de classe" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Criar lista" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Lista criada.", "success"));
    expect(await screen.findByText("Conselho de classe")).toBeInTheDocument();
  });

  it("mostra as inscrições (membros) de uma lista", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");

    await fireEvent.click(
      screen.getByRole("button", { name: "Ver inscrições de Responsáveis 6ºA" }),
    );

    expect(await screen.findByText("João Pai")).toBeInTheDocument();
    expect(screen.getByText("Marina Responsável")).toBeInTheDocument();
    expect(screen.getByTestId("membros-table")).toBeInTheDocument();
  });

  it("abre o QR ativo e revoga", async () => {
    render(ListasPage);
    await screen.findByText("Professores");

    await fireEvent.click(screen.getByRole("button", { name: "QR code de Professores" }));
    await screen.findByTestId("qr-modal");
    await waitFor(() =>
      expect(document.querySelector('[data-testid="qr-imagem"] svg')).toBeTruthy(),
    );

    await fireEvent.click(screen.getByRole("button", { name: "Revogar QR" }));
    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith(
        "QR revogado. O link deixa de funcionar.",
        "success",
      ),
    );
    await waitFor(() => expect(screen.queryByTestId("qr-modal")).not.toBeInTheDocument());
  });

  it("gera o QR de uma lista que ainda não tem", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");

    await fireEvent.click(
      screen.getByRole("button", { name: "QR code de Responsáveis 6ºA" }),
    );
    await screen.findByTestId("qr-modal");
    await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("QR code gerado.", "success"));
    await waitFor(() =>
      expect(document.querySelector('[data-testid="qr-imagem"] svg')).toBeTruthy(),
    );
  });
});
