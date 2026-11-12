// src/features/rede/pages/RedePage.test.js — página da conta de rede (#394).
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, within } from "@testing-library/svelte";
import RedePage from "./RedePage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { REDE_TOKEN } from "../mocks/redeFixtures.js";

const entrarCom = (token) => {
  setSessaoToken(token);
  setApiToken(token);
};

describe("RedePage", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => {
    clearSessaoToken();
    setApiToken(null);
  });

  it("mostra as redes da conta e as escolas", async () => {
    entrarCom(REDE_TOKEN);
    render(RedePage);
    expect(await screen.findByText("Técnica da Rede")).toBeInTheDocument();
    expect(screen.getByText("Rede municipal · Alta Floresta D'Oeste/RO")).toBeInTheDocument();
    const tabela = within(screen.getByRole("table"));
    expect(tabela.getByText("EMEF Pioneiros")).toBeInTheDocument();
    expect(tabela.getByText("EMEI Pequeno Príncipe")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Escolas em atividade (2)" })).toBeInTheDocument();
  });

  it("conta de escola ou admin vê o aviso, sem dado da rede", async () => {
    entrarCom(SESSION_TOKEN);
    render(RedePage);
    expect(await screen.findByText(/Esta página é das contas de rede/)).toBeInTheDocument();
    expect(screen.queryByRole("table")).not.toBeInTheDocument();
  });

  it("sem sessão pede login", async () => {
    render(RedePage);
    expect(await screen.findByText("Entre com a conta da rede.")).toBeInTheDocument();
  });
});
