// src/features/gestor/utils/relatorioMarkdown.test.js
// Exportação Markdown do ReportResult (#219, fase 3).
import { describe, it, expect, vi, afterEach } from "vitest";
import {
  relatorioParaMarkdown,
  nomeArquivoMarkdown,
  tabelaMarkdown,
  celulaMarkdown,
  slug,
  baixarArquivo,
  baixarMarkdown,
} from "./relatorioMarkdown.js";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_LLM_INDISPONIVEL_FIXTURE,
  RELATORIO_INFRAESTRUTURA_FIXTURE,
  RELATORIO_IDEB_ESCOLAS_FIXTURE,
} from "../mocks/relatoriosFixtures.js";

describe("relatorioParaMarkdown", () => {
  const md = relatorioParaMarkdown(RELATORIO_RESULT_FIXTURE);

  it("abre com título, tema, recorte e data", () => {
    const linhas = md.split("\n");
    expect(linhas[0]).toBe("# IDEB do território — Porto Velho (RO)");
    expect(md).toContain("**Tema:** IDEB do território  \n**Recorte:** Porto Velho (RO)  \n**Gerado em:** ");
    expect(md).toMatch(/\*\*Gerado em:\*\* \d{2}\/10\/2026,? \d{2}:\d{2}/);
  });

  it("seções de texto: título ## e o markdown da seção, na ordem", () => {
    expect(md).toContain(
      "## Resumo\n\nEm 2023 o IDEB dos anos iniciais em **Porto Velho** foi 5,6.\n\n- Rede municipal: 5,5\n- Rede estadual: 5,8",
    );
    expect(md.indexOf("## Resumo")).toBeLessThan(md.indexOf("## Indicadores principais"));
    expect(md.indexOf("## Indicadores principais")).toBeLessThan(md.indexOf("## IDEB por rede"));
    expect(md.indexOf("## IDEB por rede")).toBeLessThan(md.indexOf("## IDEB ao longo do tempo"));
    expect(md.indexOf("## IDEB ao longo do tempo")).toBeLessThan(md.indexOf("## Como ler"));
  });

  it("rebaixa os títulos internos do texto (## → ###)", () => {
    const out = relatorioParaMarkdown({
      titulo: "T",
      secoes: [{ id: "a", tipo: "texto", titulo: "Resumo", markdown: "## Parte\n\ntexto\n# Topo" }],
    });
    expect(out).toContain("## Resumo\n\n### Parte\n\ntexto\n## Topo");
  });

  it("indicadores em lista com formatos pt-BR e referência", () => {
    expect(md).toContain(
      [
        "- **IDEB 2023:** 5,6 (RO: 5,9)",
        "- **Escolas avaliadas:** 12.345",
        "- **Aprovação:** 93,4% (RO: 95,1%)",
      ].join("\n"),
    );
  });

  it("tabela markdown com cabeçalho, alinhamento e formatos", () => {
    expect(md).toContain(
      [
        "| Rede | Escolas | IDEB | Nota SAEB | Aprovação |",
        "| --- | ---: | ---: | ---: | ---: |",
        "| Municipal | 1.234 | 5,5 | 5,88 | 92,5% |",
        "| Estadual | 87 | 5,8 | 6,10 | 96% |",
      ].join("\n"),
    );
    expect(md).toContain("_Escolas com IDEB divulgado em 2023._");
  });

  it("gráfico vira a tabela dos dados", () => {
    expect(md).toContain(
      [
        "## IDEB ao longo do tempo",
        "",
        "_Gráfico de barras — dados:_",
        "",
        "| Ano | Porto Velho | RO |",
        "| --- | ---: | ---: |",
        "| 2019 | 5,2 | 5,5 |",
        "| 2021 | 5 | 5,4 |",
        "| 2023 | 5,6 | 5,9 |",
      ].join("\n"),
    );
  });

  it("avisos e fontes no fim, sem o nome interno da ferramenta", () => {
    expect(md).toContain("## Avisos\n\n- A consulta de docentes foi limitada a 1000 linhas.");
    expect(md).toContain(
      "## Fontes\n\n- IDEB agregado por território · IDEB 2023 · municípios de RO · n = 52",
    );
    expect(md).not.toContain("ideb_agregado");
    expect(md.indexOf("## Avisos")).toBeGreaterThan(md.indexOf("## Como ler"));
    expect(md.endsWith("\n")).toBe(true);
  });

  it("associações com direção, segurança, corte e n; tabelas recolhidas como detalhes técnicos", () => {
    const out = relatorioParaMarkdown(RELATORIO_INFRAESTRUTURA_FIXTURE);
    expect(out).toContain(
      [
        "## O que anda junto com o IDEB",
        "",
        "- **Biblioteca** (Urbana): associado a resultado maior · segurança alta · n = 8.123",
        "- **Internet** (Rural): associado a resultado menor · segurança média · n = 412",
        "- **Nº de matrículas**: sem relação clara · segurança baixa · n = 8.535",
        "",
        "_Associação, não causa: escolas com biblioteca também diferem em outros aspectos._",
      ].join("\n"),
    );
    expect(out).toContain("## Detalhes técnicos: Coeficientes do modelo");
    expect(out).toContain("| in_biblioteca | Urbana | 0,31 | 0,05 | 0,00 |");
    expect(out).toContain("## Detalhes técnicos: Ajuste por corte");
    // o aviso de associação também vai para os avisos
    expect(out).toContain("- Os resultados mostram associações entre fatores e o IDEB, não causas.");
    expect(out).toContain("**Recorte:** Rondônia");
    expect(out).not.toContain("regressao_escolas");
  });

  it("linha em destaque ganha \"(sua escola)\" e as chaves _* não viram coluna", () => {
    const out = relatorioParaMarkdown(RELATORIO_IDEB_ESCOLAS_FIXTURE);
    expect(out).toContain("| EEEF Professora Maria de Lourdes (sua escola) | Estadual | 5,6 |");
    expect(out).toContain("| EMEF Rio Madeira | Municipal | 6,1 |");
    expect(out).not.toContain("_destaque");
    expect(out).not.toMatch(/\| true \|/);
    expect(out).toContain("- **Posição da sua escola:** 2ª de 3");
  });

  it("escapa \"|\" e quebras de linha nas células", () => {
    const out = relatorioParaMarkdown({
      titulo: "T",
      secoes: [
        {
          id: "t",
          tipo: "tabela",
          titulo: "Escolas",
          colunas: [
            { id: "nome", rotulo: "Nome | escola", formato: "texto" },
            { id: "_interno", rotulo: "Interno", formato: "texto" },
            { id: "ideb", rotulo: "IDEB", formato: "decimal1" },
          ],
          linhas: [{ nome: "EMEF A|B\nC", _interno: "x", ideb: null }],
        },
      ],
    });
    expect(out).toContain("| Nome \\| escola | IDEB |\n| --- | ---: |\n| EMEF A\\|B C | — |");
    expect(out).not.toContain("Interno");
  });

  it("LLM indisponível vira uma nota no topo", () => {
    const out = relatorioParaMarkdown(RELATORIO_LLM_INDISPONIVEL_FIXTURE);
    expect(out).toContain("> A redação automática não estava disponível.");
    expect(out).toContain("- O serviço de redação não respondeu.");
  });

  it("ignora tipos desconhecidos e relatório vazio não quebra", () => {
    const out = relatorioParaMarkdown({
      titulo: "T",
      secoes: [null, { id: "x", tipo: "mapa", titulo: "Mapa" }, { id: "y", tipo: "texto", markdown: "oi" }],
    });
    expect(out).toBe("# T\n\noi\n");
    expect(relatorioParaMarkdown(null)).toBe("# Relatório\n");
  });

  it("tabela sem linhas diz que não há dados", () => {
    expect(tabelaMarkdown([{ id: "a", rotulo: "A", formato: "texto" }, { id: "b", rotulo: "B" }], [])).toBe(
      "| A | B |\n| --- | ---: |\n| Sem dados para este recorte. |  |",
    );
    expect(tabelaMarkdown([], [{ a: 1 }])).toBe("");
  });

  it("celulaMarkdown trata nulos", () => {
    expect(celulaMarkdown(null)).toBe("");
    expect(celulaMarkdown(" a|b ")).toBe("a\\|b");
  });
});

