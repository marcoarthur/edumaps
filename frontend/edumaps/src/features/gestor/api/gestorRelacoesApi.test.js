// src/features/gestor/api/gestorRelacoesApi.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_RELACOES } from "../mocks/relacoesFixtures.js";
import {
  getRelacoes,
  getAgenda,
  getIndicadores,
  getRelacao,
  createCategoria,
  createEntidade,
  createRelacao,
  createInteracao,
  createTarefa,
  updateTarefa,
  uploadDocumento,
  downloadDocumento,
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

  it("monta a agenda institucional (com e sem prazo)", async () => {
    const ag = await getAgenda(INEP_RELACOES);
    expect(ag.itens).toHaveLength(1);
    expect(ag.itens[0].vencida).toBe(1);
    expect(ag.sem_prazo).toHaveLength(1);
    expect(ag.vencidas).toBe(1);
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

  it("carrega o detalhe com timeline e documentos", async () => {
    const det = await getRelacao(INEP_RELACOES, 1);
    expect(det.assunto).toContain("telhado");
    expect(det.interacoes.length).toBeGreaterThan(0);
    expect(det.documentos.length).toBeGreaterThan(0);
  });

  it("registra interação e anexa documento", async () => {
    const inter = await createInteracao(INEP_RELACOES, 1, {
      assunto: "Ligação de cobrança",
      canal: "telefone",
    });
    expect(inter.id).toBeTruthy();

    const file = new File(["%PDF-1.4 ofício"], "oficio.pdf", { type: "application/pdf" });
    const up = await uploadDocumento(INEP_RELACOES, 1, { arquivo: file, referencia: "OF-9" });
    expect(up.documentos[0].nome_original).toBe("oficio.pdf");
    expect(up.documentos[0].referencia).toBe("OF-9");

    const { blob, filename } = await downloadDocumento(INEP_RELACOES, 1, up.id);
    expect(filename).toBe("oficio.pdf");
    expect(await blob.text()).toBe("conteudo-do-documento-mock");
  });

  it("monta os indicadores e gerencia tarefas", async () => {
    const ind = await getIndicadores(INEP_RELACOES);
    expect(ind.resumo.relacoes_abertas).toBeGreaterThan(0);
    expect(ind.por_grupo.length).toBeGreaterThan(0);

    const t = await createTarefa(INEP_RELACOES, 1, { descricao: "Protocolar ofício", prazo: "2026-10-01" });
    expect(t.status).toBe("pendente");

    const done = await updateTarefa(INEP_RELACOES, 1, t.id, { descricao: "Protocolar ofício", status: "concluida" });
    expect(done.status).toBe("concluida");
    expect(done.concluida_em).toBeTruthy();
  });
});
