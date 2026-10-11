// src/features/gestor/api/gestorCanaisApi.test.js
// Exercita a camada API de Listas & QR contra os handlers MSW (Bearer obrigatório).
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_CANAIS } from "../mocks/canaisFixtures.js";
import { resetCanaisMockState } from "../mocks/canaisHandlers.js";
import {
  listListas,
  createLista,
  getLista,
  deleteLista,
  gerarQrCode,
  revogarQrCode,
  listInscricoes,
} from "./gestorCanaisApi.js";

describe("gestorCanaisApi", () => {
  beforeEach(() => {
    resetCanaisMockState();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    setSessaoToken(null);
  });

  it("lista as listas da escola", async () => {
    const listas = await listListas(INEP_CANAIS);
    expect(listas.length).toBe(2);
    expect(listas.map((l) => l.nome)).toContain("Responsáveis 6ºA");
  });

  it("cria lista e recusa nome duplicado (409)", async () => {
    const criada = await createLista(INEP_CANAIS, { nome: "Conselho de classe" });
    expect(criada.id).toBeTruthy();
    expect(criada.nome).toBe("Conselho de classe");
    expect((await listListas(INEP_CANAIS)).some((l) => l.id === criada.id)).toBe(true);

    await expect(
      createLista(INEP_CANAIS, { nome: "Conselho de classe" }),
    ).rejects.toMatchObject({ status: 409 });
  });

  it("detalha a lista com a contagem de membros", async () => {
    const detalhe = await getLista(INEP_CANAIS, 1);
    expect(detalhe.nome).toBe("Responsáveis 6ºA");
    expect(detalhe.n_membros).toBe(2);
  });

  it("gera, rotaciona e revoga o QR code", async () => {
    const qr = await gerarQrCode(INEP_CANAIS, 1);
    expect(qr.token).toBeTruthy();
    expect(qr.url).toContain(`/inscricao/${qr.token}`);

    const outro = await gerarQrCode(INEP_CANAIS, 1);
    expect(outro.token).not.toBe(qr.token);

    await expect(revogarQrCode(INEP_CANAIS, 1)).resolves.toBeNull();
  });

  it("lista as inscrições da lista", async () => {
    const membros = await listInscricoes(INEP_CANAIS, 1);
    expect(membros).toHaveLength(2);
    expect(membros[0].nome).toBe("João Pai");
    expect(membros.some((m) => m.conflito)).toBe(true);
  });

  it("exclui a lista", async () => {
    await deleteLista(INEP_CANAIS, 1);
    expect((await listListas(INEP_CANAIS)).some((l) => l.id === 1)).toBe(false);
  });

  it("exige sessão (401 sem Bearer)", async () => {
    setApiToken(null);
    await expect(listListas(INEP_CANAIS)).rejects.toMatchObject({ status: 401 });
  });

  it("nega acesso a escola de outro gestor (403)", async () => {
    await expect(listListas("99999999")).rejects.toMatchObject({ status: 403 });
  });
});
