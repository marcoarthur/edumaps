// src/features/gestor/api/gestorReunioesApi.test.js
// Exercita a camada API contra os handlers MSW (precisa do token de sessão).
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import {
  listContatos,
  listGrupos,
  createContato,
  createGrupo,
  listReunioes,
  getReuniao,
  createReuniao,
  salvarAta,
  uploadAnexo,
  downloadAnexo,
} from "./gestorReunioesApi.js";

const INEP = "11000040";

describe("gestorReunioesApi", () => {
  beforeEach(() => {
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    setSessaoToken(null);
  });

  it("lista contatos, grupos e reuniões da escola", async () => {
    const contatos = await listContatos(INEP);
    expect(contatos.length).toBeGreaterThan(0);
    expect(contatos[0].nome).toBe("Ana Professora");

    const grupos = await listGrupos(INEP);
    expect(grupos.some((g) => g.nome === "Professores")).toBe(true);

    const reunioes = await listReunioes(INEP);
    expect(reunioes.some((r) => r.status === "agendada")).toBe(true);
  });

  it("lista reuniões filtrada por status", async () => {
    const reunioes = await listReunioes(INEP, { status: "realizada" });
    expect(reunioes).toHaveLength(1);
    expect(reunioes[0].status).toBe("realizada");
  });

  it("busca reunião por título (case insensitive)", async () => {
    const res = await listReunioes(INEP, { q: "CIÊNCIAS" });
    expect(res.some((r) => r.id === 50)).toBe(true);
  });

  it("detalha uma reunião com participantes e anexos", async () => {
    const det = await getReuniao(INEP, 51);
    expect(det.titulo).toContain("planejamento");
    expect(det.participantes.length).toBeGreaterThan(0);
    expect(det.anexos.some((a) => a.tipo === "pauta")).toBe(true);
  });

  it("cria contato, grupo e reunião end to end", async () => {
    const novo = await createContato(INEP, { nome: "Carlos Secretário", email: "carlos@edu.gov.br" });
    expect(novo.id).toBeTruthy();
    expect(novo.nome).toBe("Carlos Secretário");
    expect((await listContatos(INEP)).some((c) => c.id === novo.id)).toBe(true);

    const grupo = await createGrupo(INEP, "Conselho");
    expect(grupo.nome).toBe("Conselho");

    const reunião = await createReuniao(INEP, {
      titulo: "Conselho de classe",
      quando: "2026-11-05 15:00",
      duracao_min: 60,
      aviso_metodo: "email",
      contato_ids: [novo.id],
      grupo_ids: [],
    });
    expect(reunião.status).toBe("agendada");
  });

  it("salva a ata e devolve tem_ata atualizado", async () => {
    const res = await salvarAta(INEP, 51, "Aprovado o calendário de outubro.");
    expect(res.tem_ata).toBe(1);
    expect(res.ata_texto).toBe("Aprovado o calendário de outubro.");
  });

  it("faz upload multipart do anexo e baixa com filename", async () => {
    const file = new File(["%PDF-1.4 demo"], "pauta.pdf", { type: "application/pdf" });
    const atual = await uploadAnexo(INEP, 51, "pauta", file);
    const anexo = atual.anexos.find((a) => a.tipo === "pauta");
    expect(anexo.nome_original).toBe("pauta.pdf");

    const { blob, filename } = await downloadAnexo(INEP, 51, "pauta");
    expect(filename).toBe("pauta.pdf");
    expect(await blob.text()).toBe("conteudo-do-anexo-mock");
  });
});