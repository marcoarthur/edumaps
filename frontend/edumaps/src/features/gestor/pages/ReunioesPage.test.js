// src/features/gestor/pages/ReunioesPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import ReunioesPage from "./ReunioesPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("ReunioesPage", () => {
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

  it("lista reuniões com status, ata e ações", async () => {
    render(ReunioesPage);

    expect(await screen.findByText("Reunião de planejamento pedagógico")).toBeInTheDocument();
    expect(screen.getByText("Semana de ciências: temas de interesse")).toBeInTheDocument();
    expect(screen.getByText("Agendada")).toBeInTheDocument();
    expect(screen.getAllByText("Realizada").length).toBe(2); // badge e botão
    expect(screen.getByText("ata salva")).toBeInTheDocument();
    expect(screen.getAllByRole("link", { name: "Abrir" }).length).toBe(2);
  });

  it("filtra por status", async () => {
    render(ReunioesPage);
    await screen.findByText("Reunião de planejamento pedagógico");

    await fireEvent.change(screen.getByRole("combobox"), {
      target: { value: "realizada" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Filtrar" }));

    await waitFor(() =>
      expect(screen.getByText("Semana de ciências: temas de interesse")).toBeInTheDocument(),
    );
    expect(screen.queryByText("Reunião de planejamento pedagógico")).not.toBeInTheDocument();
  });

  it("marca como realizada pela ação rápida", async () => {
    render(ReunioesPage);
    await screen.findByText("Reunião de planejamento pedagógico");

    const btns = screen.getAllByRole("button", { name: "Realizada" });
    await fireEvent.click(btns[0]);

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith(
        "Reunião marcada como realizada.",
        "success",
      ),
    );
  });
});