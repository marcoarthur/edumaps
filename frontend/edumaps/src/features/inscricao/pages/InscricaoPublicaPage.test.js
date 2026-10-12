// src/features/inscricao/pages/InscricaoPublicaPage.test.js
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, cleanup, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import {
  resetCanaisMockState,
  confirmarRefMock,
  setCanaisConfirmacaoMock,
  ultimaRefConfirmacao,
} from "@/features/gestor/mocks/canaisHandlers.js";
import {
  INSCRICAO_TOKEN_CONFIRMACAO,
  INSCRICAO_TOKEN_EXPIRADO,
  INSCRICAO_TOKEN_LIMITE,
  INSCRICAO_TOKEN_VALIDO,
  TELEFONE_CONFIRMADO,
  TELEFONE_DUPLICADO,
  TELEGRAM_BOT_CONFIRMACAO,
  WHATSAPP_CODIGO_MOCK,
} from "@/features/gestor/mocks/canaisFixtures.js";
import InscricaoPublicaPage from "./InscricaoPublicaPage.svelte";
import {
  POLL_INTERVALO_MS,
  POLL_DURACAO_MS,
} from "../components/ConfirmacaoTelefone.svelte";

function renderPage(token = INSCRICAO_TOKEN_VALIDO, extra = {}) {
  return render(InscricaoPublicaPage, { props: { token, ...extra } });
}

async function preencher({ nome = "Nova Pessoa", telefone = "+55 11 98888-0000" } = {}) {
  await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
    target: { value: nome },
  });
  await fireEvent.input(screen.getByPlaceholderText("(00) 00000-0000"), {
    target: { value: telefone },
  });
  await fireEvent.click(screen.getByRole("checkbox"));
}

