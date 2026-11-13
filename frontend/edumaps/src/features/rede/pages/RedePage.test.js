// src/features/rede/pages/RedePage.test.js — painel da rede (#394, #396).
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, within, fireEvent } from "@testing-library/svelte";
import RedePage from "./RedePage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { REDE_TOKEN } from "../mocks/redeFixtures.js";

const entrarCom = (token) => {
  setSessaoToken(token);
  setApiToken(token);
};
const linha = (nome) => screen.getByText(nome).closest("tr");
const ordemDasEscolas = () =>
  within(within(screen.getByLabelText("Escolas da rede")).getByRole("table")).getAllByRole("row").slice(1).map((r) => r.querySelector("td p")?.textContent);

describe("RedePage (painel da rede)", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => {
    clearSessaoToken();
    setApiToken(null);
  });

  it("mostra a conta, os totais e os planos por escola", async () => {
    entrarCom(REDE_TOKEN);
    render(RedePage);
    expect(await screen.findByText("Técnica da Rede")).toBeInTheDocument();
    expect(screen.getByText("Rede municipal · Alta Floresta D'Oeste/RO")).toBeInTheDocument();
    const totais = within(screen.getByLabelText("Totais da rede"));
    expect(totais.getByText("Sem plano vigente").nextElementSibling).toHaveTextContent("1");
    expect(totais.getByText("Ações atrasadas").nextElementSibling).toHaveTextContent("1");

    const p = within(linha("EMEF Pioneiros"));
    expect(p.getByText("Plano de ação 2026")).toBeInTheDocument();
    expect(p.getByText("40%")).toBeInTheDocument();
    expect(p.getByText("1 de 2 meta(s) medida(s)")).toBeInTheDocument();
    expect(p.getByRole("link", { name: "Relatório de EMEF Pioneiros" }))
      .toHaveAttribute("href", "/rede/escolas/11000040/planos/1/relatorio");

    expect(within(linha("EMEI Pequeno Príncipe")).getByText(/Sem plano vigente \(1 plano\(s\) em rascunho ou encerrado\)/)).toBeInTheDocument();
    const r = within(linha("EMEF Rio Novo"));
    expect(r.getByText("Sem metas medidas")).toBeInTheDocument();
    expect(r.getByText(/2 planos vigentes; mostra o mais recente/)).toBeInTheDocument();
    expect(screen.queryByText("0%")).not.toBeInTheDocument();
  });

  it("filtra e ordena para achar quem precisa de apoio", async () => {
    entrarCom(REDE_TOKEN);
    render(RedePage);
    await screen.findByText("EMEF Pioneiros");
    await fireEvent.change(screen.getByLabelText("Mostrar"), { target: { value: "sem_plano" } });
    expect(ordemDasEscolas()).toEqual(["EMEI Pequeno Príncipe"]);
    await fireEvent.change(screen.getByLabelText("Mostrar"), { target: { value: "atrasadas" } });
    expect(ordemDasEscolas()).toEqual(["EMEF Pioneiros"]);
    await fireEvent.change(screen.getByLabelText("Mostrar"), { target: { value: "sem_andamento" } });
    expect(ordemDasEscolas()).toEqual(["EMEF Rio Novo"]);
    await fireEvent.change(screen.getByLabelText("Mostrar"), { target: { value: "todas" } });
    await fireEvent.change(screen.getByLabelText("Ordenar por"), { target: { value: "andamento" } });
    expect(ordemDasEscolas()).toEqual(["EMEI Pequeno Príncipe", "EMEF Rio Novo", "EMEF Pioneiros"]);
    await fireEvent.change(screen.getByLabelText("Ordenar por"), { target: { value: "atrasadas" } });
    expect(ordemDasEscolas()[0]).toBe("EMEF Pioneiros");
    expect(screen.getByText("3 de 3 escola(s)")).toBeInTheDocument();
  });

  it("mostra o custo por fonte, consolidado e por escola, com os encerrados à parte (#398)", async () => {
    entrarCom(REDE_TOKEN);
    render(RedePage);
    const consolidado = within(await screen.findByRole("table", { name: "Custo consolidado da rede" }));
    const pdde = within(consolidado.getByText("PDDE").closest("tr"));
    expect(pdde.getByText(/1\.500,00/)).toBeInTheDocument();
    expect(pdde.getByText(/900,00/)).toBeInTheDocument();
    const total = within(consolidado.getByText("Total da rede").closest("tr"));
    expect(total.getByText(/4\.700,00/)).toBeInTheDocument();
    expect(screen.getByText(/2 de 2 escola\(s\) com plano vigente informaram custo/)).toBeInTheDocument();
    expect(screen.getByLabelText("Planos encerrados")).toHaveTextContent(/1 em 1 escola\(s\)/);

    expect(screen.queryByRole("table", { name: "Custo por escola" })).not.toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Ver por escola" }));
    const porEscola = within(screen.getByRole("table", { name: "Custo por escola" }));
    const rio = within(porEscola.getByText("EMEF Rio Novo").closest("tr"));
    expect(rio.getByText("—")).toBeInTheDocument(); // executado sem valor: nunca R$ 0
    expect(porEscola.getByRole("link", { name: "Custos no relatório de EMEF Pioneiros" }))
      .toHaveAttribute("href", "/rede/escolas/11000040/planos/1/relatorio");
    expect(screen.queryByText(/R\$\s*0,00/)).not.toBeInTheDocument();
  });

  it("filtra os custos da rede pelo exercício (#404)", async () => {
    entrarCom(REDE_TOKEN);
    render(RedePage);
    const consolidado = () => within(screen.getByRole("table", { name: "Custo consolidado da rede" }));
    expect((await screen.findByRole("table", { name: "Custo consolidado da rede" }))).toHaveTextContent("Fundeb");
    await fireEvent.change(screen.getByLabelText("Exercício"), { target: { value: "2026" } });
    expect(await screen.findByRole("heading", { name: "Custo por fonte de recurso — exercício 2026" })).toBeInTheDocument();
    expect(consolidado().queryByText("Fundeb")).not.toBeInTheDocument();
    expect(screen.getByText(/1 ação\(ões\) sem prazo, fora do exercício/)).toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Ver por escola" }));
    const rio = within(within(screen.getByRole("table", { name: "Custo por escola" })).getByText("EMEF Rio Novo").closest("tr"));
    expect(rio.getAllByText("—").length).toBe(2); // sem previsto nem executado no ano: nunca R$ 0
    expect(screen.queryByText(/R\$\s*0,00/)).not.toBeInTheDocument();
    // a tabela das escolas do painel não muda
    expect(screen.getByText("3 de 3 escola(s)")).toBeInTheDocument();
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
