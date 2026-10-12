// src/features/inscricao/api/canaisPublicApi.test.js
// Contrato público (sem auth): GET/POST /api/canais/inscricao/:token.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import {
  resetCanaisMockState,
  confirmarRefMock,
  setCanaisConfirmacaoMock,
  setConsentimentoVigenteMock,
  setEmailDisponivelMock,
} from "@/features/gestor/mocks/canaisHandlers.js";
import {
  INSCRICAO_TOKEN_CONFIRMACAO,
  INSCRICAO_TOKEN_EXPIRADO,
  INSCRICAO_TOKEN_LIMITE,
  INSCRICAO_TOKEN_VALIDO,
  TELEFONE_CONFIRMADO,
  TELEFONE_DUPLICADO,
  TELEFONE_PENDENTE,
  TELEGRAM_BOT_CONFIRMACAO,
  WHATSAPP_CODIGO_MOCK,
  CONSENTIMENTO_VIGENTE,
  EMAIL_CODIGO_MOCK,
  INSCRICAO_TOKEN_AMBOS,
  INSCRICAO_TOKEN_EMAIL,
  INSCRICAO_TOKEN_QUALQUER,
} from "@/features/gestor/mocks/canaisFixtures.js";
import {
  getInscricaoPublica,
  enviarInscricao,
  estadoConfirmacao,
  enviarCodigoWhatsapp,
  verificarCodigoWhatsapp,
  enviarCodigoEmail,
  verificarCodigoEmail,
  consentimentoVigente,
} from "./canaisPublicApi.js";

