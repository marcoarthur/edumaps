// src/features/gestor/pages/ReunioesWizardPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import ReunioesWizardPage from "./ReunioesWizardPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

async function avancarPassos(user) {
  await fireEvent.click(screen.getByRole("button", { name: /^Continuar/ }));
  await fireEvent.click(screen.getByRole("button", { name: /^Continuar/ }));
  await fireEvent.click(screen.getByRole("button", { name: /^Continuar/ }));
}

describe("ReunioesWizardPage", () => {
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

  it("agenda uma reunião passando pelos 4 passos", async () => {
    window.history.replaceState({}, "", "/gestor/reunioes/nova");
    render(ReunioesWizardPage);

    const titulo = await screen.findByPlaceholderText(/planejamento pedagógico/);
    await fireEvent.input(titulo, { target: { value: "Conselho gestor" } });
    await fireEvent.input(screen.getByLabelText("Data e hora *"), {
      target: { value: "2026-11-15T09:00" },
    });

    // passo 0 -> 1 (quem)
    await fireEvent.click(screen.getByRole("button", { name: /^Continuar/ }));
    await fireEvent.click(screen.getByRole("checkbox", { name: /Ana Professora/ }));
    // passo 1 -> 2 (aviso)
    await fireEvent.click(screen.getByRole("button", { name: /^Continuar/ }));
    // passo 2 -> 3 (pauta)
    await fireEvent.click(screen.getByRole("button", { name: /^Continuar/ }));
    await fireEvent.input(screen.getByPlaceholderText(/1\./), {
      target: { value: "1. Aprovar calendário\n2. Conselho de classe" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Agendar reunião" }));

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith("Reunião agendada!", "success"),
    );
  });

  it("bloqueia o salvar sem título ou hora", async () => {
    window.history.replaceState({}, "", "/gestor/reunioes/nova");
    render(ReunioesWizardPage);
    // mesmo sem preencher, ir direto ao passo 3 exige título (valida no save)
    await screen.findByPlaceholderText(/planejamento pedagógico/);
    await avancarPassos();
    await fireEvent.click(screen.getByRole("button", { name: /Agendar reunião/ }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith(expect.stringMatching(/título/), "warning"));
  });

  it("edita uma reunião existente", async () => {
    window.history.replaceState({}, "", "/gestor/reunioes/51/editar");
    render(ReunioesWizardPage);

    expect(await screen.findByText("Editar reunião")).toBeInTheDocument();
    const titulo = await screen.findByPlaceholderText(/planejamento pedagógico/);
    expect(titulo.value).toContain("Reunião de planejamento pedagógico");
    // datetime-local exige "YYYY-MM-DDTHH:MM" (T, não espaço)
    expect(screen.getByLabelText("Data e hora *").value).toBe("2026-10-10T14:30");
  });
});