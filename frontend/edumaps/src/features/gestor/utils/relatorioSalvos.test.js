// src/features/gestor/utils/relatorioSalvos.test.js
import { describe, it, expect } from "vitest";
import { formatarDataHora, formatarData, textoRecorteSalvo, urlGerarDeNovo } from "./relatorioSalvos.js";

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
});
