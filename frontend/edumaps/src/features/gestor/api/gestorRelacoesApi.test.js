// src/features/gestor/api/gestorRelacoesApi.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_RELACOES } from "../mocks/relacoesFixtures.js";
import {
  getRelacoes,
  createCategoria,
  createEntidade,
  createRelacao,
  updateRelacao,
  deleteEntidade,
} from "./gestorRelacoesApi.js";

describe("gestorRelacoesApi", () => {
  beforeEach(() => {
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    setSessaoToken(null);
  });

  it("carrega taxonomia, entidades e relações", async () => {
    const data = await getRelacoes(INEP_RELACOES);
    expect(data.categorias.length).toBe(17);
    expect(data.entidades.length).toBeGreaterThan(0);
    expect(data.relacoes.length).toBeGreaterThan(0);
  });

  it("filtra relações vencidas e por status", async () => {
    const vencidas = await getRelacoes(INEP_RELACOES, { vencidas: "1" });
    expect(vencidas.relacoes).toHaveLength(1);
    expect(vencidas.relacoes[0].vencida).toBe(1);

    const abertas = await getRelacoes(INEP_RELACOES, { status: "aberta" });
    expect(abertas.relacoes.every((r) => r.status === "aberta")).toBe(true);
  });

  it("cria categoria, entidade e relação end to end", async () => {
    const cat = await createCategoria(INEP_RELACOES, { eixo: "entidade", nome: "Sindicato" });
    expect(cat.origem).toBe("manual");

    const ent = await createEntidade(INEP_RELACOES, { nome: "Universidade Federal", tipo: "Instituições parceiras" });
    expect(ent.id).toBeTruthy();

    const rel = await createRelacao(INEP_RELACOES, {
      entidade_id: ent.id,
      finalidade: "Parceria",
      assunto: "Projeto de extensão",
      prioridade: "alta",
      proxima_acao: "Assinar termo",
    });
    expect(rel.entidade_nome).toBe("Universidade Federal");
    expect(rel.status).toBe("aberta");

    const upd = await updateRelacao(INEP_RELACOES, rel.id, {
      entidade_id: ent.id,
      assunto: "Projeto de extensão",
      status: "concluida",
    });
    expect(upd.status).toBe("concluida");
  });

  it("bloqueia excluir entidade com relação", async () => {
    const ent = await createEntidade(INEP_RELACOES, { nome: "Entidade com relação" });
    await createRelacao(INEP_RELACOES, { entidade_id: ent.id, assunto: "Pendência" });
    await expect(deleteEntidade(INEP_RELACOES, ent.id)).rejects.toThrow(/relações/i);
  });
});
