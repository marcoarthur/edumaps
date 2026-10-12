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
  setConsentimentoVigenteMock,
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
  EMAIL_CODIGO_MOCK,
  INSCRICAO_TOKEN_AMBOS,
  INSCRICAO_TOKEN_EMAIL,
  INSCRICAO_TOKEN_QUALQUER,
} from "@/features/gestor/mocks/canaisFixtures.js";
import InscricaoPublicaPage from "./InscricaoPublicaPage.svelte";
import {
  POLL_INTERVALO_MS,
  POLL_DURACAO_MS,
} from "../components/ConfirmacaoContatos.svelte";

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
  describe("e-mail e LGPD (#214)", () => {
    async function preencherContatos({ nome = "Nova Pessoa", telefone, email, aceitar = true } = {}) {
      await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
        target: { value: nome },
      });
      if (telefone !== undefined) {
        await fireEvent.input(screen.getByPlaceholderText("(00) 00000-0000"), {
          target: { value: telefone },
        });
      }
      if (email !== undefined) {
        await fireEvent.input(screen.getByPlaceholderText("voce@exemplo.com"), {
          target: { value: email },
        });
      }
      if (aceitar) await fireEvent.click(screen.getByRole("checkbox"));
    }

    const enviar = () => fireEvent.click(screen.getByRole("button", { name: "Inscrever-me" }));

    it("lista só de telefone: sem campo de e-mail (regressão)", async () => {
      renderPage();
      await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
      expect(screen.queryByPlaceholderText("voce@exemplo.com")).not.toBeInTheDocument();
    });

    it("lista só de e-mail: campo e-mail com tipo, autocomplete e teclado certos", async () => {
      renderPage(INSCRICAO_TOKEN_EMAIL);
      await screen.findByRole("heading", { name: "Boletim por e-mail" });
      expect(screen.queryByPlaceholderText("(00) 00000-0000")).not.toBeInTheDocument();
      const campo = screen.getByPlaceholderText("voce@exemplo.com");
      expect(campo).toHaveAttribute("type", "email");
      expect(campo).toHaveAttribute("autocomplete", "email");
      expect(campo).toHaveAttribute("inputmode", "email");
      expect(screen.getByText("E-mail *")).toBeInTheDocument();

      await preencherContatos({ email: "invalido" });
      await enviar();
      expect(await screen.findByText("Informe um e-mail válido.")).toBeInTheDocument();
    });

    it("'qualquer um': exige pelo menos um contato e aceita só o e-mail", async () => {
      renderPage(INSCRICAO_TOKEN_QUALQUER);
      await screen.findByRole("heading", { name: "Comunidade escolar" });
      expect(screen.getByTestId("dica-um-contato")).toBeInTheDocument();
      expect(screen.getByText("Telefone")).toBeInTheDocument(); // sem asterisco

      await preencherContatos({});
      await enviar();
      expect(await screen.findByText("Informe telefone ou e-mail.")).toBeInTheDocument();

      await fireEvent.input(screen.getByPlaceholderText("voce@exemplo.com"), {
        target: { value: "nova@example.org" },
      });
      await enviar();
      expect(await screen.findByTestId("inscricao-sucesso")).toBeInTheDocument();
    });

    it("mostra o 400 do backend (obrigatório ausente)", async () => {
      server.use(
        http.post("/api/canais/inscricao/:token", () =>
          HttpResponse.json({ error: "Informe um e-mail válido." }, { status: 400 }),
        ),
      );
      renderPage(INSCRICAO_TOKEN_AMBOS);
      await screen.findByRole("heading", { name: "Família 8ºC" });
      await preencherContatos({ telefone: "+55 11 94444-1111", email: "a@example.org" });
      await enviar();
      expect(await screen.findByRole("alert")).toHaveTextContent("Informe um e-mail válido.");
    });

    it("exibe o termo vigente com a versão, expansível, sem HTML cru, e envia a versão", async () => {
      let corpo = null;
      server.use(
        http.post("/api/canais/inscricao/:token", async ({ request }) => {
          corpo = await request.json();
          return HttpResponse.json({ ok: 1 }, { status: 201 });
        }),
      );
      renderPage();
      await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
      expect(screen.getByTestId("termo-versao")).toHaveTextContent("versão 1.0");
      const termo = screen.getByTestId("termo-consentimento");
      expect(termo.open).toBe(false);
      await fireEvent.click(screen.getByText(/Ler o termo de consentimento/));
      const texto = screen.getByTestId("termo-texto");
      expect(texto.querySelectorAll("li")).toHaveLength(2);
      expect(texto.querySelector("strong")).toHaveTextContent("escola");
      expect(screen.getByRole("link", { name: "política de privacidade" })).toHaveAttribute(
        "href",
        "/privacidade",
      );

      await preencher();
      await enviar();
      await screen.findByTestId("inscricao-sucesso");
      expect(corpo).toMatchObject({ consentimento: true, consentimento_versao: "1.0" });
    });

    it("renderiza HTML do termo como texto (sem injeção)", async () => {
      server.use(
        http.get("/api/canais/inscricao/:token", () =>
          HttpResponse.json({
            lista_nome: "Lista X",
            escola_nome: "Escola",
            campos: ["nome", "telefone"],
            obrigatorios: ["nome", "telefone"],
            consentimento: { versao: "9", texto: "<img src=x onerror=alert(1)> **ok**" },
          }),
        ),
      );
      renderPage();
      await screen.findByRole("heading", { name: "Lista X" });
      const texto = screen.getByTestId("termo-texto");
      expect(texto.querySelector("img")).toBeNull();
      expect(texto.textContent).toContain("<img src=x onerror=alert(1)>");
    });

    it("409: mostra o texto novo e pede novo aceite", async () => {
      renderPage();
      await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
      setConsentimentoVigenteMock({ versao: "2.0", texto: "Texto **revisado**." });
      await preencher();
      await enviar();

      expect(await screen.findByTestId("aviso-consentimento")).toHaveTextContent("versão 2.0");
      expect(screen.getByRole("checkbox")).not.toBeChecked();
      expect(screen.getByTestId("termo-versao")).toHaveTextContent("versão 2.0");
      expect(screen.getByTestId("termo-consentimento").open).toBe(true);
      expect(screen.getByTestId("termo-texto")).toHaveTextContent("Texto revisado.");

      await fireEvent.click(screen.getByRole("checkbox"));
      await enviar();
      expect(await screen.findByTestId("inscricao-sucesso")).toBeInTheDocument();
    });

    it("sucesso mostra o link 'Remover meus dados' com orientação", async () => {
      renderPage();
      await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
      await preencher();
      await enviar();
      await screen.findByTestId("inscricao-sucesso");
      const link = screen.getByRole("link", { name: "Remover meus dados" });
      expect(link.getAttribute("href")).toMatch(/\/privacidade\/exclusao\/[0-9a-f]{32}$/);
      expect(screen.getByText(/Guarde este link/)).toBeInTheDocument();
    });

    it("sem exclusao_url não mostra o link", async () => {
      server.use(
        http.post("/api/canais/inscricao/:token", () =>
          HttpResponse.json({ ok: 1 }, { status: 201 }),
        ),
      );
      renderPage();
      await screen.findByRole("heading", { name: "Responsáveis 6ºA" });
      await preencher();
      await enviar();
      await screen.findByTestId("inscricao-sucesso");
      expect(screen.queryByTestId("link-exclusao")).not.toBeInTheDocument();
    });

    describe("confirmação por contato", () => {
      beforeEach(() => {
        vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      });
      afterEach(() => {
        vi.useRealTimers();
      });

      async function inscreverAmbos() {
        const view = renderPage(INSCRICAO_TOKEN_AMBOS);
        await screen.findByRole("heading", { name: "Família 8ºC" });
        await preencherContatos({ telefone: "+55 11 94444-2222", email: "nova@example.org" });
        await enviar();
        await screen.findByRole("heading", { name: "Confirme seus contatos" });
        return view;
      }

      it("ambos: telefone pelo Telegram (parcial) e depois e-mail → confirmado", async () => {
        await inscreverAmbos();
        expect(screen.getByRole("link", { name: "Confirmar pelo Telegram" })).toBeInTheDocument();
        expect(screen.getByText("Receber código por e-mail")).toBeInTheDocument();
        expect(screen.getByTestId("contato-telefone")).toHaveTextContent("pendente");

        confirmarRefMock(ultimaRefConfirmacao(), "telegram");
        await vi.advanceTimersByTimeAsync(POLL_INTERVALO_MS);
        await waitFor(() =>
          expect(screen.getByTestId("contato-telefone")).toHaveTextContent("confirmado"),
        );
        // parcial: o passo segue aberto para o e-mail, o polling continua
        expect(screen.getByRole("heading", { name: "Confirme seus contatos" })).toBeInTheDocument();
        expect(screen.queryByRole("link", { name: "Confirmar pelo Telegram" })).not.toBeInTheDocument();
        expect(screen.getByTestId("contato-email")).toHaveTextContent("pendente");
        expect(vi.getTimerCount()).toBe(1);

        await fireEvent.click(screen.getByRole("button", { name: "Enviar código por e-mail" }));
        const campo = await screen.findByLabelText("Código do e-mail (6 dígitos)");
        await fireEvent.input(campo, { target: { value: "000000" } });
        await fireEvent.click(screen.getByRole("button", { name: "Verificar código do e-mail" }));
        expect(await screen.findByText(/Código inválido/)).toBeInTheDocument();

        await fireEvent.input(campo, { target: { value: EMAIL_CODIGO_MOCK } });
        await fireEvent.click(screen.getByRole("button", { name: "Verificar código do e-mail" }));
        expect(
          await screen.findByRole("heading", { name: "Contatos confirmados!" }),
        ).toBeInTheDocument();
        expect(vi.getTimerCount()).toBe(0);
        expect(screen.getByRole("link", { name: "Remover meus dados" })).toBeInTheDocument();
      });

      it("ambos: e-mail primeiro deixa o telefone pendente (parcial)", async () => {
        await inscreverAmbos();
        await fireEvent.click(screen.getByRole("button", { name: "Enviar código por e-mail" }));
        const campo = await screen.findByLabelText("Código do e-mail (6 dígitos)");
        await fireEvent.input(campo, { target: { value: EMAIL_CODIGO_MOCK } });
        await fireEvent.click(screen.getByRole("button", { name: "Verificar código do e-mail" }));
        await waitFor(() =>
          expect(screen.getByTestId("contato-email")).toHaveTextContent("confirmado"),
        );
        expect(screen.queryByTestId("confirmacao-email")).not.toBeInTheDocument();
        expect(screen.getByTestId("confirmacao-whatsapp")).toBeInTheDocument();

        await fireEvent.click(screen.getByRole("button", { name: "Enviar código" }));
        await fireEvent.input(await screen.findByPlaceholderText("000000"), {
          target: { value: WHATSAPP_CODIGO_MOCK },
        });
        await fireEvent.click(screen.getByRole("button", { name: "Verificar" }));
        expect(
          await screen.findByRole("heading", { name: "Contatos confirmados!" }),
        ).toBeInTheDocument();
      });

      it("e-mail: falha de envio (502) mostra mensagem própria", async () => {
        server.use(
          http.post("/api/canais/confirmacao/:ref/email", () =>
            HttpResponse.json({ error: "SMTP falhou." }, { status: 502 }),
          ),
        );
        await inscreverAmbos();
        await fireEvent.click(screen.getByRole("button", { name: "Enviar código por e-mail" }));
        expect(await screen.findByText(/Não conseguimos enviar o e-mail/)).toBeInTheDocument();
      });

      it("e-mail: limite (429) e indisponível (409)", async () => {
        await inscreverAmbos();
        await fireEvent.click(screen.getByRole("button", { name: "Enviar código por e-mail" }));
        const reenviar = await screen.findByRole("button", { name: "Reenviar código por e-mail" });
        await fireEvent.click(reenviar);
        await waitFor(() => expect(reenviar).not.toBeDisabled());
        await fireEvent.click(reenviar);
        await waitFor(() => expect(reenviar).not.toBeDisabled());
        await fireEvent.click(reenviar);
        expect(await screen.findByText(/Muitas tentativas/)).toBeInTheDocument();

        server.use(
          http.post("/api/canais/confirmacao/:ref/email", () =>
            HttpResponse.json({ error: "x" }, { status: 409 }),
          ),
        );
        await fireEvent.click(reenviar);
        expect(await screen.findByText(/por e-mail não está disponível/)).toBeInTheDocument();
      });

      it("só e-mail: sem Telegram/WhatsApp, título do e-mail", async () => {
        renderPage(INSCRICAO_TOKEN_EMAIL);
        await screen.findByRole("heading", { name: "Boletim por e-mail" });
        await preencherContatos({ email: "leitor@example.org" });
        await enviar();
        await screen.findByRole("heading", { name: "Confirme seu e-mail" });
        expect(screen.queryByRole("link", { name: "Confirmar pelo Telegram" })).not.toBeInTheDocument();
        expect(screen.queryByTestId("confirmacao-whatsapp")).not.toBeInTheDocument();
        expect(screen.getByTestId("confirmacao-email")).toBeInTheDocument();
      });

      it("'Confirmar depois' mostra o link de exclusão", async () => {
        await inscreverAmbos();
        await fireEvent.click(screen.getByRole("button", { name: "Confirmar depois" }));
        expect(await screen.findByText(/Seus contatos ainda precisam/)).toBeInTheDocument();
        expect(screen.getByRole("link", { name: "Remover meus dados" })).toBeInTheDocument();
      });

      it("resposta sem `contatos` (formato #212) deduz pelos canais", async () => {
        server.use(
          http.post("/api/canais/inscricao/:token", () =>
            HttpResponse.json(
              {
                ok: 1,
                confirmacao: {
                  ref: "a".repeat(32),
                  estado: "pendente",
                  canais: [{ canal: "whatsapp" }, { canal: "email" }],
                },
              },
              { status: 201 },
            ),
          ),
        );
        renderPage(INSCRICAO_TOKEN_AMBOS);
        await screen.findByRole("heading", { name: "Família 8ºC" });
        await preencherContatos({ telefone: "+55 11 94444-3333", email: "z@example.org" });
        await enviar();
        expect(
          await screen.findByRole("heading", { name: "Confirme seus contatos" }),
        ).toBeInTheDocument();
        expect(screen.getByTestId("confirmacao-whatsapp")).toBeInTheDocument();
        expect(screen.getByTestId("confirmacao-email")).toBeInTheDocument();
      });
    });
  });
});
