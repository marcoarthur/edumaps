// src/features/gestor/utils/contatoParser.test.js
import { describe, it, expect } from "vitest";
import { parseContatos } from "./contatoParser.js";

describe("parseContatos", () => {
  it("parseia nome; email; telefone; grupo por linha", () => {
    const res = parseContatos(
      [
        "Maria da Silva; maria@escola.edu.br; +55 11 99999-0001; Professores",
        "João Pai; joao@escola.edu.br; +55 11 99999-0002",
      ].join("\n"),
    );
    expect(res).toHaveLength(2);
    expect(res[0]).toEqual({
      nome: "Maria da Silva",
      email: "maria@escola.edu.br",
      telefone: "+55 11 99999-0001",
      grupo: "Professores",
    });
    expect(res[1].grupo).toBeNull();
  });

  it("aceita vírgula e tab como separadores", () => {
    const res = parseContatos(
      "Maria, maria@x.gov.br, 11999990001, Pais\ntabteste, tab@x.gov.br",
    );
    expect(res[0].nome).toBe("Maria");
    expect(res[1]).toEqual({
      nome: "tabteste",
      email: "tab@x.gov.br",
      telefone: null,
      grupo: null,
    });
  });

  it("ignora linhas vazias e sem nome", () => {
    const res = parseContatos("\n\n; a@b.c;;;  \nJosé; jose@x.gov.br;; far\n");
    expect(res).toHaveLength(1);
    expect(res[0].email).toBe("jose@x.gov.br");
  });

  it("remove aspas/quotes envolventes", () => {
    const res = parseContatos('"Maria"; "maria@x.gov.br"; ""; "Professores"');
    expect(res[0]).toEqual({
      nome: "Maria",
      email: "maria@x.gov.br",
      telefone: null,
      grupo: "Professores",
    });
  });
});