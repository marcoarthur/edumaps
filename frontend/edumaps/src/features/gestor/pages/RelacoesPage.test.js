// src/features/gestor/pages/RelacoesPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import RelacoesPage from "./RelacoesPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("RelacoesPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
  });

  it("lista as relações e destaca a vencida", async () => {
    render(RelacoesPage);

    expect(await screen.findByText("Relações da escola")).toBeInTheDocument();
    expect(await screen.findByText("Conserto do telhado da quadra")).toBeInTheDocument();
    expect(screen.getByText("vencida")).toBeInTheDocument();
    expect(screen.getByText(/Alimenta Merenda LTDA/)).toBeInTheDocument();
  });

  it("cadastra uma entidade externa", async () => {
    render(RelacoesPage);
    await screen.findByText("Conserto do telhado da quadra");

    await fireEvent.click(screen.getByRole("button", { name: "Entidades externas" }));
    await fireEvent.click(screen.getByRole("button", { name: "+ Nova entidade" }));

    await fireEvent.input(screen.getByPlaceholderText(/Prefeitura, Escola X/), {
      target: { value: "Conselho Escolar" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Entidade cadastrada.", "success"));
    expect(await screen.findByText("Conselho Escolar")).toBeInTheDocument();
  });

  it("registra uma nova relação", async () => {
    render(RelacoesPage);
    await screen.findByText("Conserto do telhado da quadra");

    await fireEvent.click(screen.getByRole("button", { name: "+ Nova relação" }));
    await fireEvent.input(screen.getByPlaceholderText(/Conserto do telhado/), {
      target: { value: "Reunião sobre merenda" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Relação registrada.", "success"));
    expect(await screen.findByText("Reunião sobre merenda")).toBeInTheDocument();
  });

  it("mostra a agenda agrupada por mês e a seção sem prazo", async () => {
    render(RelacoesPage);
    await screen.findByText("Conserto do telhado da quadra");

    await fireEvent.click(screen.getByRole("button", { name: "Agenda" }));

    expect(await screen.findByText("janeiro de 2020")).toBeInTheDocument();
    expect(screen.getByText("Sem prazo definido")).toBeInTheDocument();
    expect(screen.getByText("vencida")).toBeInTheDocument();
  });
});
