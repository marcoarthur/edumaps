// src/features/gestor/constants/planos.test.js — sugestão de indicador (#397).
import { describe, it, expect } from "vitest";
import { sugerirIndicador } from "./planos.js";

const CATALOGO = [
  { codigo: "ideb_ai", rotulo: "IDEB — anos iniciais" },
  { codigo: "ideb_af", rotulo: "IDEB — anos finais" },
  { codigo: "matriculas_total", rotulo: "Matrículas — total da educação básica" },
  { codigo: "matriculas_infantil", rotulo: "Matrículas — educação infantil" },
  { codigo: "infra_quadra", rotulo: "Tem quadra de esportes" },
  { codigo: "infra_biblioteca", rotulo: "Tem biblioteca ou sala de leitura" },
];

describe("sugerirIndicador", () => {
  it("acha o indicador pela palavra distintiva, sem acento", () => {
    expect(sugerirIndicador("Construir a quadra", CATALOGO)?.codigo).toBe("infra_quadra");
    expect(sugerirIndicador("aumentar matriculas", CATALOGO)?.codigo).toBe("matriculas_total");
  });

  it("prefere o rótulo com mais palavras em comum", () => {
    expect(sugerirIndicador("Aumentar as matrículas da educação infantil", CATALOGO)?.codigo).toBe("matriculas_infantil");
    expect(sugerirIndicador("Subir o IDEB dos anos finais", CATALOGO)?.codigo).toBe("ideb_af");
  });

  it("não sugere por palavra genérica nem sem relação", () => {
    expect(sugerirIndicador("Reduzir as faltas", CATALOGO)).toBeNull();
    expect(sugerirIndicador("Melhorar a escola", CATALOGO)).toBeNull();
    expect(sugerirIndicador("", CATALOGO)).toBeNull();
  });
});
