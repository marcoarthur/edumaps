// src/features/rede/pages/RedeDocumentoPage.test.js — documento da rede (#405).
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, within, fireEvent } from "@testing-library/svelte";
import RedeDocumentoPage from "./RedeDocumentoPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { REDE_TOKEN } from "../mocks/redeFixtures.js";

const entrarCom = (t) => {
  setSessaoToken(t);
  setApiToken(t);
};

describe("RedeDocumentoPage", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => {
    clearSessaoToken();
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("junta resumo, escolas, custos e metas comparáveis, com o cargo e sem o nome", async () => {
    entrarCom(REDE_TOKEN);
    render(RedeDocumentoPage);
    const doc = within(await screen.findByRole("article", { name: "Documento da rede" }));
    expect(doc.getByRole("heading", { name: "Acompanhamento dos planos de gestão da rede" })).toBeInTheDocument();
    expect(doc.getByText("Rede municipal · Alta Floresta D'Oeste/RO")).toBeInTheDocument();
    expect(doc.getByText(/Emitido em \d{2}\/\d{2}\/\d{4} às \d{2}:\d{2} · por: Técnica pedagógica/)).toBeInTheDocument();
    expect(doc.queryByText(/Técnica da Rede/)).not.toBeInTheDocument();
    expect(doc.queryByText(/tecnica@prefeitura/)).not.toBeInTheDocument();

    expect(doc.getByText("Sem plano vigente").nextElementSibling).toHaveTextContent("1");
    const escolas = within(doc.getByRole("table", { name: "Escolas e planos" }));
    expect(escolas.getAllByRole("row")).toHaveLength(4);
    expect(escolas.getByText("Sem metas medidas")).toBeInTheDocument();
    expect(escolas.getByText(/Sem plano vigente \(1 plano\(s\) em rascunho ou encerrado\)/)).toBeInTheDocument();

    // custos: a tabela por escola já aberta, sem o botão
    expect(doc.getByRole("table", { name: "Custo consolidado da rede" })).toBeInTheDocument();
    expect(doc.getByRole("table", { name: "Custo por escola" })).toBeInTheDocument();
    expect(doc.queryByRole("button", { name: "Ver por escola" })).not.toBeInTheDocument();

    const metas = within(doc.getByRole("table", { name: "Metas comparáveis" }));
    expect(metas.getByText("IDEB — anos iniciais").closest("tr")).toHaveTextContent(/1 de 2.*40%/);
    expect(doc.getByText(/meta\(s\) manual\(is\) em 1 escola\(s\) não entram na/)).toBeInTheDocument();
    expect(doc.queryByText("0%")).not.toBeInTheDocument();
    expect(doc.queryByText(/R\$\s*0,00/)).not.toBeInTheDocument();
  });

  it("filtra os custos pelo exercício e imprime", async () => {
    entrarCom(REDE_TOKEN);
    const print = vi.spyOn(window, "print").mockImplementation(() => {});
    render(RedeDocumentoPage);
    await screen.findByRole("article", { name: "Documento da rede" });
    await fireEvent.change(screen.getByLabelText("Exercício"), { target: { value: "2026" } });
    expect(await screen.findByRole("heading", { name: "Custo por fonte de recurso — exercício 2026" })).toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Imprimir / salvar PDF" }));
    expect(print).toHaveBeenCalled();
  });

  it("conta de escola vê o aviso, sem dado da rede", async () => {
    entrarCom(SESSION_TOKEN);
    render(RedeDocumentoPage);
    expect(await screen.findByText(/Esta página é das contas de rede/)).toBeInTheDocument();
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });
});
