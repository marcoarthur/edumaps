// src/features/gestor/constants/documentos.test.js
import { describe, it, expect } from "vitest";
import { conteudoDaPasta, avisoPastaNaoVazia } from "./documentos.js";

const PASTAS = [
  { id: 1, nome: "Planejamento", pasta_pai_id: null },
  { id: 2, nome: "2026", pasta_pai_id: 1 },
  { id: 3, nome: "Vazia", pasta_pai_id: null },
];
const DOCS = [
  { id: 10, pasta_id: null },
  { id: 11, pasta_id: 2 },
  { id: 12, pasta_id: 2 },
];

describe("conteudoDaPasta", () => {
  it("conta só o conteúdo direto (subpastas e arquivos imediatos)", () => {
    expect(conteudoDaPasta(PASTAS, DOCS, 1)).toEqual({ subpastas: 1, arquivos: 0 });
    expect(conteudoDaPasta(PASTAS, DOCS, 2)).toEqual({ subpastas: 0, arquivos: 2 });
    expect(conteudoDaPasta(PASTAS, DOCS, 3)).toEqual({ subpastas: 0, arquivos: 0 });
  });

  it("ids como string (vindos do DOM) e arquivos da Raiz não contam para pasta nenhuma", () => {
    expect(conteudoDaPasta(PASTAS, DOCS, "2")).toEqual({ subpastas: 0, arquivos: 2 });
    expect(conteudoDaPasta(PASTAS, [{ id: 1, pasta_id: null }], 1)).toEqual({ subpastas: 1, arquivos: 0 });
  });

  it("tolera listas ausentes", () => {
    expect(conteudoDaPasta(undefined, null, 1)).toEqual({ subpastas: 0, arquivos: 0 });
  });
});

describe("avisoPastaNaoVazia", () => {
  it("diz o que há dentro, no singular e no plural, e o que fazer", () => {
    expect(avisoPastaNaoVazia("Atas", { subpastas: 1, arquivos: 2 })).toBe(
      'A pasta "Atas" não está vazia (2 arquivos e 1 subpasta). Mova ou exclua o conteúdo antes de excluí-la.',
    );
    expect(avisoPastaNaoVazia("X", { subpastas: 0, arquivos: 1 })).toMatch(/\(1 arquivo\)/);
    expect(avisoPastaNaoVazia("X", { subpastas: 3, arquivos: 0 })).toMatch(/\(3 subpastas\)/);
  });
});
