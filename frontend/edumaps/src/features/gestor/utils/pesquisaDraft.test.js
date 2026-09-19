// src/features/gestor/utils/pesquisaDraft.test.js
import { describe, it, expect, vi } from "vitest";
import {
  emptyDraft,
  newPergunta,
  surveyToDraft,
  draftToPayload,
  perguntaErros,
  tituloValido,
  draftValidoParaFinalizar,
} from "./pesquisaDraft.js";

vi.mock("@/shared/utils/uuid.js", () => ({
  uuid: vi.fn(() => `id-${Math.random()}`),
}));

describe("emptyDraft / newPergunta", () => {
  it("emptyDraft cria rascunho sem id e sem perguntas", () => {
    const d = emptyDraft();
    expect(d).toMatchObject({ id: null, titulo: "", perguntas: [] });
  });

  it("newPergunta já nasce com duas opções vazias", () => {
    const p = newPergunta();
    expect(p.tipo).toBe("unica");
    expect(p.obrigatoria).toBe(false);
    expect(p.opcoes).toHaveLength(2);
    expect(p.opcoes[0].id).toBeTruthy();
  });
});

describe("surveyToDraft / draftToPayload", () => {
  it("converte resposta da API para o formato local", () => {
    const d = surveyToDraft({
      id: 1,
      titulo: "T",
      descricao: "D",
      status: "publicada",
      perguntas: [
        {
          id: 11,
          ordem: 1,
          texto: "P?",
          tipo: "unica",
          obrigatoria: true,
          opcoes: [{ id: "a", label: "Sim" }],
        },
      ],
    });
    expect(d.id).toBe(1);
    expect(d.perguntas[0]).toMatchObject({ id: "11", texto: "P?", obrigatoria: true });
  });

  it("draftToPayload omite opções em pergunta de texto livre", () => {
    const payload = draftToPayload({
      id: 1,
      titulo: "T",
      descricao: "",
      perguntas: [
        { id: "11", texto: "Sugestões", tipo: "texto", obrigatoria: true, opcoes: [] },
      ],
    });
    expect(payload.perguntas[0].opcoes).toBeUndefined();
  });
});

describe("perguntaErros", () => {
  it("aceita pergunta única com 2+ opções distintas", () => {
    const p = { texto: "Acolhido?", tipo: "unica", obrigatoria: false, opcoes: [{ label: "Sim" }, { label: "Não" }] };
    expect(perguntaErros(p)).toEqual([]);
  });

  it("rejeita pergunta sem texto", () => {
    const p = { texto: "  ", tipo: "texto", obrigatoria: false, opcoes: [] };
    expect(perguntaErros(p)).not.toHaveLength(0);
  });

  it("rejeita opções repetidas", () => {
    const p = { texto: "X", tipo: "unica", obrigatoria: false, opcoes: [{ label: "Sim" }, { label: "Sim" }] };
    expect(perguntaErros(p)).toContain(
      "As opções não podem se repetir.",
    );
  });

  it("rejeita menos de 2 opções preenchidas", () => {
    const p = { texto: "X", tipo: "dropdown", obrigatoria: false, opcoes: [{ label: "Somente" }, { label: "" }] };
    expect(perguntaErros(p)).not.toHaveLength(0);
  });
});

describe("draftValidoParaFinalizar", () => {
  it("bloqueia rascunho sem id", () => {
    const d = emptyDraft();
    d.titulo = "Pesquisa ok";
    d.perguntas.push(newPergunta());
    expect(draftValidoParaFinalizar(d)).toBeTruthy();
  });

  it("bloqueia sem pergunta", () => {
    const d = { id: 1, titulo: "Pesquisa ok", descricao: "", perguntas: [] };
    expect(draftValidoParaFinalizar(d)).toMatch(/pergunta/i);
  });

  it("aceita rascunho completo", () => {
    const d = { id: 1, titulo: "Pesquisa de clima", descricao: "", perguntas: [] };
    d.perguntas.push(newPergunta());
    d.perguntas[0].texto = "Você se sente acolhido?";
    d.perguntas[0].opcoes = [{ label: "Sim" }, { label: "Não" }];
    expect(draftValidoParaFinalizar(d)).toBeNull();
  });
});

describe("tituloValido", () => {
  it("exige pelo menos 3 caracteres", () => {
    expect(tituloValido("ab")).toBe(false);
    expect(tituloValido("abc")).toBe(true);
  });
});