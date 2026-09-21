// src/features/gestor/pages/InventarioPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import InventarioPage from "./InventarioPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("InventarioPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
  });

  it("mostra o baseline do Censo e as categorias", async () => {
    render(InventarioPage);

    expect(await screen.findByText("Inventário da escola")).toBeInTheDocument();
    expect(await screen.findByText("Dispositivos")).toBeInTheDocument();
    expect(screen.getByText("Computadores (aluno)")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Importar para o inventário/ })).toBeInTheDocument();
  });

  it("importa o Censo e lista os recursos", async () => {
    render(InventarioPage);
    await screen.findByText("Dispositivos");

    await fireEvent.click(screen.getByRole("button", { name: /Importar para o inventário/ }));
    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith(expect.stringMatching(/importado/), "success"),
    );

    await fireEvent.click(screen.getByRole("button", { name: "Recursos" }));
    expect(await screen.findByText("Tablets (aluno)")).toBeInTheDocument();
  });

  it("cria um recurso pelo modal", async () => {
    render(InventarioPage);
    await screen.findByText("Dispositivos");

    await fireEvent.click(screen.getByRole("button", { name: "Recursos" }));
    await fireEvent.click(screen.getByRole("button", { name: "+ Novo recurso" }));

    await fireEvent.input(screen.getByPlaceholderText("Ex.: Caixa de giz"), {
      target: { value: "Apagador" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Item criado.", "success"));
    expect(await screen.findByText("Apagador")).toBeInTheDocument();
  });

  it("cadastra um fornecedor", async () => {
    render(InventarioPage);
    await screen.findByText("Dispositivos");

    await fireEvent.click(screen.getByRole("button", { name: "Fornecedores" }));
    await fireEvent.click(screen.getByRole("button", { name: "+ Novo fornecedor" }));

    const inputs = screen.getAllByRole("textbox");
    await fireEvent.input(inputs[0], { target: { value: "Internet Rápida LTDA" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Fornecedor salvo.", "success"));
    expect(await screen.findByText("Internet Rápida LTDA")).toBeInTheDocument();
  });
});
