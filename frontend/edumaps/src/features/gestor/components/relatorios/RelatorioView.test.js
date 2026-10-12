// src/features/gestor/components/relatorios/RelatorioView.test.js
import { describe, it, expect, vi, afterEach } from "vitest";
import { render, screen, within, fireEvent } from "@testing-library/svelte";
import { ApiError } from "@/shared/api/client.js";
import { relatorioParaMarkdown } from "../../utils/relatorioMarkdown.js";
import RelatorioView from "./RelatorioView.svelte";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_LLM_INDISPONIVEL_FIXTURE,
  RELATORIO_INFRAESTRUTURA_FIXTURE,
} from "../../mocks/relatoriosFixtures.js";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

describe("RelatorioView", () => {
  it("renderiza título, recorte e as seções na ordem, por tipo", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE } });
    expect(
      screen.getByRole("heading", { name: "IDEB do território — Porto Velho (RO)" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Porto Velho \(RO\)/, { selector: "p" })).toBeInTheDocument();
    const ids = [...document.querySelectorAll("[data-testid^='secao-']")].map((e) =>
      e.getAttribute("data-testid"),
    );
    expect(ids).toEqual([
      "secao-texto",
      "secao-indicadores",
      "secao-tabela",
      "secao-grafico",
      "secao-tabela", // dados do gráfico, dentro dele
      "secao-texto",
    ]);
    expect(screen.queryByTestId("selo-cache")).toBeNull();
    expect(screen.queryByTestId("aviso-llm")).toBeNull();
  });

  it("rodapé com fontes (descrição, edição, escopo, n) e avisos, sem nome interno", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE } });
    const fontes = screen.getByTestId("relatorio-fontes");
    expect(fontes).toHaveTextContent("IDEB agregado por território");
    expect(fontes).toHaveTextContent("IDEB 2023");
    expect(fontes).toHaveTextContent("municípios de RO");
    expect(fontes).toHaveTextContent("n = 52");
    expect(fontes).not.toHaveTextContent("ideb_agregado");
    expect(within(screen.getByTestId("relatorio-avisos")).getByText(/limitada a 1000 linhas/)).toBeInTheDocument();
  });

  it("selo quando veio do cache", () => {
    render(RelatorioView, { props: { relatorio: { ...RELATORIO_RESULT_FIXTURE, cache_hit: true } } });
    expect(screen.getByTestId("selo-cache")).toHaveTextContent("Gerado a partir do cache");
  });

  it("aviso visível quando o LLM esteve indisponível", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_LLM_INDISPONIVEL_FIXTURE } });
    expect(screen.getByTestId("aviso-llm")).toHaveTextContent("A redação automática não estava disponível");
    expect(screen.getByTestId("relatorio-avisos")).toHaveTextContent("O serviço de redação não respondeu.");
  });

  it("ignora tipos de seção desconhecidos e listas ausentes", () => {
    render(RelatorioView, {
      props: { relatorio: { titulo: "Só título", secoes: [{ id: "z", tipo: "mapa" }] } },
    });
    expect(screen.getByRole("heading", { name: "Só título" })).toBeInTheDocument();
    expect(screen.queryByTestId("relatorio-fontes")).toBeNull();
    expect(screen.queryByTestId("relatorio-avisos")).toBeNull();
  });

  it("ignora tipo desconhecido entre seções conhecidas, sem erro", () => {
    const erro = vi.spyOn(console, "error").mockImplementation(() => {});
    render(RelatorioView, {
      props: {
        relatorio: {
          titulo: "Misto",
          secoes: [
            { id: "a", tipo: "texto", titulo: "Antes", markdown: "oi" },
            { id: "b", tipo: "radar_futuro", titulo: "Não sei desenhar" },
            null,
            { id: "c", tipo: "texto", titulo: "Depois", markdown: "tchau" },
          ],
        },
      },
    });
    expect(screen.getByRole("heading", { name: "Antes" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Depois" })).toBeInTheDocument();
    expect(screen.queryByText("Não sei desenhar")).toBeNull();
    expect(erro).not.toHaveBeenCalled();
    erro.mockRestore();
  });

  it("fase 2: associações, tabelas recolhidas e aviso de associação em destaque", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE } });
    const ids = [...document.querySelectorAll("[data-testid^='secao-']")].map((e) =>
      e.getAttribute("data-testid"),
    );
    expect(ids).toEqual(["secao-texto", "secao-associacoes", "secao-tabela", "secao-tabela"]);
    expect(screen.getAllByTestId("tabela-recolhida")).toHaveLength(2);
    const aviso = screen.getByTestId("aviso-associacao");
    expect(aviso).toHaveAttribute("role", "note");
    expect(aviso).toHaveTextContent("Associação não é causa");
    expect(aviso).toHaveTextContent("não causas");
    // não repete no rodapé
    expect(screen.queryByTestId("relatorio-avisos")).toBeNull();
    expect(screen.getByTestId("relatorio-fontes")).toHaveTextContent("n = 8.535");
  });

  it("sem aviso de associação, não há destaque", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE } });
    expect(screen.queryByTestId("aviso-associacao")).toBeNull();
  });

  describe("ações (fase 3)", () => {
    const originais = { print: window.print, create: URL.createObjectURL, revoke: URL.revokeObjectURL };
    afterEach(() => {
      window.print = originais.print;
      URL.createObjectURL = originais.create;
      URL.revokeObjectURL = originais.revoke;
    });

    it("sem props de ação não há barra", () => {
      render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE } });
      expect(screen.queryByTestId("relatorio-acoes")).toBeNull();
      expect(screen.queryByRole("button", { name: /Imprimir/ })).toBeNull();
    });

    it("a barra some na impressão", () => {
      render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE, acoes: true } });
      expect(screen.getByTestId("relatorio-acoes")).toHaveClass("print:hidden");
      expect(screen.queryByRole("button", { name: "Salvar relatório" })).toBeNull();
    });

    it("Imprimir chama window.print com os <details> abertos e restaura depois", async () => {
      render(RelatorioView, { props: { relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE, acoes: true } });
      const detalhes = [...screen.getByTestId("relatorio-view").querySelectorAll("details")];
      expect(detalhes.length).toBeGreaterThanOrEqual(2);
      // um já aberto pelo usuário continua aberto depois
      detalhes[0].open = true;
      let duranteImpressao = null;
      window.print = vi.fn(() => {
        window.dispatchEvent(new Event("beforeprint"));
        duranteImpressao = detalhes.map((d) => d.open);
        window.dispatchEvent(new Event("afterprint"));
      });
      await fireEvent.click(screen.getByRole("button", { name: "Imprimir / salvar PDF" }));
      expect(window.print).toHaveBeenCalledTimes(1);
      expect(duranteImpressao.every(Boolean)).toBe(true);
      expect(detalhes.map((d) => d.open)).toEqual([true, ...detalhes.slice(1).map(() => false)]);
    });

    it("Ctrl+P (beforeprint sem o botão) também abre os detalhes", () => {
      render(RelatorioView, { props: { relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE } });
      const recolhidas = screen.getAllByTestId("tabela-recolhida");
      window.dispatchEvent(new Event("beforeprint"));
      recolhidas.forEach((d) => expect(d.open).toBe(true));
      window.dispatchEvent(new Event("afterprint"));
      recolhidas.forEach((d) => expect(d.open).toBe(false));
    });

    it("desmontado, não escuta mais a impressão", () => {
      const { unmount } = render(RelatorioView, { props: { relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE } });
      const d = screen.getAllByTestId("tabela-recolhida")[0];
      unmount();
      window.dispatchEvent(new Event("beforeprint"));
      expect(d.open).toBe(false);
      window.dispatchEvent(new Event("afterprint"));
    });

    it("Baixar Markdown baixa o .md do relatório", async () => {
      URL.createObjectURL = vi.fn(() => "blob:md");
      URL.revokeObjectURL = vi.fn();
      let baixado = null;
      const spy = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function () {
        baixado = this.download;
      });
      render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE, acoes: true } });
      await fireEvent.click(screen.getByRole("button", { name: "Baixar Markdown" }));
      expect(baixado).toBe("relatorio-ideb-territorio-porto-velho-2026-10-12.md");
      const blob = URL.createObjectURL.mock.calls[0][0];
      const texto = await new Promise((r) => {
        const fr = new FileReader();
        fr.onload = () => r(fr.result);
        fr.readAsText(blob);
      });
      expect(texto).toBe(relatorioParaMarkdown(RELATORIO_RESULT_FIXTURE));
      spy.mockRestore();
    });

    it("Salvar: salvando → Salvo com link para a lista", async () => {
      let resolver;
      const onSalvar = vi.fn(() => new Promise((r) => (resolver = r)));
      render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE, onSalvar } });
      await fireEvent.click(screen.getByRole("button", { name: "Salvar relatório" }));
      const btn = screen.getByRole("button", { name: "Salvando…" });
      expect(btn).toBeDisabled();
      resolver({ id: 1 });
      expect(await screen.findByTestId("relatorio-salvo")).toHaveTextContent("Salvo");
      expect(screen.getByRole("link", { name: "Ver meus relatórios" })).toHaveAttribute(
        "href",
        "/gestor/relatorios/salvos",
      );
      expect(screen.queryByRole("button", { name: "Salvar relatório" })).toBeNull();
      expect(onSalvar).toHaveBeenCalledTimes(1);
    });

    it("Salvar com erro mostra a mensagem e permite tentar de novo", async () => {
      const onSalvar = vi
        .fn()
        .mockRejectedValueOnce(new ApiError("O relatório ainda não terminou de ser gerado.", { status: 409 }))
        .mockRejectedValueOnce(new Error("rede"))
        .mockResolvedValueOnce({ id: 2 });
      render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE, onSalvar } });
      await fireEvent.click(screen.getByRole("button", { name: "Salvar relatório" }));
      expect(await screen.findByTestId("erro-salvar")).toHaveTextContent("ainda não terminou");
      await fireEvent.click(screen.getByRole("button", { name: "Salvar relatório" }));
      expect(await screen.findByTestId("erro-salvar")).toHaveTextContent("Não foi possível salvar o relatório.");
      await fireEvent.click(screen.getByRole("button", { name: "Salvar relatório" }));
      expect(await screen.findByTestId("relatorio-salvo")).toBeInTheDocument();
      expect(screen.queryByTestId("erro-salvar")).toBeNull();
    });

    it("já salvo: sem botão de salvar", () => {
      render(RelatorioView, {
        props: { relatorio: RELATORIO_RESULT_FIXTURE, acoes: true, onSalvar: vi.fn(), salvo: true },
      });
      expect(screen.queryByRole("button", { name: "Salvar relatório" })).toBeNull();
      expect(screen.getByRole("button", { name: "Baixar Markdown" })).toBeInTheDocument();
    });
  });
});
