// src/features/config/components/TelegramPublicoStatus.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import TelegramPublicoStatus from "./TelegramPublicoStatus.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { server } from "../../../mocks/server.js";
import {
  resetConfigMockState,
  setTelegramMockState,
  setTelegramMockErro,
  getTelegramStatusChamadas,
} from "../mocks/configHandlers.js";
import {
  TELEGRAM_STATUS_POLLING,
  TELEGRAM_STATUS_WEBHOOK,
  TELEGRAM_WEBHOOK_URL,
} from "../mocks/configFixtures.js";

const comWebhook = (extra = {}) => ({
  ...TELEGRAM_STATUS_WEBHOOK,
  webhook: { ...TELEGRAM_STATUS_WEBHOOK.webhook, ...extra },
});

describe("TelegramPublicoStatus", () => {
  beforeEach(() => {
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
  });
  afterEach(() => setApiToken(null));

  describe("modo polling", () => {
    it("exibe enabled, modo, usuário e dados do polling", async () => {
      setTelegramMockState({ ...TELEGRAM_STATUS_POLLING, polling: { ativo: 0, offset: 812 } });
      render(TelegramPublicoStatus);

      expect(await screen.findByTestId("tg-recebimento")).toHaveTextContent("polling");
      expect(screen.getByTestId("tg-enabled")).toHaveTextContent("ativado");
      expect(screen.getByTestId("tg-username")).toHaveTextContent("@EduMapsConfirmaBot");
      expect(screen.getByTestId("tg-polling-ativo")).toHaveTextContent("parado");
      expect(screen.getByTestId("tg-polling-offset")).toHaveTextContent("812");
      expect(screen.getByRole("button", { name: "Iniciar polling" })).toBeInTheDocument();
      expect(screen.queryByRole("button", { name: "Registrar webhook" })).not.toBeInTheDocument();
      expect(screen.queryByTestId("tg-webhook-url")).not.toBeInTheDocument();
    });

    it("inicia o polling (202) e recarrega o status", async () => {
      render(TelegramPublicoStatus);
      await screen.findByTestId("tg-polling-ativo");
      expect(getTelegramStatusChamadas()).toBe(1);

      await fireEvent.click(screen.getByRole("button", { name: "Iniciar polling" }));

      expect(await screen.findByRole("status")).toHaveTextContent("Polling iniciado (job 4242).");
      await waitFor(() => expect(screen.getByTestId("tg-polling-ativo")).toHaveTextContent("ativo"));
      expect(getTelegramStatusChamadas()).toBe(2);
    });

    it("avisa quando o polling já está ativo (200 ja_ativo)", async () => {
      setTelegramMockState({ ...TELEGRAM_STATUS_POLLING, polling: { ativo: 1, offset: 3 } });
      render(TelegramPublicoStatus);
      await screen.findByTestId("tg-polling-ativo");

      await fireEvent.click(screen.getByRole("button", { name: "Iniciar polling" }));
      expect(await screen.findByRole("status")).toHaveTextContent("O polling já está ativo.");
      await waitFor(() => expect(getTelegramStatusChamadas()).toBe(2));
    });

    it("mostra a mensagem do 409 ao iniciar o polling com o bot desligado", async () => {
      setTelegramMockState({ ...TELEGRAM_STATUS_POLLING, enabled: 0 });
      render(TelegramPublicoStatus);
      expect(await screen.findByTestId("tg-enabled")).toHaveTextContent("desativado");

      await fireEvent.click(screen.getByRole("button", { name: "Iniciar polling" }));
      const alerta = await screen.findByRole("alert");
      expect(alerta).toHaveTextContent(/Não foi possível iniciar o polling/);
      expect(alerta).toHaveTextContent(/desligado/);
      await waitFor(() => expect(getTelegramStatusChamadas()).toBe(2));
    });

    it("desabilita o botão durante a requisição", async () => {
      let liberar;
      const pendente = new Promise((r) => (liberar = r));
      server.use(
        http.post("/api/admin/canais/telegram/polling", async () => {
          await pendente;
          return HttpResponse.json({ ok: 1, job_id: 7 }, { status: 202 });
        }),
      );
      render(TelegramPublicoStatus);
      await screen.findByTestId("tg-polling-ativo");

      const botao = screen.getByRole("button", { name: "Iniciar polling" });
      await fireEvent.click(botao);
      await waitFor(() => expect(botao).toBeDisabled());
      expect(screen.getByRole("button", { name: "Atualizar status" })).toBeDisabled();

      liberar();
      expect(await screen.findByRole("status")).toHaveTextContent("job 7");
      await waitFor(() => expect(screen.getByRole("button", { name: "Iniciar polling" })).not.toBeDisabled());
    });
  });

  describe("modo webhook", () => {
    it("exibe url, pendentes e último erro do webhook", async () => {
      setTelegramMockState(
        comWebhook({ url: TELEGRAM_WEBHOOK_URL, pending_update_count: 5, last_error_message: "Connection refused" }),
      );
      render(TelegramPublicoStatus);

      expect(await screen.findByTestId("tg-recebimento")).toHaveTextContent("webhook");
      expect(screen.getByTestId("tg-webhook-url")).toHaveTextContent(TELEGRAM_WEBHOOK_URL);
      expect(screen.getByTestId("tg-webhook-pendentes")).toHaveTextContent("5");
      expect(screen.getByTestId("tg-webhook-erro")).toHaveTextContent("Connection refused");
      expect(screen.getByRole("button", { name: "Registrar webhook" })).toBeInTheDocument();
      expect(screen.getByRole("button", { name: "Remover webhook" })).toBeInTheDocument();
      expect(screen.queryByRole("button", { name: "Iniciar polling" })).not.toBeInTheDocument();
      expect(screen.queryByTestId("tg-polling-offset")).not.toBeInTheDocument();
    });

    it("registra o webhook (200) e recarrega o status", async () => {
      setTelegramMockState(comWebhook());
      render(TelegramPublicoStatus);
      expect(await screen.findByTestId("tg-webhook-url")).toHaveTextContent("não registrado");

      await fireEvent.click(screen.getByRole("button", { name: "Registrar webhook" }));

      expect(await screen.findByRole("status")).toHaveTextContent(`Webhook registrado em ${TELEGRAM_WEBHOOK_URL}.`);
      await waitFor(() => expect(screen.getByTestId("tg-webhook-url")).toHaveTextContent(TELEGRAM_WEBHOOK_URL));
      expect(getTelegramStatusChamadas()).toBe(2);
    });

    it("mostra o 409 ao registrar sem URL pública/segredo", async () => {
      setTelegramMockState(comWebhook());
      setTelegramMockErro("webhook_post", { status: 409, error: "Defina canais.inscricao.public_base_url." });
      render(TelegramPublicoStatus);
      await screen.findByTestId("tg-webhook-url");

      await fireEvent.click(screen.getByRole("button", { name: "Registrar webhook" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(
        "Não foi possível registrar o webhook: Defina canais.inscricao.public_base_url.",
      );
      await waitFor(() => expect(getTelegramStatusChamadas()).toBe(2));
    });

    it("mostra o 502 quando o Telegram recusa o registro", async () => {
      setTelegramMockState(comWebhook());
      setTelegramMockErro("webhook_post", { status: 502, error: "Bad Request: bad webhook: HTTPS url must be provided" });
      render(TelegramPublicoStatus);
      await screen.findByTestId("tg-webhook-url");

      await fireEvent.click(screen.getByRole("button", { name: "Registrar webhook" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(
        /O Telegram recusou registrar o webhook: Bad Request: bad webhook/,
      );
      await waitFor(() => expect(getTelegramStatusChamadas()).toBe(2));
    });

    it("remove o webhook (200) e recarrega o status", async () => {
      setTelegramMockState(comWebhook({ url: TELEGRAM_WEBHOOK_URL }));
      render(TelegramPublicoStatus);
      expect(await screen.findByTestId("tg-webhook-url")).toHaveTextContent(TELEGRAM_WEBHOOK_URL);

      await fireEvent.click(screen.getByRole("button", { name: "Remover webhook" }));

      expect(await screen.findByRole("status")).toHaveTextContent("Webhook removido.");
      await waitFor(() => expect(screen.getByTestId("tg-webhook-url")).toHaveTextContent("não registrado"));
      expect(getTelegramStatusChamadas()).toBe(2);
    });

    it("mostra o 502 ao remover o webhook", async () => {
      setTelegramMockState(comWebhook({ url: TELEGRAM_WEBHOOK_URL }));
      setTelegramMockErro("webhook_delete", { status: 502, error: "Telegram indisponível" });
      render(TelegramPublicoStatus);
      await screen.findByTestId("tg-webhook-url");

      await fireEvent.click(screen.getByRole("button", { name: "Remover webhook" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(
        "O Telegram recusou remover o webhook: Telegram indisponível",
      );
      await waitFor(() => expect(getTelegramStatusChamadas()).toBe(2));
      expect(screen.getByTestId("tg-webhook-url")).toHaveTextContent(TELEGRAM_WEBHOOK_URL);
    });
  });

  it("recarrega o status pelo botão 'Atualizar status'", async () => {
    render(TelegramPublicoStatus);
    expect(await screen.findByTestId("tg-polling-offset")).toHaveTextContent("0");

    setTelegramMockState({ ...TELEGRAM_STATUS_POLLING, polling: { ativo: 1, offset: 99 } });
    await fireEvent.click(screen.getByRole("button", { name: "Atualizar status" }));

    await waitFor(() => expect(screen.getByTestId("tg-polling-offset")).toHaveTextContent("99"));
    expect(screen.getByTestId("tg-polling-ativo")).toHaveTextContent("ativo");
  });
});
