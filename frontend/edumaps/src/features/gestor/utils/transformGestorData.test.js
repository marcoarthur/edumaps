// src/features/gestor/utils/transformGestorData.test.js
import { describe, it, expect } from "vitest";
import {
  buildEtapaRows,
  buildFaixaRows,
  toBreakdownItems,
  buildDisciplinaRows,
  presentStats,
  resumoCards,
  formatInt,
  formatNumber,
} from "./transformGestorData.js";

describe("transformGestorData", () => {
  it("buildEtapaRows mantém só etapas com alunos", () => {
    const rows = buildEtapaRows([
      { key: "creche", label: "Creche", value: 0 },
      { key: "pre_escola", label: "Pré-escola", value: 211 },
    ]);
    expect(rows).toEqual([{ group: "Pré-escola", value: 211 }]);
  });

  it("buildFaixaRows usa group 'Alunos' e key = label", () => {
    const rows = buildFaixaRows([{ key: "4-5", label: "4 a 5 anos", value: 195 }]);
    expect(rows[0]).toEqual({ group: "Alunos", key: "4 a 5 anos", value: 195 });
  });

  it("toBreakdownItems remove zeros", () => {
    const items = toBreakdownItems([
      { key: "matutino", label: "Matutino", value: 211 },
      { key: "noturno", label: "Noturno", value: 0 },
    ]);
    expect(items).toEqual([{ key: "matutino", label: "Matutino", value: 211 }]);
  });

  it("buildDisciplinaRows ordena desc e limita", () => {
    const rows = buildDisciplinaRows(
      [
        { key: "a", label: "A", value: 1 },
        { key: "b", label: "B", value: 9 },
        { key: "c", label: "C", value: 5 },
      ],
      2,
    );
    expect(rows.map((r) => r.key)).toEqual(["B", "C"]);
    expect(rows[0].group).toBe("Docentes");
  });

  it("presentStats conta itens presentes", () => {
    expect(
      presentStats([{ present: 1 }, { present: 0 }, { present: 1 }]),
    ).toEqual({ present: 2, total: 3 });
  });

  it("resumoCards monta os quatro cartões", () => {
    const cards = resumoCards({
      matriculas: 211,
      docentes: 9,
      salas_utilizadas: 6,
      alunos_por_sala: 35.2,
    });
    expect(cards.map((c) => c.key)).toEqual([
      "matriculas",
      "docentes",
      "salas",
      "alunos_por_sala",
    ]);
    expect(cards[3].value).toBe("35,2");
  });

  it("formatInt/formato BR e trunca valores inválidos", () => {
    expect(formatInt(1234)).toBe("1.234");
    expect(formatInt(null)).toBe("—");
    expect(formatNumber(35.17)).toBe("35,2");
    expect(formatNumber(undefined)).toBe("—");
  });
});
