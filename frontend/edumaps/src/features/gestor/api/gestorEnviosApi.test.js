// src/features/gestor/api/gestorEnviosApi.test.js
// Exercita a camada API de envios e listas dinâmicas (#216) contra os handlers MSW.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_CANAIS } from "../mocks/canaisFixtures.js";
import {
  resetEnviosMockState,
  setLimitesEnvioMock,
  avancarEnvioMock,
  mascarar,
} from "../mocks/enviosHandlers.js";
import { server } from "../../../mocks/server.js";
import {
  listEnvios,
  createEnvio,
  atualizarEnvio,
  getEnvio,
  deleteEnvio,
  getLimitesEnvio,
  previaEnvio,
  testeEnvio,
  dispararEnvio,
  cancelarEnvio,
  listDestinatarios,
  listSegmentos,
  getSegmento,
  createSegmento,
  atualizarSegmento,
  deleteSegmento,
  previaCriterios,
  previaSegmento,
  normalizarCriterios,
} from "./gestorEnviosApi.js";

const novo = (o = {}) => ({
  alvo_tipo: "lista",
  alvo_id: 4,
  operacao: "aviso",
  assunto: "Assunto",
  corpo: "Corpo",
  ...o,
});

describe("gestorEnviosApi", () => {
  beforeEach(() => {
    resetEnviosMockState();
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => setApiToken(null));

  describe("envios", () => {
    it("lista paginado, mais recentes primeiro, sem corpo", async () => {
      const r = await listEnvios(INEP_CANAIS);
      expect(r.total).toBe(4);
      expect(r.page).toBe(1);
      expect(r.items[0].id).toBe(2);
      expect(r.items[0].corpo).toBeUndefined();
      const p = await listEnvios(INEP_CANAIS, { page: 2, per_page: 3 });
      expect(p.items).toHaveLength(1);
      expect((await listEnvios(INEP_CANAIS, { status: "rascunho" })).items.map((e) => e.id)).toEqual([1]);
    });

    it("envia status/page/per_page na query", async () => {
      let url = null;
      server.use(
        http.get("/api/gestor/:cod_inep/canais/envios", ({ request }) => {
          url = new URL(request.url);
          return HttpResponse.json({ items: [], total: 0, page: 2, per_page: 5 });
        }),
      );
      await listEnvios(INEP_CANAIS, { status: "enviando", page: 2, per_page: 5 });
      expect(url.searchParams.get("status")).toBe("enviando");
      expect(url.searchParams.get("page")).toBe("2");
      expect(url.searchParams.get("per_page")).toBe("5");
    });

    it("cria, detalha, altera e apaga um rascunho", async () => {
      const criado = await createEnvio(INEP_CANAIS, novo({ alvo_id: "4" }));
      expect(criado).toMatchObject({ status: "rascunho", alvo: { tipo: "lista", id: 4, nome: "Família 8ºC" } });
      const alterado = await atualizarEnvio(INEP_CANAIS, criado.id, { assunto: "Novo", ignorar: 1 });
      expect(alterado.assunto).toBe("Novo");
      expect((await getEnvio(INEP_CANAIS, criado.id)).corpo).toBe("Corpo");
      await expect(deleteEnvio(INEP_CANAIS, criado.id)).resolves.toEqual({ ok: 1 });
      await expect(getEnvio(INEP_CANAIS, criado.id)).rejects.toMatchObject({ status: 404 });
    });

    it("recusa campos inválidos (400) e alvo fora da escola (404)", async () => {
      await expect(createEnvio(INEP_CANAIS, novo({ assunto: "" }))).rejects.toMatchObject({ status: 400 });
      await expect(createEnvio(INEP_CANAIS, novo({ operacao: "spam" }))).rejects.toMatchObject({ status: 400 });
      await expect(createEnvio(INEP_CANAIS, novo({ alvo_id: 999 }))).rejects.toMatchObject({ status: 404 });
    });

    it("PATCH/DELETE de envio já disparado → 409", async () => {
      await expect(atualizarEnvio(INEP_CANAIS, 2, { assunto: "x" })).rejects.toMatchObject({ status: 409 });
      await expect(deleteEnvio(INEP_CANAIS, 3)).rejects.toMatchObject({ status: 409 });
    });

    it("lê os limites", async () => {
      expect(await getLimitesEnvio(INEP_CANAIS)).toMatchObject({ saldo_hoje: 488, cota_diaria: 500, suspensao: null });
    });

    it("prévia traz o rodapé e a estimativa", async () => {
      const p = await previaEnvio(INEP_CANAIS, 1);
      expect(p.texto).toContain("Você recebe este e-mail porque se inscreveu na lista \"Família 8ºC\"");
      expect(p.texto).toContain("/privacidade/sair/EXEMPLO");
      expect(p.estimativa).toEqual({ destinatarios: 3, ignorados_optout: 0, ignorados_duplicado: 0 });
    });

    it("teste: 202, depois 429 após 5; 409 sem SMTP", async () => {
      for (let i = 0; i < 5; i += 1) {
        expect(await testeEnvio(INEP_CANAIS, 1)).toMatchObject({ enviado: 1 });
      }
      await expect(testeEnvio(INEP_CANAIS, 1)).rejects.toMatchObject({ status: 429 });
      setLimitesEnvioMock({ smtp_disponivel: false });
      await expect(testeEnvio(INEP_CANAIS, 3)).rejects.toMatchObject({
        status: 409,
        data: { motivo: "smtp_indisponivel" },
      });
    });

    it("dispara agora: vira enviando com destinatários mascarados", async () => {
      const r = await dispararEnvio(INEP_CANAIS, 1);
      expect(r).toMatchObject({ status: "enviando", contadores: { destinatarios: 3, pendentes: 3 } });
      const d = await listDestinatarios(INEP_CANAIS, 1);
      expect(d.total).toBe(3);
      expect(d.items[0].email).toBe("a***@e***.org");
      avancarEnvioMock(1, 10);
      expect((await getEnvio(INEP_CANAIS, 1)).status).toBe("concluido");
    });

    it("dispara sem corpo quando é agora e com agendado_para quando agenda", async () => {
      const corpos = [];
      server.use(
        http.post("/api/gestor/:cod_inep/canais/envios/:id/disparar", async ({ request }) => {
          corpos.push(await request.json());
          return HttpResponse.json({ id: 1, status: "agendado" }, { status: 202 });
        }),
      );
      await dispararEnvio(INEP_CANAIS, 1);
      await dispararEnvio(INEP_CANAIS, 1, "2026-12-01T12:00:00Z");
      expect(corpos).toEqual([{}, { agendado_para: "2026-12-01T12:00:00Z" }]);
    });

    it("agenda no futuro; recusa data passada (400)", async () => {
      const futuro = new Date(Date.now() + 2 * 86400000).toISOString();
      expect((await dispararEnvio(INEP_CANAIS, 1, futuro)).status).toBe("agendado");
      const outro = await createEnvio(INEP_CANAIS, novo());
      await expect(dispararEnvio(INEP_CANAIS, outro.id, "2020-01-01T00:00:00Z")).rejects.toMatchObject({ status: 400 });
    });

    it("409 por motivo: sem_destinatarios, cota_insuficiente (saldo), acima_do_teto (teto), suspensa, desligado", async () => {
      const semEmail = await createEnvio(INEP_CANAIS, novo({ alvo_id: 1 }));
      await expect(dispararEnvio(INEP_CANAIS, semEmail.id)).rejects.toMatchObject({
        status: 409,
        data: { motivo: "sem_destinatarios" },
      });
      setLimitesEnvioMock({ saldo_hoje: 2 });
      await expect(dispararEnvio(INEP_CANAIS, 1)).rejects.toMatchObject({
        data: { motivo: "cota_insuficiente", saldo: 2 },
      });
      setLimitesEnvioMock({ saldo_hoje: 100, max_destinatarios: 2 });
      await expect(dispararEnvio(INEP_CANAIS, 1)).rejects.toMatchObject({
        data: { motivo: "acima_do_teto", teto: 2 },
      });
      setLimitesEnvioMock({ suspensao: { motivo: "abuso", suspenso_em: "2026-10-12T10:00:00Z" } });
      await expect(dispararEnvio(INEP_CANAIS, 1)).rejects.toMatchObject({ data: { motivo: "escola_suspensa" } });
      setLimitesEnvioMock({ enabled: false });
      await expect(dispararEnvio(INEP_CANAIS, 1)).rejects.toMatchObject({ data: { motivo: "envio_desligado" } });
      await expect(dispararEnvio(INEP_CANAIS, 3)).rejects.toMatchObject({ data: { motivo: "status" } });
    });

    it("cancela um envio em andamento; recusa concluído (409)", async () => {
      const r = await cancelarEnvio(INEP_CANAIS, 2);
      expect(r).toMatchObject({ status: "cancelado", contadores: { cancelados: 2, pendentes: 0 } });
      await expect(cancelarEnvio(INEP_CANAIS, 3)).rejects.toMatchObject({ status: 409 });
    });

    it("filtra destinatários por estado", async () => {
      const r = await listDestinatarios(INEP_CANAIS, 2, { status: "pendente" });
      expect(r.items.map((d) => d.id)).toEqual([202, 203]);
    });

    it("exige sessão (401) e posse da escola (403)", async () => {
      await expect(listEnvios("99999999")).rejects.toMatchObject({ status: 403 });
      setApiToken(null);
      await expect(getLimitesEnvio(INEP_CANAIS)).rejects.toMatchObject({ status: 401 });
    });
  });

  describe("segmentos", () => {
    const criterios = { listas: [4, 5], estado: [], email_confirmado: null };

    it("normaliza critérios", () => {
      expect(normalizarCriterios({ listas: ["4"], email_confirmado: "x", inscritos_desde: "" })).toEqual({
        listas: [4],
        estado: [],
        email_confirmado: null,
        inscritos_desde: null,
        inscritos_ate: null,
      });
    });

    it("lista por nome com as listas resolvidas (existe/nome)", async () => {
      const segs = await listSegmentos(INEP_CANAIS);
      expect(segs.map((s) => s.nome)).toEqual(["Confirmados", "Lista antiga"]);
      expect(segs[1].listas).toEqual([
        { id: 6, nome: "Boletim por e-mail", existe: true },
        { id: 77, nome: null, existe: false },
      ]);
    });

    it("cria, detalha, altera e apaga; nome repetido → 409; lista de fora → 400", async () => {
      const s = await createSegmento(INEP_CANAIS, { nome: "Todos", criterios });
      expect(s.criterios.listas).toEqual([4, 5]);
      expect((await getSegmento(INEP_CANAIS, s.id)).nome).toBe("Todos");
      await expect(createSegmento(INEP_CANAIS, { nome: "todos", criterios })).rejects.toMatchObject({ status: 409 });
      await expect(createSegmento(INEP_CANAIS, { nome: "X", criterios: { listas: [999] } })).rejects.toMatchObject({ status: 400 });
      const alt = await atualizarSegmento(INEP_CANAIS, s.id, { nome: "Todos 2", criterios: { ...criterios, estado: ["confirmado"] } });
      expect(alt.criterios.estado).toEqual(["confirmado"]);
      await deleteSegmento(INEP_CANAIS, s.id);
      await expect(getSegmento(INEP_CANAIS, s.id)).rejects.toMatchObject({ status: 404 });
    });

    it("prévia por critérios: dedupe, amostra mascarada, listas ignoradas", async () => {
      const p = await previaCriterios(INEP_CANAIS, { listas: [4, 5, 77] });
      expect(p.destinatarios).toBe(4);
      expect(p.amostra[0]).toEqual({ nome: "Ana Parcial", email: "a***@e***.org" });
      expect(p.listas_ignoradas).toEqual([77]);
      const conf = await previaCriterios(INEP_CANAIS, { listas: [4], email_confirmado: true });
      expect(conf.destinatarios).toBe(1);
      await expect(previaCriterios(INEP_CANAIS, { listas: [] })).rejects.toMatchObject({ status: 400 });
    });

    it("prévia de um segmento salvo", async () => {
      expect((await previaSegmento(INEP_CANAIS, 1)).destinatarios).toBe(1);
    });

    it("mascara e-mails como no contrato", () => {
      expect(mascarar("joao@dominio.com")).toBe("j***@d***.com");
    });
  });
});
