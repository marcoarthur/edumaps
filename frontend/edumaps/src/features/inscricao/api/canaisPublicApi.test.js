// src/features/inscricao/api/canaisPublicApi.test.js
// Contrato público (sem auth): GET/POST /api/canais/inscricao/:token.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { resetCanaisMockState } from "@/features/gestor/mocks/canaisHandlers.js";
import {
  INSCRICAO_TOKEN_EXPIRADO,
  INSCRICAO_TOKEN_LIMITE,
  INSCRICAO_TOKEN_VALIDO,
  TELEFONE_DUPLICADO,
} from "@/features/gestor/mocks/canaisFixtures.js";
import { getInscricaoPublica, enviarInscricao } from "./canaisPublicApi.js";

describe("canaisPublicApi", () => {
  beforeEach(() => resetCanaisMockState());
  afterEach(() => resetCanaisMockState());

  it("carrega os metadados mínimos do formulário (sem PII)", async () => {
    const form = await getInscricaoPublica(INSCRICAO_TOKEN_VALIDO);
    expect(form.lista_nome).toBe("Responsáveis 6ºA");
    expect(form.canal).toBe("telefone");
    expect(form.campos).toEqual(["nome", "telefone"]);
    expect(form).not.toHaveProperty("membros");
    expect(form).not.toHaveProperty("contatos");
  });

  it("registra uma inscrição válida (201)", async () => {
    const res = await enviarInscricao(INSCRICAO_TOKEN_VALIDO, {
      nome: "Nova Pessoa",
      telefone: "+55 11 98888-0000",
      consentimento: true,
    });
    expect(res.ok).toBe(1);
    expect(res.duplicado).toBeUndefined();
  });

  it("marca duplicado quando o telefone já está na lista", async () => {
    const res = await enviarInscricao(INSCRICAO_TOKEN_VALIDO, {
      nome: "Outro Nome",
      telefone: TELEFONE_DUPLICADO,
      consentimento: true,
    });
    expect(res).toMatchObject({ ok: 1, duplicado: 1 });
  });

  it("recusa sem consentimento (400)", async () => {
    await expect(
      enviarInscricao(INSCRICAO_TOKEN_VALIDO, {
        nome: "Sem Consentimento",
        telefone: "+55 11 97777-0000",
        consentimento: false,
      }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it("recusa token expirado/revogado (410)", async () => {
    await expect(getInscricaoPublica(INSCRICAO_TOKEN_EXPIRADO)).rejects.toMatchObject({
      status: 410,
    });
  });

  it("recusa token desconhecido (404)", async () => {
    await expect(getInscricaoPublica("00000000-0000-4000-8000-000000000000")).rejects.toMatchObject(
      { status: 404 },
    );
  });

  it("aplica rate limit / max_usos (429)", async () => {
    await enviarInscricao(INSCRICAO_TOKEN_LIMITE, {
      nome: "Primeiro",
      telefone: "+55 11 96666-0000",
      consentimento: true,
    });
    await expect(
      enviarInscricao(INSCRICAO_TOKEN_LIMITE, {
        nome: "Segundo",
        telefone: "+55 11 96666-0001",
        consentimento: true,
      }),
    ).rejects.toMatchObject({ status: 429 });
  });
});
