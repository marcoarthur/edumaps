// src/features/gestor/api/gestorDocumentosApi.test.js
// Exercita a camada API de documentos e planos contra os handlers MSW.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_DOCUMENTOS } from "../mocks/documentosFixtures.js";
import {
  getDocumentos,
  getAuditoriaDocumentos,
  createPasta,
  deletePasta,
  uploadDocumento,
  updateDocumento,
  setDocumentoTags,
  deleteDocumento,
  getDocumentoVersoes,
  getDocumentoHistorico,
  downloadDocumento,
} from "./gestorDocumentosApi.js";

describe("gestorDocumentosApi", () => {
  beforeEach(() => {
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    setSessaoToken(null);
  });

  it("carrega a árvore (pastas, documentos e tags)", async () => {
    const data = await getDocumentos(INEP_DOCUMENTOS);
    expect(data.pastas.length).toBeGreaterThan(0);
    expect(data.documentos.some((d) => d.nome.includes("PPP"))).toBe(true);
    expect(data.tags).toContain("PPP");
  });

  it("cria e exclui uma pasta na raiz", async () => {
    const pasta = await createPasta(INEP_DOCUMENTOS, { nome: "Novos projetos", pasta_pai_id: "" });
    expect(pasta.id).toBeGreaterThan(0);

    await expect(
      createPasta(INEP_DOCUMENTOS, { nome: "Novos projetos", pasta_pai_id: "" }),
    ).rejects.toMatchObject({ status: 409 });

    await deletePasta(INEP_DOCUMENTOS, pasta.id);
    const data = await getDocumentos(INEP_DOCUMENTOS);
    expect(data.pastas.some((p) => p.id === pasta.id)).toBe(false);
  });

  it("upload cria v1; mesmo nome gera v2 e mantém versões", async () => {
    const file = new File(["conteudo v1"], "Projeto Politico Pedagogico.pdf", { type: "application/pdf" });
    const v1 = await uploadDocumento(INEP_DOCUMENTOS, { file, pasta_id: null, tags: ["PPP"] });
    expect(v1.versao).toBe(1);
    expect(v1.novo).toBe(1);

    const v2 = await uploadDocumento(INEP_DOCUMENTOS, {
      file: new File(["conteudo v2"], "Projeto Politico Pedagogico.pdf", { type: "application/pdf" }),
      pasta_id: null,
      tags: ["PPP"],
    });
    expect(v2.documento_id).toBe(v1.documento_id);
    expect(v2.versao).toBe(2);
    expect(v2.novo).toBe(0);

    const versoes = await getDocumentoVersoes(INEP_DOCUMENTOS, v1.documento_id);
    expect(versoes.versoes.map((v) => v.versao)).toEqual([2, 1]);

    await deleteDocumento(INEP_DOCUMENTOS, v1.documento_id);
  });

  it("download devolve blob + filename", async () => {
    const data = await getDocumentos(INEP_DOCUMENTOS);
    const doc = data.documentos.find((d) => d.nome.includes("PPP"));
    const { blob, filename } = await downloadDocumento(INEP_DOCUMENTOS, doc.id);
    expect(filename).toMatch(/\.pdf$/);
    expect(blob.size).toBeGreaterThan(0);
  });

  it("renomeia, move via pasta_id '' (raiz) e embala tags", async () => {
    const data = await getDocumentos(INEP_DOCUMENTOS);
    const doc = data.documentos.find((d) => d.nome.includes("Ata"));

    const renomeado = await updateDocumento(INEP_DOCUMENTOS, doc.id, { nome: "Ata conselho atualizada.txt", pasta_id: "" });
    expect(renomeado.nome).toBe("Ata conselho atualizada.txt");

    const tags = await setDocumentoTags(INEP_DOCUMENTOS, doc.id, ["conselho", "2026"]);
    expect(tags.tags).toEqual(["conselho", "2026"]);

    const historico = await getDocumentoHistorico(INEP_DOCUMENTOS, doc.id);
    expect(historico.historico.some((h) => h.acao === "renomeado")).toBe(true);
  });

  it("carrega o feed de atividade", async () => {
    const data = await getAuditoriaDocumentos(INEP_DOCUMENTOS);
    expect(data.auditoria.length).toBeGreaterThan(0);
    expect(data.auditoria[0]).toHaveProperty("acao");
    expect(data.auditoria[0]).toHaveProperty("gestor");
  });

  it("sem sessão devolve 401", async () => {
    setApiToken(null);
    await expect(getDocumentos(INEP_DOCUMENTOS)).rejects.toMatchObject({ status: 401 });
  });
});