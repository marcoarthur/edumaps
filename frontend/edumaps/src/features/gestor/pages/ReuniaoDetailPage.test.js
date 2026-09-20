// src/features/gestor/pages/ReuniaoDetailPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import ReuniaoDetailPage from "./ReuniaoDetailPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("ReuniaoDetailPage", () => {
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

  it("exibe detalhes, o convite e os participantes", async () => {
    window.history.replaceState({}, "", "/gestor/reunioes/51");
    render(ReuniaoDetailPage);

    expect(await screen.findByText("Reunião de planejamento pedagógico")).toBeInTheDocument();
    expect(screen.getByText("Agendada")).toBeInTheDocument();
    expect(screen.getAllByText(/Google Meet/).length).toBeGreaterThan(0);
    expect(screen.getByText("Ana Professora")).toBeInTheDocument();
    expect(screen.getByText("Pais e responsáveis")).toBeInTheDocument();
    expect(screen.getAllByText(/Copiar convite/).length).toBeGreaterThan(0);
  });

  it("mostra anexo da pauta e botão de baixar", async () => {
    window.history.replaceState({}, "", "/gestor/reunioes/51");
    render(ReuniaoDetailPage);

    await screen.findByText("Reunião de planejamento pedagógico");
    expect(screen.getByText(/pauta-setembro\.pdf/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Baixar" })).toBeInTheDocument();
  });

  it("salva a ata em texto", async () => {
    window.history.replaceState({}, "", "/gestor/reunioes/51");
    render(ReuniaoDetailPage);
    await screen.findByText("Reunião de planejamento pedagógico");

    await fireEvent.input(screen.getByPlaceholderText(/O que ficou decidido/), {
      target: { value: "Aprovado o novo calendário." },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar ata" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Ata salva.", "success"));
  });
});