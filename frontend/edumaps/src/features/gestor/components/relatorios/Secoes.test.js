// src/features/gestor/components/relatorios/Secoes.test.js
// Componentes de seção do Assistente de Relatório (#219).
import { describe, it, expect, vi } from "vitest";
import { render, screen, within } from "@testing-library/svelte";
import SecaoTexto from "./SecaoTexto.svelte";
import SecaoIndicadores from "./SecaoIndicadores.svelte";
import SecaoTabela from "./SecaoTabela.svelte";
import SecaoGrafico from "./SecaoGrafico.svelte";
import SecaoAssociacoes from "./SecaoAssociacoes.svelte";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_INFRAESTRUTURA_FIXTURE,
  RELATORIO_IDEB_ESCOLAS_FIXTURE,
} from "../../mocks/relatoriosFixtures.js";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

const secao = (id) => RELATORIO_RESULT_FIXTURE.secoes.find((s) => s.id === id);

describe("SecaoTexto", () => {
  it("renderiza o markdown simples com elementos (negrito e lista)", () => {
    render(SecaoTexto, { props: { secao: secao("resumo") } });
    expect(screen.getByRole("heading", { name: "Resumo" })).toBeInTheDocument();
    expect(screen.getByText("Porto Velho").tagName).toBe("STRONG");
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
  });

  it("não interpreta HTML", () => {
    const { container } = render(SecaoTexto, {
      props: { secao: { id: "x", tipo: "texto", markdown: "<img src=x onerror=alert(1)> oi" } },
    });
    expect(container.querySelector("img")).toBeNull();
    expect(screen.getByText(/<img src=x/)).toBeInTheDocument();
  });
});

describe("SecaoIndicadores", () => {
  it("mostra cartões com valor formatado e referência", () => {
    render(SecaoIndicadores, { props: { secao: secao("kpis") } });
    const cards = screen.getAllByTestId("indicador");
    expect(cards).toHaveLength(3);
    expect(cards[0]).toHaveTextContent("IDEB 2023");
    expect(cards[0]).toHaveTextContent("5,6");
    expect(within(cards[0]).getByTestId("indicador-referencia")).toHaveTextContent("RO: 5,9");
    expect(cards[1]).toHaveTextContent("12.345");
    expect(within(cards[1]).queryByTestId("indicador-referencia")).toBeNull();
    expect(cards[2]).toHaveTextContent("93,4%");
    expect(within(cards[2]).getByTestId("indicador-referencia")).toHaveTextContent("RO: 95,1%");
  });
});

describe("SecaoTabela", () => {
  it("é acessível (caption, th scope) e formata as colunas", () => {
    render(SecaoTabela, { props: { secao: secao("tabela_redes") } });
    const tabela = screen.getByRole("table", { name: "IDEB por rede" });
    const cols = within(tabela).getAllByRole("columnheader");
    expect(cols.map((c) => c.textContent.trim())).toEqual([
      "Rede",
      "Escolas",
      "IDEB",
      "Nota SAEB",
      "Aprovação",
    ]);
    cols.forEach((c) => expect(c).toHaveAttribute("scope", "col"));
    const rowHeader = within(tabela).getByRole("rowheader", { name: "Municipal" });
    expect(rowHeader).toHaveAttribute("scope", "row");
    const linha = rowHeader.closest("tr");
    const celulas = within(linha).getAllByRole("cell").map((c) => c.textContent.trim());
    expect(celulas).toEqual(["1.234", "5,5", "5,88", "92,5%"]);
    expect(screen.getByText("Escolas com IDEB divulgado em 2023.")).toBeInTheDocument();
  });

  it("sem linhas mostra mensagem", () => {
    render(SecaoTabela, {
      props: { secao: { id: "v", titulo: "Vazia", colunas: [{ id: "a", rotulo: "A" }], linhas: [] } },
    });
    expect(screen.getByText("Sem dados para este recorte.")).toBeInTheDocument();
  });
});