const inscrever = (telefone = "+55 11 95555-0000", token = INSCRICAO_TOKEN_CONFIRMACAO) =>
  enviarInscricao(token, { nome: "Pessoa Teste", telefone, consentimento: true });

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

  describe("confirmação de posse (#212)", () => {
    it("lista que não exige: resposta idêntica à Fase 0 (sem confirmacao)", async () => {
      const res = await inscrever("+55 11 95555-0001", INSCRICAO_TOKEN_VALIDO);
      expect(res).toEqual({ ok: 1, exclusao_url: expect.any(String) }); // #214: + exclusao_url
    });

    it("lista que exige: devolve ref, estado pendente e canais disponíveis", async () => {
      const { confirmacao } = await inscrever();
      expect(confirmacao.ref).toMatch(/^[0-9a-f]{32}$/);
      expect(confirmacao.estado).toBe("pendente");
      expect(confirmacao.expira_em).toBeTruthy();
      expect(confirmacao.canais).toEqual([
        {
          canal: "telegram",
          url: `https://t.me/${TELEGRAM_BOT_CONFIRMACAO}?start=${confirmacao.ref}`,
        },
        { canal: "whatsapp" },
      ]);
    });

    it("reinscrição: pendente gera nova ref (a anterior some); confirmado não gera", async () => {
      const a = await inscrever(TELEFONE_PENDENTE);
      const b = await inscrever(TELEFONE_PENDENTE);
      expect(b.confirmacao.ref).not.toBe(a.confirmacao.ref);
      await expect(estadoConfirmacao(a.confirmacao.ref)).rejects.toMatchObject({ status: 404 });

      const c = await inscrever(TELEFONE_CONFIRMADO);
      expect(c.confirmacao).toEqual({ estado: "confirmado" });
    });

    it("estadoConfirmacao: pendente → confirmado; ref desconhecida → 404", async () => {
      const { confirmacao } = await inscrever();
      expect(await estadoConfirmacao(confirmacao.ref)).toMatchObject({ estado: "pendente" });
      confirmarRefMock(confirmacao.ref, "telegram");
      expect(await estadoConfirmacao(confirmacao.ref)).toMatchObject({
        estado: "confirmado",
        canais: [],
      });
      await expect(estadoConfirmacao("f".repeat(32))).rejects.toMatchObject({ status: 404 });
    });

    it("canais vazio quando nenhum canal está configurado", async () => {
      setCanaisConfirmacaoMock([]);
      const { confirmacao } = await inscrever();
      expect(confirmacao.canais).toEqual([]);
    });

    it("WhatsApp: envia (202), recusa código inválido (400) e confirma (200)", async () => {
      const { confirmacao } = await inscrever();
      const envio = await enviarCodigoWhatsapp(confirmacao.ref);
      expect(envio.enviado).toBe(1);
      await expect(verificarCodigoWhatsapp(confirmacao.ref, "000000")).rejects.toMatchObject({
        status: 400,
      });
      expect(await verificarCodigoWhatsapp(confirmacao.ref, WHATSAPP_CODIGO_MOCK)).toEqual({
        estado: "confirmado",
      });
      expect(await estadoConfirmacao(confirmacao.ref)).toMatchObject({ estado: "confirmado" });
    });

    it("WhatsApp: limita reenvios (429), canal indisponível (409) e ref inválida (404)", async () => {
      const { confirmacao } = await inscrever();
      for (let i = 0; i < 3; i += 1) await enviarCodigoWhatsapp(confirmacao.ref);
      await expect(enviarCodigoWhatsapp(confirmacao.ref)).rejects.toMatchObject({ status: 429 });

      setCanaisConfirmacaoMock(["telegram"]);
      const outra = await inscrever("+55 11 95555-0009");
      await expect(enviarCodigoWhatsapp(outra.confirmacao.ref)).rejects.toMatchObject({
        status: 409,
      });
      await expect(enviarCodigoWhatsapp("0".repeat(32))).rejects.toMatchObject({ status: 404 });
    });

    it("WhatsApp: verificação sem código enviado → 410", async () => {
      const { confirmacao } = await inscrever();
      await expect(verificarCodigoWhatsapp(confirmacao.ref, "123456")).rejects.toMatchObject({
        status: 410,
      });
    });
  });
  describe("e-mail e LGPD (#214)", () => {
    const ambos = (extra = {}) =>
      enviarInscricao(INSCRICAO_TOKEN_AMBOS, {
        nome: "Pessoa Ambos",
        telefone: "+55 11 94444-0000",
        email: "pessoa@example.org",
        consentimento: true,
        ...extra,
      });

    it("GET traz campos, obrigatórios e o consentimento vigente por coleta", async () => {
      const tel = await getInscricaoPublica(INSCRICAO_TOKEN_VALIDO);
      expect(tel).toMatchObject({ campos: ["nome", "telefone"], obrigatorios: ["nome", "telefone"] });
      expect(tel.consentimento).toEqual({
        versao: CONSENTIMENTO_VIGENTE.versao,
        texto: CONSENTIMENTO_VIGENTE.texto,
      });
      expect((await getInscricaoPublica(INSCRICAO_TOKEN_EMAIL)).campos).toEqual(["nome", "email"]);
      expect(await getInscricaoPublica(INSCRICAO_TOKEN_QUALQUER)).toMatchObject({
        campos: ["nome", "telefone", "email"],
        obrigatorios: ["nome"],
      });
    });

    it("consentimentoVigente devolve a versão publicada", async () => {
      expect(await consentimentoVigente()).toMatchObject({ versao: "1.0" });
    });

    it("400 por obrigatório ausente, e-mail inválido e 'qualquer' sem contato", async () => {
      await expect(ambos({ email: "" })).rejects.toMatchObject({ status: 400 });
      await expect(ambos({ email: "não-é-email" })).rejects.toMatchObject({ status: 400 });
      await expect(
        enviarInscricao(INSCRICAO_TOKEN_QUALQUER, { nome: "Sem contato", consentimento: true }),
      ).rejects.toMatchObject({ status: 400 });
      const soEmail = await enviarInscricao(INSCRICAO_TOKEN_QUALQUER, {
        nome: "Só e-mail",
        email: "so@example.org",
        consentimento: true,
      });
      expect(soEmail.ok).toBe(1);
    });

    it("409 quando a versão do consentimento mudou, com o texto vigente no corpo", async () => {
      setConsentimentoVigenteMock({ versao: "2.0", texto: "Novo texto." });
      const err = await ambos({ consentimento_versao: "1.0" }).catch((e) => e);
      expect(err).toMatchObject({ status: 409 });
      expect(err.data.consentimento).toEqual({ versao: "2.0", texto: "Novo texto." });
      // ausente → grava a vigente (compatibilidade)
      expect((await ambos()).ok).toBe(1);
    });

    it("201 traz exclusao_url; honeypot não", async () => {
      const res = await ambos({ consentimento_versao: "1.0" });
      expect(res.exclusao_url).toMatch(/\/privacidade\/exclusao\/[0-9a-f]{32}$/);
      const bot = await ambos({ _hp: "x" });
      expect(bot.exclusao_url).toBeUndefined();
    });

    it("confirmação por contato: telefone → parcial, e-mail → confirmado", async () => {
      const { confirmacao } = await ambos();
      expect(confirmacao.canais.map((c) => c.canal)).toEqual(["telegram", "whatsapp", "email"]);
      expect(await estadoConfirmacao(confirmacao.ref)).toMatchObject({
        estado: "pendente",
        contatos: { telefone: { estado: "pendente" }, email: { estado: "pendente" } },
      });

      confirmarRefMock(confirmacao.ref, "telegram");
      expect(await estadoConfirmacao(confirmacao.ref)).toMatchObject({
        estado: "parcial",
        contatos: { telefone: { estado: "confirmado", via: "telegram" } },
      });

      expect(await enviarCodigoEmail(confirmacao.ref)).toMatchObject({ enviado: 1 });
      await expect(verificarCodigoEmail(confirmacao.ref, "000000")).rejects.toMatchObject({
        status: 400,
      });
      const fim = await verificarCodigoEmail(confirmacao.ref, EMAIL_CODIGO_MOCK);
      expect(fim).toMatchObject({ estado: "confirmado", contatos: { email: { estado: "confirmado" } } });
      expect(await estadoConfirmacao(confirmacao.ref)).toMatchObject({ estado: "confirmado" });
    });

    it("e-mail: indisponível (409), limite (429), sem código (410)", async () => {
      const { confirmacao } = await ambos();
      await expect(verificarCodigoEmail(confirmacao.ref, "123456")).rejects.toMatchObject({
        status: 410,
      });
      for (let i = 0; i < 3; i += 1) await enviarCodigoEmail(confirmacao.ref);
      await expect(enviarCodigoEmail(confirmacao.ref)).rejects.toMatchObject({ status: 429 });

      setEmailDisponivelMock(false);
      const outra = await ambos({ telefone: "+55 11 94444-0001", email: "outra@example.org" });
      expect(outra.confirmacao.canais.map((c) => c.canal)).not.toContain("email");
      await expect(enviarCodigoEmail(outra.confirmacao.ref)).rejects.toMatchObject({
        status: 409,
      });
    });
  });
});