describe("InscricaoPublicaPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    document.head.querySelectorAll('meta[name="robots"]').forEach((m) => m.remove());
  });
  afterEach(() => cleanup());

  it("carrega o formulário pelo token e marca noindex", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    expect(screen.getByText(/Escola Estadual Professora Maria/)).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Seu nome completo")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("(00) 00000-0000")).toHaveAttribute(
      "inputmode",
      "numeric",
    );
    const meta = document.querySelector('meta[name="robots"]');
    expect(meta).toHaveAttribute("content", "noindex, nofollow");
  });

  it("envia uma inscrição válida e confirma", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher();
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByTestId("inscricao-sucesso")).toBeInTheDocument();
  });

  it("mostra 'já cadastrado' quando o telefone já está na lista", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher({ telefone: TELEFONE_DUPLICADO });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByTestId("inscricao-ja-cadastrada")).toBeInTheDocument();
  });

  it("valida no cliente antes de enviar", async () => {
    renderPage();
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByText("Informe seu nome.")).toBeInTheDocument();
  });

  it("mostra link indisponível para token expirado (410)", async () => {
    renderPage(INSCRICAO_TOKEN_EXPIRADO);
    expect(await screen.findByTestId("inscricao-indisponivel")).toBeInTheDocument();
  });

  it("mostra erro de rede quando a API falha", async () => {
    server.use(http.get("/api/canais/inscricao/:token", () => HttpResponse.error()));
    renderPage();
    expect(await screen.findByTestId("inscricao-erro")).toBeInTheDocument();
  });

  it("trata o limite de usos (429) com mensagem amigável", async () => {
    const primeiro = renderPage(INSCRICAO_TOKEN_LIMITE);
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher({ telefone: "+55 11 96666-0000" });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    await screen.findByTestId("inscricao-sucesso");
    primeiro.unmount();

    renderPage(INSCRICAO_TOKEN_LIMITE);
    await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
    await preencher({ nome: "Outra Pessoa", telefone: "+55 11 96666-0001" });
    await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
    expect(await screen.findByText(/Muitas inscrições/i)).toBeInTheDocument();
  });

  describe("passo 2 — confirmação do telefone (#212)", () => {
    // Só o setInterval do polling é falso: MSW e waitFor seguem com timers reais.
    beforeEach(() => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    });
    afterEach(() => {
      vi.useRealTimers();
    });

    async function inscreverComConfirmacao({ telefone = "+55 11 95555-0000", extra } = {}) {
      const view = renderPage(INSCRICAO_TOKEN_CONFIRMACAO, extra);
      await screen.findByRole("heading", { name: "Responsáveis 7ºB" });
      await preencher({ telefone });
      await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
      return view;
    }

    it("expõe intervalo de 3s e duração de 5 min para o polling", () => {
      expect(POLL_INTERVALO_MS).toBe(3000);
      expect(POLL_DURACAO_MS).toBe(300000);
    });

    it("mostra o botão do Telegram com o deep link da ref", async () => {
      await inscreverComConfirmacao();
      await screen.findByRole("heading", { name: "Confirme seu telefone" });
      const link = screen.getByRole("link", { name: "Confirmar pelo Telegram" });
      expect(link).toHaveAttribute(
        "href",
        `https://t.me/${TELEGRAM_BOT_CONFIRMACAO}?start=${ultimaRefConfirmacao()}`,
      );
      expect(link).toHaveAttribute("target", "_blank");
      expect(link.getAttribute("rel")).toContain("noopener");
      expect(screen.getByText(/apenas o seu número de telefone/)).toBeInTheDocument();
      expect(screen.queryByTestId("inscricao-sucesso")).not.toBeInTheDocument();
    });

    it("confirma pelo WhatsApp: envia, recusa código inválido e confirma", async () => {
      await inscreverComConfirmacao();
      await screen.findByText("Receber código pelo WhatsApp");
      await fireEvent.click(screen.getByRole("button", { name: "Enviar código" }));

      const campo = await screen.findByPlaceholderText("000000");
      expect(campo).toHaveAttribute("inputmode", "numeric");
      expect(campo).toHaveAttribute("autocomplete", "one-time-code");
      expect(campo).toHaveAttribute("maxlength", "6");
      expect(screen.getByRole("button", { name: "Reenviar código" })).toBeInTheDocument();

      await fireEvent.input(campo, { target: { value: "000000" } });
      await fireEvent.click(screen.getByRole("button", { name: "Verificar" }));
      expect(await screen.findByText(/Código inválido/)).toBeInTheDocument();

      await fireEvent.input(campo, { target: { value: WHATSAPP_CODIGO_MOCK } });
      await fireEvent.click(screen.getByRole("button", { name: "Verificar" }));
      expect(
        await screen.findByRole("heading", { name: "Telefone confirmado!" }),
      ).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0); // polling parou
    });

    it("WhatsApp: trata muitas tentativas (429) ao reenviar", async () => {
      await inscreverComConfirmacao();
      await fireEvent.click(await screen.findByRole("button", { name: "Enviar código" }));
      const reenviar = await screen.findByRole("button", { name: "Reenviar código" });
      await fireEvent.click(reenviar);
      await waitFor(() => expect(reenviar).not.toBeDisabled());
      await fireEvent.click(reenviar);
      await waitFor(() => expect(reenviar).not.toBeDisabled());
      await fireEvent.click(reenviar);
      expect(await screen.findByText(/Muitas tentativas/)).toBeInTheDocument();
    });

    it("WhatsApp: canal indisponível (409)", async () => {
      server.use(
        http.post("/api/canais/confirmacao/:ref/whatsapp", () =>
          HttpResponse.json({ error: "Canal indisponível." }, { status: 409 }),
        ),
      );
      await inscreverComConfirmacao();
      await fireEvent.click(await screen.findByRole("button", { name: "Enviar código" }));
      expect(await screen.findByText(/WhatsApp não está disponível/)).toBeInTheDocument();
    });

    it("sem canais disponíveis: informa que a escola confirmará depois", async () => {
      setCanaisConfirmacaoMock([]);
      await inscreverComConfirmacao();
      expect(
        await screen.findByText(
          "Sua inscrição foi registrada; a escola vai confirmar seu telefone depois.",
        ),
      ).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);
    });

    it("telefone já confirmado (reinscrição) não pede confirmação", async () => {
      await inscreverComConfirmacao({ telefone: TELEFONE_CONFIRMADO });
      expect(
        await screen.findByRole("heading", { name: "Telefone já confirmado" }),
      ).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);
    });

    it("polling: detecta a confirmação feita no Telegram e para", async () => {
      await inscreverComConfirmacao();
      await screen.findByRole("heading", { name: "Confirme seu telefone" });
      expect(vi.getTimerCount()).toBe(1);

      // primeira consulta: ainda pendente
      await vi.advanceTimersByTimeAsync(POLL_INTERVALO_MS);
      await new Promise((r) => setTimeout(r, 20));
      expect(screen.getByRole("heading", { name: "Confirme seu telefone" })).toBeInTheDocument();

      confirmarRefMock(ultimaRefConfirmacao(), "telegram");
      await vi.advanceTimersByTimeAsync(POLL_INTERVALO_MS);
      expect(
        await screen.findByRole("heading", { name: "Telefone confirmado!" }),
      ).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);
    });

    it("polling: ref expirada (404) mostra confirmação expirada", async () => {
      await inscreverComConfirmacao();
      await screen.findByRole("heading", { name: "Confirme seu telefone" });
      server.use(
        http.get("/api/canais/confirmacao/:ref", () =>
          HttpResponse.json({ error: "Confirmação não encontrada." }, { status: 404 }),
        ),
      );
      await vi.advanceTimersByTimeAsync(POLL_INTERVALO_MS);
      expect(await screen.findByTestId("confirmacao-expirada")).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);
    });

    it("polling: desiste após a duração máxima e permite verificar de novo", async () => {
      await inscreverComConfirmacao({ extra: { intervaloPolling: 1000, duracaoPolling: 3000 } });
      await screen.findByRole("heading", { name: "Confirme seu telefone" });
      for (let i = 0; i < 4; i += 1) {
        await vi.advanceTimersByTimeAsync(1000);
        await new Promise((r) => setTimeout(r, 10));
      }
      expect(await screen.findByTestId("confirmacao-esgotada")).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);

      await fireEvent.click(screen.getByRole("button", { name: "Verificar novamente" }));
      expect(vi.getTimerCount()).toBe(1);
    });

    it("para o polling ao desmontar a página", async () => {
      const view = await inscreverComConfirmacao();
      await screen.findByRole("heading", { name: "Confirme seu telefone" });
      expect(vi.getTimerCount()).toBe(1);
      view.unmount();
      expect(vi.getTimerCount()).toBe(0);
    });

    it("'Confirmar depois' encerra com a inscrição pendente", async () => {
      await inscreverComConfirmacao();
      await fireEvent.click(await screen.findByRole("button", { name: "Confirmar depois" }));
      expect(await screen.findByText(/registrada como pendente/)).toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);
    });

    it("regressão Fase 0: lista sem exigência mantém 'Inscrição confirmada!'", async () => {
      renderPage();
      await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
      await preencher();
      await fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));
      expect(
        await screen.findByRole("heading", { name: "Inscrição confirmada!" }),
      ).toBeInTheDocument();
      expect(screen.queryByTestId("confirmacao-passo")).not.toBeInTheDocument();
      expect(vi.getTimerCount()).toBe(0);
    });
  });
});