describe("SecaoTabela (fase 2)", () => {
  it("tabela longa (> 25 linhas) rola na própria caixa; curta não", () => {
    const linhasLongas = Array.from({ length: 30 }, (_, k) => ({ escola: `Escola ${k}`, ideb: 5 }));
    const colunas = [
      { id: "escola", rotulo: "Escola", formato: "texto" },
      { id: "ideb", rotulo: "IDEB", formato: "decimal1" },
    ];
    const { container, unmount } = render(SecaoTabela, {
      props: { secao: { id: "t", tipo: "tabela", titulo: "Longa", colunas, linhas: linhasLongas } },
    });
    expect(container.querySelector('[data-longa="true"]')).not.toBeNull();
    unmount();
    const curta = render(SecaoTabela, {
      props: { secao: { id: "t2", tipo: "tabela", titulo: "Curta", colunas, linhas: linhasLongas.slice(0, 3) } },
    });
    expect(curta.container.querySelector('[data-longa="true"]')).toBeNull();
  });

  const infra = (id) => RELATORIO_INFRAESTRUTURA_FIXTURE.secoes.find((s) => s.id === id);
  const escolas = RELATORIO_IDEB_ESCOLAS_FIXTURE.secoes.find((s) => s.id === "escolas");

  it("recolhida: dentro de <details> fechado, com o título no summary", () => {
    render(SecaoTabela, { props: { secao: infra("coeficientes") } });
    const details = screen.getByTestId("tabela-recolhida");
    expect(details.tagName).toBe("DETAILS");
    expect(details.open).toBe(false);
    const summary = details.querySelector("summary");
    expect(summary).toHaveTextContent("Ver detalhes técnicos: Coeficientes do modelo");
    // continua acessível como tabela (só recolhida)
    const tabela = within(details).getByRole("table", { name: "Coeficientes do modelo", hidden: true });
    expect(within(tabela).getAllByRole("row", { hidden: true })).toHaveLength(3);
  });

  it("não recolhida: sem <details>", () => {
    render(SecaoTabela, { props: { secao: secao("tabela_redes") } });
    expect(screen.queryByTestId("tabela-recolhida")).toBeNull();
    expect(screen.getByRole("table", { name: "IDEB por rede" })).toBeInTheDocument();
  });

  it("_destaque: realça a linha, anuncia \"(sua escola)\" e não vira coluna", () => {
    render(SecaoTabela, { props: { secao: escolas } });
    const tabela = screen.getByRole("table", { name: "Escolas do município" });
    expect(within(tabela).getAllByRole("columnheader").map((c) => c.textContent.trim())).toEqual([
      "Escola",
      "Rede",
      "IDEB",
    ]);
    expect(tabela).not.toHaveTextContent("true");
    const destacada = within(tabela).getByRole("rowheader", {
      name: "EEEF Professora Maria de Lourdes (sua escola)",
    });
    const tr = destacada.closest("tr");
    expect(tr).toHaveAttribute("data-destaque", "true");
    expect(tr).toHaveClass("bg-amber-50");
    const outra = within(tabela).getByRole("rowheader", { name: "EMEF Rio Madeira" }).closest("tr");
    expect(outra).not.toHaveAttribute("data-destaque");
    expect(outra).not.toHaveClass("bg-amber-50");
    expect(tabela.querySelectorAll("[data-destaque]")).toHaveLength(1);
  });

  it("coluna \"_destaque\" declarada por engano é descartada", () => {
    render(SecaoTabela, {
      props: {
        secao: {
          ...escolas,
          colunas: [...escolas.colunas, { id: "_destaque", rotulo: "_destaque" }],
        },
      },
    });
    const tabela = screen.getByRole("table", { name: "Escolas do município" });
    expect(within(tabela).getAllByRole("columnheader")).toHaveLength(3);
  });
});