describe("nomeArquivoMarkdown", () => {
  it("relatorio-<tema>-<recorte>-<data>.md com slug", () => {
    expect(nomeArquivoMarkdown(RELATORIO_RESULT_FIXTURE)).toBe(
      "relatorio-ideb-territorio-porto-velho-2026-10-12.md",
    );
    expect(nomeArquivoMarkdown(RELATORIO_INFRAESTRUTURA_FIXTURE)).toBe(
      "relatorio-infraestrutura-ideb-rondonia-2026-10-12.md",
    );
  });

  it("sem nome usa o código; sem data usa hoje", () => {
    const nome = nomeArquivoMarkdown({ tema: { id: "minha_escola" }, recorte: { codigo: "11000040" } });
    expect(nome).toMatch(/^relatorio-minha-escola-11000040-\d{4}-\d{2}-\d{2}\.md$/);
  });

  it("slug remove acentos e símbolos", () => {
    expect(slug("São Paulo — Região Sudeste!")).toBe("sao-paulo-regiao-sudeste");
    expect(slug(null)).toBe("");
  });
});

// o Blob do jsdom não tem .text()
const lerBlob = (b) =>
  new Promise((resolve) => {
    const fr = new FileReader();
    fr.onload = () => resolve(fr.result);
    fr.readAsText(b);
  });

