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
  { codigo: "aprovacao_ai", rotulo: "Taxa de aprovação — anos iniciais" },
  { codigo: "aprovacao_af", rotulo: "Taxa de aprovação — anos finais" },
  { codigo: "abandono_ai", rotulo: "Taxa de abandono — anos iniciais" },
  { codigo: "abandono_af", rotulo: "Taxa de abandono — anos finais" },
  { codigo: "distorcao_af", rotulo: "Distorção idade-série — anos finais" },
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

  it("taxas de rendimento e distorção do INEP (#376)", () => {
    expect(sugerirIndicador("Reduzir o abandono nos anos finais", CATALOGO)?.codigo).toBe("abandono_af");
    expect(sugerirIndicador("Aumentar a taxa de aprovação", CATALOGO)?.codigo).toBe("aprovacao_ai");
    expect(sugerirIndicador("Diminuir a distorção idade-série", CATALOGO)?.codigo).toBe("distorcao_af");
    expect(sugerirIndicador("Taxa de frequência nas reuniões", CATALOGO)).toBeNull();
  });

  it("não sugere por palavra genérica nem sem relação", () => {
    expect(sugerirIndicador("Reduzir as faltas", CATALOGO)).toBeNull();
    expect(sugerirIndicador("Melhorar a escola", CATALOGO)).toBeNull();
    expect(sugerirIndicador("", CATALOGO)).toBeNull();
  });
});