describe("SecaoAssociacoes", () => {
  const assoc = RELATORIO_INFRAESTRUTURA_FIXTURE.secoes.find((s) => s.id === "associacoes");

  it("título, um cartão por item, corte e n em pt-BR, e a nota", () => {
    render(SecaoAssociacoes, { props: { secao: assoc } });
    expect(screen.getByRole("heading", { name: "O que anda junto com o IDEB" })).toBeInTheDocument();
    const cards = screen.getAllByTestId("associacao");
    expect(cards).toHaveLength(3);
    expect(cards[0]).toHaveTextContent("Biblioteca");
    expect(cards[0]).toHaveTextContent("Urbana");
    expect(within(cards[0]).getByTestId("associacao-n")).toHaveTextContent("8.123 escolas analisadas");
    expect(cards[2]).not.toHaveTextContent("·"); // sem corte
    expect(screen.getByTestId("associacoes-nota")).toHaveTextContent(/^Associação, não causa/);
  });

  it("direção com texto (não só cor) e seta decorativa", () => {
    render(SecaoAssociacoes, { props: { secao: assoc } });
    const dirs = screen.getAllByTestId("associacao-direcao");
    expect(dirs[0]).toHaveTextContent("Associado a resultado maior");
    expect(dirs[1]).toHaveTextContent("Associado a resultado menor");
    expect(dirs[2]).toHaveTextContent("Sem relação clara");
    dirs.forEach((d) => expect(d.querySelector("[aria-hidden='true']")).not.toBeNull());
  });

  it("selo de segurança com texto explicativo", () => {
    render(SecaoAssociacoes, { props: { secao: assoc } });
    const segs = screen.getAllByTestId("associacao-seguranca");
    expect(segs[0]).toHaveTextContent("Segurança alta — é muito pouco provável que seja acaso.");
    expect(segs[1]).toHaveTextContent("Segurança média — é pouco provável que seja acaso.");
    expect(segs[2]).toHaveTextContent("Segurança baixa — pode ser acaso.");
  });

  it("valores fora do contrato caem no neutro; sem itens mostra mensagem", () => {
    const { unmount } = render(SecaoAssociacoes, {
      props: { secao: { id: "a", tipo: "associacoes", itens: [{ rotulo: "X", direcao: "??" }] } },
    });
    expect(screen.getByRole("heading", { name: "Associações" })).toBeInTheDocument();
    expect(screen.getByTestId("associacao-direcao")).toHaveTextContent("Sem relação clara");
    expect(screen.getByTestId("associacao-seguranca")).toHaveTextContent("Segurança baixa");
    expect(screen.queryByTestId("associacao-n")).toBeNull();
    unmount();
    render(SecaoAssociacoes, { props: { secao: { id: "b", tipo: "associacoes", itens: [] } } });
    expect(screen.getByText("Sem associações para este recorte.")).toBeInTheDocument();
  });
});

describe("SecaoGrafico", () => {
  it("barras: usa o wrapper com as linhas convertidas e descreve em texto", () => {
    render(SecaoGrafico, { props: { secao: secao("grafico_serie") } });
    const sec = screen.getByTestId("secao-grafico");
    expect(sec).toHaveAttribute("data-grafico", "barras");
    const stub = screen.getByTestId("carbon-chart-stub");
    expect(stub).toHaveAttribute("data-rows", "6");
    expect(screen.getByText(/IDEB ao longo do tempo/, { selector: "p" })).toBeInTheDocument();
    const figura = screen.getByRole("figure");
    expect(figura).toHaveAccessibleDescription(/Gráfico de barras .* Porto Velho — 2019: 5,2/);
    // os mesmos dados em tabela recolhível
    expect(screen.getByRole("table", { name: "Dados: IDEB ao longo do tempo" })).toBeInTheDocument();
  });

  it("linhas: marca o tipo", () => {
    render(SecaoGrafico, { props: { secao: { ...secao("grafico_serie"), grafico: "linhas" } } });
    expect(screen.getByTestId("secao-grafico")).toHaveAttribute("data-grafico", "linhas");
    expect(screen.getByTestId("grafico-descricao")).toHaveTextContent(/^Gráfico de linhas/);
  });

  it("sem dados não desenha o gráfico", () => {
    render(SecaoGrafico, { props: { secao: { ...secao("grafico_serie"), dados: [] } } });
    expect(screen.queryByTestId("carbon-chart-stub")).toBeNull();
    expect(screen.getByText("Sem dados para este gráfico.")).toBeInTheDocument();
  });
});