describe("download", () => {
  const original = { create: URL.createObjectURL, revoke: URL.revokeObjectURL };
  afterEach(() => {
    URL.createObjectURL = original.create;
    URL.revokeObjectURL = original.revoke;
    vi.useRealTimers();
  });

  it("baixarArquivo cria um link temporário com o nome e revoga a URL depois", async () => {
    vi.useFakeTimers();
    URL.createObjectURL = vi.fn(() => "blob:teste");
    URL.revokeObjectURL = vi.fn();
    const cliques = [];
    const spy = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function () {
      cliques.push({ href: this.getAttribute("href"), download: this.download, ligado: this.isConnected });
    });
    const blob = baixarArquivo("# oi\n", "a.md");
    expect(blob.type).toBe("text/markdown;charset=utf-8");
    expect(cliques).toEqual([{ href: "blob:teste", download: "a.md", ligado: true }]);
    expect(document.querySelector("a[download]")).toBeNull();
    expect(URL.revokeObjectURL).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1000);
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:teste");
    vi.useRealTimers(); // o FileReader do jsdom usa timers
    expect(await lerBlob(blob)).toBe("# oi\n");
    spy.mockRestore();
  });

  it("baixarMarkdown usa o conteúdo e o nome do relatório", async () => {
    URL.createObjectURL = vi.fn(() => "blob:x");
    URL.revokeObjectURL = vi.fn();
    let nome = null;
    const spy = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function () {
      nome = this.download;
    });
    const blob = baixarMarkdown(RELATORIO_RESULT_FIXTURE);
    expect(nome).toBe("relatorio-ideb-territorio-porto-velho-2026-10-12.md");
    expect(await lerBlob(blob)).toBe(relatorioParaMarkdown(RELATORIO_RESULT_FIXTURE));
    spy.mockRestore();
  });

  it("gráfico com formato na seção (percentual) aplica o formato à tabela de dados", () => {
    const md = relatorioParaMarkdown({
      titulo: "T", recorte: { nome: "BA" }, tema: { titulo: "Professores" },
      secoes: [{ id: "g", tipo: "grafico", grafico: "barras", titulo: "G", formato: "percentual",
        x: { id: "rede", rotulo: "Rede" }, series: [{ id: "sup", rotulo: "Com superior" }],
        dados: [{ rede: "Municipal", sup: 0.803 }] }],
      fontes: [], avisos: [],
    });
    expect(md).toContain("80,3%");
    expect(md).not.toMatch(/\| 0,8 \|/);
  });
});
