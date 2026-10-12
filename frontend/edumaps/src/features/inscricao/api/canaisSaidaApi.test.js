// src/features/inscricao/api/canaisSaidaApi.test.js
// Contrato público da saída dos envios (#216, onda 2): GET/POST /api/canais/sair/:token,
// One-Click (RFC 8058) e reinscrição desfazendo o opt-out.
import { describe, it, expect, beforeEach } from "vitest";
import { resetCanaisMockState, getOptoutsMock } from "@/features/gestor/mocks/canaisHandlers.js";
import {
  CANAIS_ESCOLA_NOME,
  INSCRICAO_TOKEN_AMBOS,
  SAIDA_TOKEN_JA_SAIU,
  SAIDA_TOKEN_LIMITE,
  SAIDA_TOKEN_VALIDO,
} from "@/features/gestor/mocks/canaisFixtures.js";
import { getSaida, confirmarSaida, enviarInscricao } from "./canaisPublicApi.js";

describe("canaisPublicApi — saída dos envios", () => {
  beforeEach(() => resetCanaisMockState());

  it("GET devolve escola, lista e ja_saiu", async () => {
    expect(await getSaida(SAIDA_TOKEN_VALIDO)).toEqual({
      escola_nome: CANAIS_ESCOLA_NOME,
      lista_nome: "Família 8ºC",
      ja_saiu: false,
    });
    expect((await getSaida(SAIDA_TOKEN_JA_SAIU)).ja_saiu).toBe(true);
  });

  it("POST {confirmar:true} registra o opt-out e é idempotente", async () => {
    expect(await confirmarSaida(SAIDA_TOKEN_VALIDO)).toEqual({ ok: 1, ja_saiu: false });
    expect(await confirmarSaida(SAIDA_TOKEN_VALIDO)).toEqual({ ok: 1, ja_saiu: true });
    expect(getOptoutsMock().filter((o) => o.email === "ana@example.org")).toHaveLength(1);
  });

  it("aceita o One-Click (form) e recusa corpo sem confirmação (400)", async () => {
    const url = `/api/canais/sair/${SAIDA_TOKEN_VALIDO}`;
    const semNada = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    expect(semNada.status).toBe(400);
    const oneClick = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: "List-Unsubscribe=One-Click",
    });
    expect(oneClick.status).toBe(200);
    expect(await oneClick.json()).toEqual({ ok: 1, ja_saiu: false });
  });

  it("token desconhecido → 404; antiabuso → 429", async () => {
    await expect(getSaida("0".repeat(32))).rejects.toMatchObject({ status: 404 });
    await expect(confirmarSaida(SAIDA_TOKEN_LIMITE)).rejects.toMatchObject({ status: 429 });
  });

  it("reinscrição na lista com o mesmo e-mail desfaz o opt-out", async () => {
    expect((await getSaida(SAIDA_TOKEN_JA_SAIU)).ja_saiu).toBe(true);
    await enviarInscricao(INSCRICAO_TOKEN_AMBOS, {
      nome: "Clara Pendente",
      telefone: "+55 11 99999-0043",
      email: "Clara@Example.org",
      consentimento: true,
    });
    expect((await getSaida(SAIDA_TOKEN_JA_SAIU)).ja_saiu).toBe(false);
  });
});
