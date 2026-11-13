// src/features/rede/pages/RedeIndicadoresPage.test.js — metas comparáveis (#397).
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, within, fireEvent } from "@testing-library/svelte";
import RedeIndicadoresPage from "./RedeIndicadoresPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { REDE_TOKEN } from "../mocks/redeFixtures.js";

const entrarCom = (t) => {
  setSessaoToken(t);
  setApiToken(t);
};

describe("RedeIndicadoresPage", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => {
    clearSessaoToken();
    setApiToken(null);
  });

  it("resume cada indicador e lista as escolas, com a base ajustada marcada", async () => {
    entrarCom(REDE_TOKEN);
    render(RedeIndicadoresPage);
    expect(await screen.findByRole("heading", { name: "IDEB — anos iniciais" })).toBeInTheDocument();
    expect(screen.getByText(/2 meta\(s\) manual\(is\) em 1 escola\(s\) não entram na comparação/)).toBeInTheDocument();
    const ideb = screen.getByLabelText("Resumo de IDEB — anos iniciais");
    expect(ideb).toHaveTextContent("2 escola(s) com meta · 1 de 2 meta(s) medida(s) · andamento médio 40%");
    expect(ideb).toHaveTextContent("1 com base ajustada pela escola");
    expect(screen.getByLabelText("Resumo de Tem quadra de esportes")).toHaveTextContent("sem metas medidas");
    expect(screen.queryByText("0%")).not.toBeInTheDocument();

    await fireEvent.click(screen.getByRole("button", { name: "Ver as 2 escola(s)" }));
    const linha = screen.getByRole("link", { name: "EMEF Pioneiros" }).closest("tr");
    expect(screen.getByRole("link", { name: "EMEF Pioneiros" })).toHaveAttribute("href", "/rede/escolas/11000040/planos/1/relatorio");
    expect(within(linha).getByText(/ajustada; oficial 5,2/)).toBeInTheDocument();
    expect(within(linha).getByText("40%")).toBeInTheDocument();
    const rio = screen.getAllByRole("link", { name: "EMEF Rio Novo" })[0].closest("tr");
    expect(within(rio).getByText("Sem dado da escola na fonte")).toBeInTheDocument();
  });

  it("conta que não é de rede vê o aviso", async () => {
    entrarCom(SESSION_TOKEN);
    render(RedeIndicadoresPage);
    expect(await screen.findByText(/Esta página é das contas de rede/)).toBeInTheDocument();
  });
});
