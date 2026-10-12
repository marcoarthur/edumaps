// src/features/gestor/utils/relatorioSalvos.test.js
import { describe, it, expect } from "vitest";
import {
  formatarDataHora,
  formatarData,
  textoRecorteSalvo,
  urlGerarDeNovo,
  assistenteNaoPadrao,
} from "./relatorioSalvos.js";

describe("relatorioSalvos", () => {
  it("datas em pt-BR; inválidas viram —", () => {
    expect(formatarDataHora("2026-10-12T12:00:00Z")).toMatch(/^\d{2}\/10\/2026,? \d{2}:\d{2}$/);
    expect(formatarData("2026-10-12T12:00:00Z")).toBe("12/10/2026");
    expect(formatarDataHora(null)).toBe("—");
    expect(formatarData("xx")).toBe("—");
  });

  it("recorte com o nível", () => {
    expect(textoRecorteSalvo({ nivel: "municipio", codigo: "1100205", nome: "Porto Velho" })).toBe(
      "Porto Velho (Município)",
    );
    expect(textoRecorteSalvo({ nivel: "escola", codigo: "11000040" })).toBe("11000040 (Escola)");
    expect(textoRecorteSalvo(null)).toBe("—");
  });

  it("gerar de novo leva recorte, tema, opções e gerar=1", () => {
    const url = urlGerarDeNovo({
      recorte: { nivel: "municipio", codigo: "1200401", nome: "Rio Branco" },
      tema: { id: "ideb_territorio", titulo: "IDEB do território" },
      opcoes: { etapa: "fundamental_ii", rede: "Municipal", vazio: "" },
    });
    const [path, query] = url.split("?");
    expect(path).toBe("/gestor/relatorios");
    expect(Object.fromEntries(new URLSearchParams(query))).toEqual({
      nivel: "municipio",
      codigo: "1200401",
      nome: "Rio Branco",
      tema: "ideb_territorio",
      etapa: "fundamental_ii",
      rede: "Municipal",
      gerar: "1",
    });
  });

  it("sem resumo usa o recorte e o tema do relatório", () => {
    const url = urlGerarDeNovo({
      relatorio: { recorte: { nivel: "uf", codigo: "RO", nome: "Rondônia" }, tema: { id: "infraestrutura_ideb" } },
    });
    expect(url).toBe("/gestor/relatorios?nivel=uf&codigo=RO&nome=Rond%C3%B4nia&tema=infraestrutura_ideb&gerar=1");
  });

  it("assistente padrão não vai na query; o tema também não quando é o próprio assistente", () => {
    expect(
      urlGerarDeNovo({
        recorte: { nivel: "uf", codigo: "RO" },
        tema: { id: "ideb_territorio" },
        assistente: { id: "relatorio", titulo: "Relatório por tema" },
      }),
    ).toBe("/gestor/relatorios?nivel=uf&codigo=RO&tema=ideb_territorio&gerar=1");

    const url = urlGerarDeNovo({
      recorte: { nivel: "municipio", codigo: "1100205", nome: "Porto Velho" },
      tema: { id: "eda_municipio", titulo: "EDA do município" },
      assistente: { id: "eda_municipio", titulo: "EDA do município" },
      opcoes: { etapa: "fundamental_ii" },
    });
    expect(Object.fromEntries(new URLSearchParams(url.split("?")[1]))).toEqual({
      assistente: "eda_municipio",
      nivel: "municipio",
      codigo: "1100205",
      nome: "Porto Velho",
      etapa: "fundamental_ii",
      gerar: "1",
    });
  });

  it("assistente não padrão vem do resumo ou do relatório", () => {
    expect(assistenteNaoPadrao({ assistente: { id: "relatorio", titulo: "Relatório por tema" } })).toBeNull();
    expect(assistenteNaoPadrao({})).toBeNull();
    expect(assistenteNaoPadrao({ assistente: { id: "eda_municipio", titulo: "EDA do município" } })).toEqual({
      id: "eda_municipio",
      titulo: "EDA do município",
    });
    expect(
      assistenteNaoPadrao({ relatorio: { assistente: { id: "eda_municipio", titulo: "EDA", modo: "composto" } } }),
    ).toEqual({ id: "eda_municipio", titulo: "EDA" });
  });
});
