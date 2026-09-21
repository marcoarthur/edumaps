// src/features/gestor/pages/RelacaoDetailPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import RelacaoDetailPage from "./RelacaoDetailPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("RelacaoDetailPage", () => {
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

  it("mostra a relação, a timeline e os documentos", async () => {
    window.history.replaceState({}, "", "/gestor/relacoes/1");
    render(RelacaoDetailPage);

    expect(await screen.findByText("Conserto do telhado da quadra")).toBeInTheDocument();
    expect(screen.getByText("Reunião inicial")).toBeInTheDocument();
    expect(screen.getByText("oficio-telhado.pdf")).toBeInTheDocument();
    expect(screen.getByText("Próxima ação")).toBeInTheDocument();
  });

  it("registra uma interação na timeline", async () => {
    window.history.replaceState({}, "", "/gestor/relacoes/1");
    render(RelacaoDetailPage);
    await screen.findByText("Conserto do telhado da quadra");

    await fireEvent.click(screen.getByRole("button", { name: "+ Interação" }));
    await fireEvent.input(screen.getByPlaceholderText(/Reunião inicial/), {
      target: { value: "Ligação de cobrança" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Interação registrada.", "success"));
    expect(await screen.findByText("Ligação de cobrança")).toBeInTheDocument();
  });
});
