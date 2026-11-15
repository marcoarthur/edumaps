import { describe, it, expect } from "vitest";
import { rotuloIndicador, resumoUniverso, dataBR } from "./execucao.js";

const COLS = [
  { column_name: "in_agua_potavel", comment: "Há água potável na escola?" },
  { column_name: "prop_licenciatura", comment: "Proporção de docentes com licenciatura (qt_a / qt_b)" },
  { column_name: "in_esgoto_rede_publica", comment: "Esgoto sanitário: rede pública" },
];

describe("rotuloIndicador (#427)", () => {
  it("tira a pergunta e a fórmula do comentário", () => {
    expect(rotuloIndicador("in_agua_potavel", COLS)).toBe("Água potável");
    expect(rotuloIndicador("prop_licenciatura", COLS)).toBe("Proporção de docentes com licenciatura");
    expect(rotuloIndicador("in_esgoto_rede_publica", COLS)).toBe("Esgoto sanitário: rede pública");
  });
  it("sem comentário, o nome da coluna", () => {
    expect(rotuloIndicador("qt_salas", COLS)).toBe("qt_salas");
  });
});

describe("resumoUniverso (#427)", () => {
  it("fora = total - agrupadas, motivos em ordem e escolas fora do mapa", () => {
    const r = resumoUniverso({
      universo: { n_total: 10, n_inativas: 2, n_agrupadas: 6, sem_dado: { prop_licenciatura: 1, in_agua_potavel: 2 } },
      n_atribuicoes: 6, n_no_mapa: 5,
    }, COLS);
    expect(r.total).toBe(10);
    expect(r.fora).toBe(4);
    expect(r.motivos.map((m) => m.n)).toEqual([2, 2, 1]);
    expect(r.motivos[1].texto).toBe("sem dado de água potável");
    expect(r.foraDoMapa).toBe(1);
  });
  it("execução sem universo não quebra", () => {
    expect(resumoUniverso({}).fora).toBe(0);
  });
});

it("dataBR", () => {
  expect(dataBR("2027-02-13")).toBe("13/02/2027");
  expect(dataBR(null)).toBe("");
});

import { formatarIndicador } from "./execucao.js";

it("formatarIndicador: 0/1 e proporção em %, o resto em número (#427)", () => {
  expect(formatarIndicador("in_internet", 0.784)).toBe("78%");
  expect(formatarIndicador("prop_licenciatura", 0.5)).toBe("50%");
  expect(formatarIndicador("nota_media", 251.456)).toBe("251,46");
  expect(formatarIndicador("qt_doc_bas", null)).toBe("–");
});
