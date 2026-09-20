// src/features/gestor/utils/reuniaoDraft.test.js
import { describe, it, expect } from "vitest";
import {
  estadoInicial,
  quandoParaBackend,
  buildReuniaoPayload,
  primeiroErro,
  participantesPreview,
} from "./reuniaoDraft.js";

const contatos = [
  { id: 1, nome: "Ana" },
  { id: 2, nome: "João" },
];
const grupos = [
  { id: 10, nome: "Professores", n_contatos: 3 },
  { id: 11, nome: "Pais", n_contatos: 5 },
];

describe("reuniaoDraft", () => {
  it("estadoInicial usa duração padrão", () => {
    const e = estadoInicial();
    expect(e.duracaoMin).toBe(60);
    expect(e.avisoMetodo).toBe("todos");
    expect([...e.contatoIds]).toEqual([]);
  });

  it("converte datetime-local para o formato do backend", () => {
    expect(quandoParaBackend("2026-10-10T14:30")).toBe("2026-10-10 14:30");
    expect(quandoParaBackend("")).toBeNull();
  });

  it("buildReuniaoPayload limpa Sets e campos vazios", () => {
    const e = estadoInicial();
    e.titulo = "  Reunião de planejamento  ";
    e.dataLocal = "2026-10-10T14:30";
    e.duracaoMin = 90;
    e.ondeLabel = "Sala X";
    e.contatoIds = new Set([1, 2]);
    e.grupoIds = new Set(["10"]);

    const p = buildReuniaoPayload(e);
    expect(p).toEqual({
      titulo: "Reunião de planejamento",
      quando: "2026-10-10 14:30",
      duracao_min: 90,
      onde_label: "Sala X",
      onde_link: null,
      aviso_metodo: "todos",
      pauta_texto: null,
      contato_ids: [1, 2],
      grupo_ids: [10],
    });
    expect(Array.isArray(p.contato_ids)).toBe(true);
    expect(Array.isArray(p.grupo_ids)).toBe(true);
  });

  it("primeiroErro valida título, data, duração e participantes", () => {
    expect(primeiroErro(estadoInicial())).toMatch(/título/);
    const comTitulo = { ...estadoInicial(), titulo: "Reunião X" };
    expect(primeiroErro(comTitulo)).toMatch(/data e o horário/);
    const comData = { ...comTitulo, dataLocal: "2026-10-10T14:30", duracaoMin: 5 };
    expect(primeiroErro(comData)).toMatch(/dura/i);
    const comDuracao = { ...comData, duracaoMin: 60 };
    expect(primeiroErro(comDuracao)).toMatch(/pessoa ou grupo/i);
    const completo = { ...comDuracao, contatoIds: new Set([1]) };
    expect(primeiroErro(completo)).toBeNull();
  });

  it("participantesPreview soma diretos e membros de grupos selecionados", () => {
    const e = estadoInicial();
    e.contatoIds = new Set([1]);
    e.grupoIds = new Set([10]);
    const preview = participantesPreview(contatos, grupos, e);
    expect(preview.diretos.map((c) => c.id)).toEqual([1]);
    expect(preview.grupoSel.map((g) => g.id)).toEqual([10]);
    expect(preview.nExpandidos).toBe(3);
    expect(preview.total).toBe(4);
  });
});