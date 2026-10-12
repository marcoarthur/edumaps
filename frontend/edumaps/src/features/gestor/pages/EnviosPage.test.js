// src/features/gestor/pages/EnviosPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetCanaisMockState } from "../mocks/canaisHandlers.js";
import {
  resetEnviosMockState,
  setLimitesEnvioMock,
  avancarEnvioMock,
  getEnviosMock,
  getChamadasEnvioMock,
} from "../mocks/enviosHandlers.js";
import { localParaIsoUtc } from "../constants/envios.js";
import { server } from "../../../mocks/server.js";
import EnviosPage from "./EnviosPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const URL_ENVIO = "/api/gestor/:cod_inep/canais/envios/:id";

function irPara(query) {
  window.history.replaceState({}, "", `/gestor/envios${query}`);
}

// "YYYY-MM-DDTHH:mm" na hora local (valor de input datetime-local)
function localInput(date) {
  const p = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}T${p(date.getHours())}:${p(date.getMinutes())}`;
}

async function abrirRascunho1() {
  irPara("?id=1");
  render(EnviosPage);
  await screen.findByTestId("envio-editor");
}

describe("EnviosPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    resetEnviosMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
  });
  afterEach(() => {
    window.history.replaceState({}, "", "/");
    setApiToken(null);
    vi.useRealTimers();
  });

  describe("lista e limites", () => {
    it("mostra os limites e os envios com selo de estado", async () => {
      irPara("");
      render(EnviosPage);
      expect(await screen.findByText("Reunião de pais na sexta")).toBeInTheDocument();
      expect(screen.getByTestId("saldo-hoje")).toHaveTextContent("488");
      expect(screen.getAllByTestId("envio-row")).toHaveLength(4);
      expect(screen.getByLabelText("Estado: Pausado (cota do dia)")).toBeInTheDocument();
      expect(screen.getByLabelText("Estado: Enviando")).toBeInTheDocument();
      expect(screen.getByLabelText("Estado: Rascunho")).toBeInTheDocument();
      expect(screen.getByText(/1\/3 enviados · 2 pendente\(s\)/)).toBeInTheDocument();
      expect(screen.getByRole("link", { name: "Listas dinâmicas" })).toHaveAttribute("href", "/gestor/segmentos");
    });

    it("avisa suspensão e SMTP indisponível", async () => {
      setLimitesEnvioMock({
        smtp_disponivel: false,
        suspensao: { motivo: "volume anormal", suspenso_em: "2026-10-12T10:00:00Z" },
      });
      irPara("");
      render(EnviosPage);
      expect(await screen.findByTestId("aviso-suspensao")).toHaveTextContent("volume anormal");
      expect(screen.getByTestId("aviso-smtp")).toBeInTheDocument();
    });

    it("filtra por estado", async () => {
      irPara("");
      render(EnviosPage);
      await screen.findByText("Reunião de pais na sexta");
      await fireEvent.change(screen.getByLabelText("Filtrar envios por estado"), {
        target: { value: "concluido" },
      });
      await waitFor(() => expect(screen.getAllByTestId("envio-row")).toHaveLength(1));
      expect(screen.getByText("Convite: festa junina")).toBeInTheDocument();
    });

    it("sem sessão mostra o login", async () => {
      setApiToken(null);
      setSessaoToken(null);
      irPara("");
      render(EnviosPage);
      expect(await screen.findByText("Entre para enviar e-mails às suas listas.")).toBeInTheDocument();
    });
  });

  describe("editor", () => {
    it("abre com o alvo preenchido pela query (ação da ListasPage)", async () => {
      irPara("?novo=1&alvo_tipo=lista&alvo_id=4");
      render(EnviosPage);
      await screen.findByTestId("envio-editor");
      expect(screen.getByLabelText("Enviar para")).toHaveValue("lista:4");
      expect(screen.getByRole("heading", { name: "Novo envio" })).toBeInTheDocument();
    });

    it("valida campos antes de salvar", async () => {
      irPara("");
      render(EnviosPage);
      await fireEvent.click(await screen.findByRole("button", { name: "+ Novo envio" }));
      await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
      expect(screen.getByTestId("editor-erro")).toHaveTextContent("Escolha para quem enviar");
      await fireEvent.change(screen.getByLabelText("Enviar para"), { target: { value: "lista:4" } });
      await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
      expect(screen.getByTestId("editor-erro")).toHaveTextContent("Informe o assunto");
    });

    it("cria o rascunho, mostra a prévia markdown e a prévia final", async () => {
      irPara("?novo=1&alvo_tipo=lista&alvo_id=4");
      render(EnviosPage);
      await screen.findByTestId("envio-editor");
      await fireEvent.change(screen.getByLabelText("Motivo (operação)"), { target: { value: "convite" } });
      await fireEvent.input(screen.getByLabelText("Assunto"), { target: { value: "Festa" } });
      await fireEvent.input(screen.getByLabelText("Mensagem"), {
        target: { value: "Venha!\n\n- **sábado**\n- 10h" },
      });
      const previaCorpo = screen.getByTestId("corpo-previa");
      expect(within(previaCorpo).getByText("sábado").tagName).toBe("STRONG");
      expect(within(previaCorpo).getAllByRole("listitem")).toHaveLength(2);

      await fireEvent.click(screen.getByRole("button", { name: "Pré-visualizar" }));
      const final = await screen.findByTestId("previa-final");
      expect(final).toHaveTextContent("Motivo: Convite.");
      expect(final).toHaveTextContent("/privacidade/sair/EXEMPLO");
      expect(screen.getByTestId("previa-estimativa")).toHaveTextContent("3 destinatário(s)");
      const criado = getEnviosMock().find((e) => e.assunto === "Festa");
      expect(criado).toMatchObject({ status: "rascunho", operacao: "convite", alvo: { tipo: "lista", id: 4 } });
    });

    it("envia teste para o gestor", async () => {
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Enviar teste para mim" }));
      await waitFor(() =>
        expect(addToast).toHaveBeenCalledWith("Teste enviado para h***@e***.br.", "success"),
      );
    });

    it.each([
      [429, {}, /Limite de testes deste envio/],
      [502, { error: "SMTP falhou" }, /servidor de e-mail recusou/],
      [409, { motivo: "sem_email_gestor" }, /não tem e-mail cadastrado/],
      [409, { motivo: "smtp_indisponivel" }, /não está configurado agora/],
    ])("teste com erro %i mostra mensagem", async (status, corpo, msg) => {
      server.use(http.post(`${URL_ENVIO}/teste`, () => HttpResponse.json(corpo, { status })));
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Enviar teste para mim" }));
      expect(await screen.findByTestId("editor-erro")).toHaveTextContent(msg);
    });

    it("Enviar agora: confirma com a contagem e abre o detalhe", async () => {
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Enviar agora" }));
      const dlg = await screen.findByTestId("disparo-dialog");
      expect(dlg).toHaveTextContent("3 destinatário(s) vão receber");
      await fireEvent.click(within(dlg).getByRole("button", { name: "Enviar" }));
      expect(await screen.findByTestId("envio-detalhe")).toBeInTheDocument();
      expect(getEnviosMock().find((e) => e.id === 1).status).toBe("enviando");
      expect(addToast).toHaveBeenCalledWith("Envio iniciado.", "success");
      expect(await screen.findAllByTestId("destinatario-row")).toHaveLength(3);
    });

    it("Agendar converte a hora local para ISO UTC", async () => {
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Agendar…" }));
      const amanha = new Date(Date.now() + 86400000);
      amanha.setSeconds(0, 0);
      const valor = localInput(amanha);
      await fireEvent.input(screen.getByLabelText("Data e hora do envio"), { target: { value: valor } });
      await fireEvent.click(screen.getByRole("button", { name: "Agendar" }));
      const dlg = await screen.findByTestId("disparo-dialog");
      await fireEvent.click(within(dlg).getByRole("button", { name: "Agendar" }));
      await screen.findByTestId("envio-detalhe");
      const envio = getEnviosMock().find((e) => e.id === 1);
      expect(envio.status).toBe("agendado");
      expect(envio.agendado_para).toBe(localParaIsoUtc(valor));
      expect(envio.agendado_para).toMatch(/Z$/);
    });

    it("Agendar sem data pede a data", async () => {
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Agendar…" }));
      await fireEvent.click(screen.getByRole("button", { name: "Agendar" }));
      expect(screen.getByTestId("editor-erro")).toHaveTextContent("Escolha a data e a hora");
    });

    it.each([
      [{ motivo: "status" }, /não está mais em rascunho/],
      [{ motivo: "smtp_indisponivel" }, /não está configurado agora/],
      [{ motivo: "envio_desligado" }, /desligado pela administração/],
      [{ motivo: "escola_suspensa" }, /estão suspensos/],
      [{ motivo: "alvo_inexistente" }, /não existe mais/],
      [{ motivo: "sem_destinatarios" }, /Ninguém nesta lista tem e-mail/],
      [{ motivo: "acima_do_teto", teto: 2000 }, /máximo de 2000 destinatários/],
      [{ motivo: "cota_insuficiente", saldo: 7 }, /restam 7 e-mail\(s\)/],
    ])("disparo 409 %o mostra a mensagem em PT-BR", async (corpo, msg) => {
      server.use(
        http.post(`${URL_ENVIO}/disparar`, () =>
          HttpResponse.json({ error: "conflito", ...corpo }, { status: 409 }),
        ),
      );
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Enviar agora" }));
      const dlg = await screen.findByTestId("disparo-dialog");
      await fireEvent.click(within(dlg).getByRole("button", { name: "Enviar" }));
      expect(await within(dlg).findByRole("alert")).toHaveTextContent(msg);
    });

    it("sem destinatários de verdade (mock) → 409 sem_destinatarios", async () => {
      irPara("?novo=1&alvo_tipo=lista&alvo_id=1");
      render(EnviosPage);
      await screen.findByTestId("envio-editor");
      await fireEvent.input(screen.getByLabelText("Assunto"), { target: { value: "Oi" } });
      await fireEvent.input(screen.getByLabelText("Mensagem"), { target: { value: "Texto" } });
      await fireEvent.click(screen.getByRole("button", { name: "Enviar agora" }));
      const dlg = await screen.findByTestId("disparo-dialog");
      expect(dlg).toHaveTextContent("0 destinatário(s)");
      await fireEvent.click(within(dlg).getByRole("button", { name: "Enviar" }));
      expect(await within(dlg).findByRole("alert")).toHaveTextContent(/Ninguém nesta lista/);
    });

    it("bloqueia enviar quando a escola está suspensa", async () => {
      setLimitesEnvioMock({ suspensao: { motivo: null, suspenso_em: "2026-10-12T10:00:00Z" } });
      await abrirRascunho1();
      expect(screen.getByRole("button", { name: "Enviar agora" })).toBeDisabled();
      expect(screen.getByRole("button", { name: "Enviar teste para mim" })).toBeDisabled();
    });

    it("apaga o rascunho com confirmação", async () => {
      await abrirRascunho1();
      await fireEvent.click(screen.getByRole("button", { name: "Apagar rascunho" }));
      const dlg = await screen.findByTestId("apagar-envio-dialog");
      await fireEvent.click(within(dlg).getByRole("button", { name: "Apagar" }));
      await waitFor(() => expect(getEnviosMock().some((e) => e.id === 1)).toBe(false));
      expect(await screen.findAllByTestId("envio-row")).toHaveLength(3);
    });

    it("edita um rascunho existente pelo botão Editar", async () => {
      irPara("");
      render(EnviosPage);
      await fireEvent.click(await screen.findByRole("button", { name: "Editar envio Reunião de pais na sexta" }));
      await screen.findByTestId("envio-editor");
      expect(screen.getByLabelText("Mensagem").value).toContain("A reunião de pais");
      await fireEvent.input(screen.getByLabelText("Assunto"), { target: { value: "Reunião remarcada" } });
      await fireEvent.click(screen.getByRole("button", { name: "Salvar rascunho" }));
      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Rascunho salvo.", "success"));
      expect(getEnviosMock().find((e) => e.id === 1).assunto).toBe("Reunião remarcada");
    });
  });

  describe("detalhe", () => {
    it("mostra contadores e destinatários mascarados, com filtro", async () => {
      irPara("?id=3");
      render(EnviosPage);
      expect(await screen.findByTestId("contador-enviados")).toHaveTextContent("1");
      expect(screen.getByTestId("contador-falhas")).toHaveTextContent("1");
      expect(await screen.findAllByTestId("destinatario-row")).toHaveLength(2);
      expect(screen.getByText("550 caixa inexistente")).toBeInTheDocument();
      expect(screen.getByText("d***@e***.org")).toBeInTheDocument();
      expect(screen.queryByRole("button", { name: "Cancelar envio" })).not.toBeInTheDocument();

      await fireEvent.change(screen.getByLabelText("Filtrar destinatários por estado"), {
        target: { value: "falhou" },
      });
      await waitFor(() => expect(screen.getAllByTestId("destinatario-row")).toHaveLength(1));
    });

    it("cancela com confirmação", async () => {
      irPara("?id=4");
      render(EnviosPage);
      await screen.findByLabelText("Estado: Pausado (cota do dia)");
      await fireEvent.click(screen.getByRole("button", { name: "Cancelar envio" }));
      const dlg = await screen.findByTestId("cancelar-envio-dialog");
      await fireEvent.click(within(dlg).getByRole("button", { name: "Cancelar envio" }));
      expect(await screen.findByLabelText("Estado: Cancelado")).toBeInTheDocument();
      expect(getEnviosMock().find((e) => e.id === 4).status).toBe("cancelado");
    });

    describe("polling", () => {
      beforeEach(() => {
        vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      });

      it("recarrega a cada 5 s enquanto enviando e para ao concluir", async () => {
        irPara("?id=2");
        render(EnviosPage);
        await screen.findByTestId("ao-vivo");
        await waitFor(() => expect(screen.getByTestId("contador-enviados")).toHaveTextContent("1"));
        const antes = getChamadasEnvioMock(2);

        avancarEnvioMock(2, 1);
        await vi.advanceTimersByTimeAsync(5000);
        await waitFor(() => expect(screen.getByTestId("contador-enviados")).toHaveTextContent("2"));
        expect(getChamadasEnvioMock(2)).toBe(antes + 1);

        avancarEnvioMock(2, 1); // último pendente → concluido
        await vi.advanceTimersByTimeAsync(5000);
        expect(await screen.findByLabelText("Estado: Concluído")).toBeInTheDocument();
        expect(screen.queryByTestId("ao-vivo")).not.toBeInTheDocument();
        const final = getChamadasEnvioMock(2);

        await vi.advanceTimersByTimeAsync(15000);
        expect(getChamadasEnvioMock(2)).toBe(final);
      });

      it("não faz polling de envio concluído", async () => {
        irPara("?id=3");
        render(EnviosPage);
        await screen.findByLabelText("Estado: Concluído");
        const n = getChamadasEnvioMock(3);
        await vi.advanceTimersByTimeAsync(15000);
        expect(getChamadasEnvioMock(3)).toBe(n);
      });

      it("para o polling ao sair da página (desmontar)", async () => {
        irPara("?id=2");
        const { unmount } = render(EnviosPage);
        await screen.findByTestId("ao-vivo");
        const n = getChamadasEnvioMock(2);
        unmount();
        await vi.advanceTimersByTimeAsync(15000);
        expect(getChamadasEnvioMock(2)).toBe(n);
      });

      it("para o polling ao voltar para a lista", async () => {
        irPara("?id=2");
        render(EnviosPage);
        await screen.findByTestId("ao-vivo");
        const n = getChamadasEnvioMock(2);
        await fireEvent.click(screen.getByRole("button", { name: "← Voltar aos envios" }));
        await screen.findAllByTestId("envio-row");
        await vi.advanceTimersByTimeAsync(15000);
        expect(getChamadasEnvioMock(2)).toBe(n);
      });
    });
  });
});
