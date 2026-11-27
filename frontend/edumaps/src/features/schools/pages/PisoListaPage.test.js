// #601 (QC-01 da P2): a lista do ano dos abaixo do piso na rede.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import { ApiError } from "@/shared/api/client.js";

const mocks = vi.hoisted(() => ({ getPisoLista: vi.fn() }));
vi.mock("../api/pisoApi.js", async (orig) => ({ ...(await orig()), getPisoLista: mocks.getPisoLista }));

import PisoListaPage from "./PisoListaPage.svelte";

const pessoa = (i, sit, base40) => ({
  nome: `PESSOA ${String(i).padStart(3, "0")}`, cpf_mascarado: `xxx.${i}-xx`, situacao: sit, carga_comum: 30,
  base_mensal_tipica: 3212.71, base_40h: base40, piso_proporcional: 3847.97, diferenca_mensal: 635.26, meses: 8, secretaria: true, inep_escolas: [], escolas: [],
});

describe("PisoListaPage (#601)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/municipio/piso?ibge=5103403&ano=2026");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("resumo, CSV, filtro por situação e ordenação da lista inteira (#602)", async () => {
    const pessoas = [
      ...Array.from({ length: 150 }, (_, i) => pessoa(i, "temporario", 4000 + i)),
      { ...pessoa(999, "efetivo", 1000), secretaria: false, inep_escolas: ["51000001"], escolas: ["EMEB UM"] },
    ];
    mocks.getPisoLista.mockResolvedValue({ codigo_ibge: "5103403", municipio: "Cuiabá", uf: "MT", ano: 2026, piso: 5130.63, total: 151, pessoas });
    render(PisoListaPage);
    expect(await screen.findByTestId("resumo-lista-piso")).toHaveTextContent("151 profissionais do magistério ficam abaixo do piso de 2026");
    expect(screen.getByTestId("resumo-lista-piso")).toHaveTextContent("150 temporários, 1 efetivo");
    expect(mocks.getPisoLista).toHaveBeenCalledWith("5103403", "2026");
    expect(screen.getByTestId("csv-lista-piso").getAttribute("href")).toBe("/api/city/5103403/piso?ano=2026&formato=csv");
    expect(screen.getByTestId("contagem-lista-piso")).toHaveTextContent("151 pessoas · página 1 de 2");
    // a menor base por 40 h está na página 2 pela ordem de nome; ordenar traz para a primeira
    expect(screen.queryByText("PESSOA 999")).toBeNull();
    await fireEvent.click(screen.getByText("Base por 40 h"));
    expect(screen.getByText("PESSOA 999")).toBeInTheDocument();
    expect(screen.getByText("EMEB UM")).toBeInTheDocument();
    await fireEvent.change(screen.getByTestId("piso-situacao"), { target: { value: "efetivo" } });
    expect(screen.getByTestId("contagem-lista-piso")).toHaveTextContent("1 pessoa · página 1 de 1");
  });

  it("#604: o aviso de que a folha não se compara ao ano anterior", async () => {
    mocks.getPisoLista.mockResolvedValue({ codigo_ibge: "5103403", municipio: "Cuiabá", uf: "MT", ano: 2026, piso: 5130.63, total: 1,
      pessoas: [pessoa(1, "temporario", 4000)], comparacao_ano_anterior: { ano_anterior: 2025, comparavel: false, motivos: ["magisterio", "secretaria"], magisterio: 6578, magisterio_anterior: 3485, so_secretaria: 3141, so_secretaria_anterior: 60, pct_so_secretaria: 48, pct_so_secretaria_anterior: 2, abaixo_piso_anterior: 6 } });
    render(PisoListaPage);
    expect(await screen.findByTestId("quebra-ano-lista")).toHaveTextContent("A folha de 2026 não se compara à de 2025");
  });

  it("#605: o custo na página e as colunas da diferença", async () => {
    mocks.getPisoLista.mockResolvedValue({ codigo_ibge: "5103403", municipio: "Cuiabá", uf: "MT", ano: 2026, piso: 5130.63, total: 1,
      diferenca_mensal: 635.26, diferenca_situacao: { efetivo: 0, temporario: 635.26, outros: 0 }, pessoas: [pessoa(1, "temporario", 4283.61)] });
    render(PisoListaPage);
    expect(await screen.findByTestId("custo-lista-piso")).toHaveTextContent("faltam R$ 635,26 por mês; em 13 salários, cerca de R$ 8,3 mil no ano, pelo piso de 2026");
    expect(screen.getByText("Falta por mês")).toBeInTheDocument();
    expect(screen.getByText("Piso na carga")).toBeInTheDocument();
    expect(screen.getByText("R$ 635,26")).toBeInTheDocument();
  });

  it("sem piso no ano: diz o motivo", async () => {
    mocks.getPisoLista.mockRejectedValue(new ApiError("Sem piso cadastrado para 2001", { status: 404 }));
    render(PisoListaPage);
    expect(await screen.findByTestId("sem-lista-piso")).toHaveTextContent("Sem piso cadastrado para 2001");
  });
});
