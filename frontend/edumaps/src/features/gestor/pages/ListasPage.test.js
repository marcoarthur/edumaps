// src/features/gestor/pages/ListasPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetCanaisMockState, getExclusoesMock } from "../mocks/canaisHandlers.js";
import { server } from "../../../mocks/server.js";
import { http, HttpResponse } from "msw";
import ListasPage from "./ListasPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("ListasPage", () => {
  beforeEach(() => {
    resetCanaisMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
    vi.spyOn(window, "confirm").mockReturnValue(true);
  });
  afterEach(() => {
    window.history.replaceState({}, "", "/");
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("lista as listas da escola com o status do QR", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");
    expect(screen.getByText("Professores")).toBeInTheDocument();
    expect(screen.getByText("QR ativo")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Contatos →" })).toBeInTheDocument();
  });

  it("cria uma nova lista nomeada", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");

    await fireEvent.click(screen.getByRole("button", { name: "+ Nova lista" }));
    await fireEvent.input(screen.getByPlaceholderText(/Nome da lista/), {
      target: { value: "Conselho de classe" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Criar lista" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Lista criada.", "success"));
    expect(await screen.findByText("Conselho de classe")).toBeInTheDocument();
  });

  it("mostra as inscrições (membros) de uma lista", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");

    await fireEvent.click(
      screen.getByRole("button", { name: "Ver inscrições de Responsáveis 6ºA" }),
    );

    expect(await screen.findByText("João Pai")).toBeInTheDocument();
    expect(screen.getByText("Marina Responsável")).toBeInTheDocument();
    expect(screen.getByTestId("membros-table")).toBeInTheDocument();
  });

  it("abre o QR ativo e revoga", async () => {
    render(ListasPage);
    await screen.findByText("Professores");

    await fireEvent.click(screen.getByRole("button", { name: "QR code de Professores" }));
    await screen.findByTestId("qr-modal");
    await waitFor(() =>
      expect(document.querySelector('[data-testid="qr-imagem"] svg')).toBeTruthy(),
    );

    await fireEvent.click(screen.getByRole("button", { name: "Revogar QR" }));
    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith(
        "QR revogado. O link deixa de funcionar.",
        "success",
      ),
    );
    await waitFor(() => expect(screen.queryByTestId("qr-modal")).not.toBeInTheDocument());
  });

  it("gera o QR de uma lista que ainda não tem", async () => {
    render(ListasPage);
    await screen.findByText("Responsáveis 6ºA");

    await fireEvent.click(
      screen.getByRole("button", { name: "QR code de Responsáveis 6ºA" }),
    );
    await screen.findByTestId("qr-modal");
    await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("QR code gerado.", "success"));
    await waitFor(() =>
      expect(document.querySelector('[data-testid="qr-imagem"] svg')).toBeTruthy(),
    );
  });

  describe("confirmação do telefone (#212)", () => {
    async function abrirDetalhe(nome) {
      render(ListasPage);
      await screen.findByText(nome);
      await fireEvent.click(screen.getByRole("button", { name: `Ver inscrições de ${nome}` }));
      await screen.findAllByTestId("membro-row");
    }

    it("cria lista exigindo confirmação", async () => {
      render(ListasPage);
      await screen.findByText("Responsáveis 6ºA");
      await fireEvent.click(screen.getByRole("button", { name: "+ Nova lista" }));
      await fireEvent.input(screen.getByPlaceholderText(/Nome da lista/), {
        target: { value: "Conselho confirmado" },
      });
      await fireEvent.click(screen.getByRole("checkbox", { name: /Exigir confirmação do telefone/ }));
      await fireEvent.click(screen.getByRole("button", { name: "Criar lista" }));

      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Lista criada.", "success"));
      const linha = (await screen.findByText("Conselho confirmado")).closest("[data-testid='lista-row']");
      expect(linha.textContent).toContain("exige confirmação");
    });

    it("mostra selo de estado e contadores numa lista que exige", async () => {
      await abrirDetalhe("Responsáveis 7ºB");
      const estados = screen.getAllByTestId("membro-estado").map((td) => td.textContent);
      expect(estados[0]).toContain("Confirmado (Telegram)");
      expect(estados[0]).toContain("em 11/10/2026");
      expect(estados[1]).toContain("Pendente");

      const contadores = screen.getByTestId("contadores-confirmacao");
      expect(contadores.textContent).toMatch(/1\s*confirmado\(s\)/);
      expect(contadores.textContent).toMatch(/1\s*pendente\(s\)/);
    });

    it("lista sem exigência mostra 'Não exigida' e esconde os contadores", async () => {
      await abrirDetalhe("Responsáveis 6ºA");
      const estados = screen.getAllByTestId("membro-estado").map((td) => td.textContent);
      expect(estados.every((t) => t.includes("Não exigida"))).toBe(true);
      expect(screen.queryByTestId("contadores-confirmacao")).not.toBeInTheDocument();
    });

    it("filtra os membros por estado", async () => {
      await abrirDetalhe("Responsáveis 7ºB");
      const filtro = screen.getByRole("combobox", { name: "Filtrar por estado" });

      await fireEvent.change(filtro, { target: { value: "pendente" } });
      expect(screen.getAllByTestId("membro-row")).toHaveLength(1);
      expect(screen.getByText("Paulo Pendente")).toBeInTheDocument();
      expect(screen.queryByText("Carla Confirmada")).not.toBeInTheDocument();

      await fireEvent.change(filtro, { target: { value: "confirmado" } });
      expect(screen.getByText("Carla Confirmada")).toBeInTheDocument();
      expect(screen.queryByText("Paulo Pendente")).not.toBeInTheDocument();

      await fireEvent.change(filtro, { target: { value: "nao_exigida" } });
      expect(screen.queryAllByTestId("membro-row")).toHaveLength(0);
      expect(screen.getByText("Nenhuma inscrição neste estado.")).toBeInTheDocument();

      await fireEvent.change(filtro, { target: { value: "todos" } });
      expect(screen.getAllByTestId("membro-row")).toHaveLength(2);
    });

    it("liga a exigência no detalhe (PATCH) e atualiza estado e contadores", async () => {
      await abrirDetalhe("Responsáveis 6ºA");
      const toggle = screen.getByRole("checkbox", { name: "Exigir confirmação do telefone" });
      expect(toggle).not.toBeChecked();

      await fireEvent.click(toggle);
      await waitFor(() =>
        expect(addToast).toHaveBeenCalledWith(
          "Confirmação do telefone passou a ser exigida.",
          "success",
        ),
      );
      await waitFor(() => {
        const estados = screen.getAllByTestId("membro-estado").map((td) => td.textContent);
        expect(estados.every((t) => t.includes("Pendente"))).toBe(true);
      });
      expect(screen.getByRole("checkbox", { name: "Exigir confirmação do telefone" })).toBeChecked();
      expect(screen.getByTestId("contadores-confirmacao").textContent).toMatch(/2\s*pendente\(s\)/);
    });

    it("avisa quando o PATCH falha", async () => {
      const { server } = await import("../../../mocks/server.js");
      const { http, HttpResponse } = await import("msw");
      await abrirDetalhe("Responsáveis 7ºB");
      server.use(
        http.patch("/api/gestor/:cod_inep/canais/listas/:id", () =>
          HttpResponse.json({ error: "Nada a alterar." }, { status: 400 }),
        ),
      );
      await fireEvent.click(screen.getByRole("checkbox", { name: "Exigir confirmação do telefone" }));
      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Nada a alterar.", "error"));
      expect(screen.getByRole("checkbox", { name: "Exigir confirmação do telefone" })).toBeChecked();
    });
  });
  describe("coleta e e-mail (#214)", () => {
    async function abrirDetalhe(nome) {
      render(ListasPage);
      await screen.findByText(nome);
      await fireEvent.click(screen.getByRole("button", { name: `Ver inscrições de ${nome}` }));
      await screen.findAllByTestId("membro-row");
    }

    it("cria lista escolhendo o que coletar", async () => {
      render(ListasPage);
      await screen.findByText("Responsáveis 6ºA");
      await fireEvent.click(screen.getByRole("button", { name: "+ Nova lista" }));
      await fireEvent.input(screen.getByPlaceholderText(/Nome da lista/), {
        target: { value: "Lista por e-mail" },
      });
      const coletar = screen.getByRole("combobox", { name: "Coletar" });
      expect([...coletar.options].map((o) => o.textContent)).toEqual([
        "Telefone",
        "E-mail",
        "Ambos",
        "Qualquer um",
      ]);
      await fireEvent.change(coletar, { target: { value: "email" } });
      expect(
        screen.getByRole("checkbox", { name: /Exigir confirmação do e-mail/ }),
      ).toBeInTheDocument();
      await fireEvent.click(screen.getByRole("button", { name: "Criar lista" }));

      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Lista criada.", "success"));
      const linha = (await screen.findByText("Lista por e-mail")).closest("[data-testid='lista-row']");
      expect(linha.textContent).toContain("e-mail");
    });

    it("lista 'ambos': coluna de e-mail, estado por contato e selo Parcial", async () => {
      await abrirDetalhe("Família 8ºC");
      expect(screen.getByRole("columnheader", { name: "E-mail" })).toBeInTheDocument();
      expect(screen.getByText("ana@example.org")).toBeInTheDocument();

      const estados = screen.getAllByTestId("membro-estado").map((td) => td.textContent);
      expect(estados[0]).toContain("Parcial");
      expect(estados[1]).toContain("Confirmado");
      expect(estados[2]).toContain("Pendente");

      const linhaAna = screen.getAllByTestId("membro-row")[0];
      expect(linhaAna.querySelector("[data-testid='membro-telefone-estado']").textContent).toContain(
        "confirmado",
      );
      expect(linhaAna.querySelector("[data-testid='membro-email-estado']").textContent).toContain(
        "pendente",
      );

      const contadores = screen.getByTestId("contadores-confirmacao");
      expect(contadores.textContent).toMatch(/1\s*confirmado\(s\)/);
      expect(contadores.textContent).toMatch(/2\s*pendente\(s\)/);
      expect(contadores.textContent).toMatch(/1\s*parcial\(is\)/);
    });

    it("filtra por estado parcial", async () => {
      await abrirDetalhe("Família 8ºC");
      await fireEvent.change(screen.getByRole("combobox", { name: "Filtrar por estado" }), {
        target: { value: "parcial" },
      });
      expect(screen.getAllByTestId("membro-row")).toHaveLength(1);
      expect(screen.getByText("Ana Parcial")).toBeInTheDocument();
    });

    it("lista só de telefone não mostra a coluna de e-mail", async () => {
      await abrirDetalhe("Responsáveis 7ºB");
      expect(screen.queryByRole("columnheader", { name: "E-mail" })).not.toBeInTheDocument();
      expect(screen.queryByTestId("membro-email-estado")).not.toBeInTheDocument();
    });

    it("lista só de e-mail esconde a coluna de telefone", async () => {
      await abrirDetalhe("Boletim por e-mail");
      expect(screen.queryByRole("columnheader", { name: "Telefone" })).not.toBeInTheDocument();
      expect(screen.getByText("eva@example.org")).toBeInTheDocument();
    });

    it("altera a coleta no detalhe (PATCH) e mostra o e-mail", async () => {
      await abrirDetalhe("Responsáveis 6ºA");
      const sel = screen.getByRole("combobox", { name: "Coletar nesta lista" });
      expect(sel.value).toBe("telefone");
      await fireEvent.change(sel, { target: { value: "ambos" } });
      await waitFor(() =>
        expect(addToast).toHaveBeenCalledWith("A lista passou a coletar: Ambos.", "success"),
      );
      expect(await screen.findByRole("columnheader", { name: "E-mail" })).toBeInTheDocument();
      expect(
        screen.getByRole("checkbox", { name: "Exigir confirmação dos contatos" }),
      ).toBeInTheDocument();
    });

    it("desfaz a coleta quando o PATCH falha", async () => {
      const { server } = await import("../../../mocks/server.js");
      const { http, HttpResponse } = await import("msw");
      await abrirDetalhe("Responsáveis 6ºA");
      server.use(
        http.patch("/api/gestor/:cod_inep/canais/listas/:id", () =>
          HttpResponse.json({ error: "coleta inválida." }, { status: 400 }),
        ),
      );
      const sel = screen.getByRole("combobox", { name: "Coletar nesta lista" });
      await fireEvent.change(sel, { target: { value: "email" } });
      await waitFor(() => expect(addToast).toHaveBeenCalledWith("coleta inválida.", "error"));
      expect(sel.value).toBe("telefone");
    });

    it("gera QR com limite; 400 do backend aparece no modal", async () => {
      const { server } = await import("../../../mocks/server.js");
      const { http, HttpResponse } = await import("msw");
      render(ListasPage);
      await screen.findByText("Responsáveis 6ºA");
      await fireEvent.click(screen.getByRole("button", { name: "QR code de Responsáveis 6ºA" }));
      await screen.findByTestId("qr-modal");

      server.use(
        http.post("/api/gestor/:cod_inep/canais/listas/:id/qrcode", () =>
          HttpResponse.json({ error: "expira_em deve ser uma data futura (ISO 8601)." }, { status: 400 }),
        ),
      );
      await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));
      expect(await screen.findByRole("alert")).toHaveTextContent("expira_em deve ser");
      expect(addToast).not.toHaveBeenCalledWith(expect.anything(), "error");

      server.resetHandlers();
      await fireEvent.input(screen.getByLabelText(/Limite de inscrições/), {
        target: { value: "3" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));
      await waitFor(() => expect(addToast).toHaveBeenCalledWith("QR code gerado.", "success"));
      expect(await screen.findByTestId("qr-usos")).toHaveTextContent("0 / 3");
    });
  });
  describe("exclusão: remover inscrito e histórico (#214, onda 2)", () => {
    async function abrir(nome) {
      render(ListasPage);
      await screen.findByText(nome);
      await fireEvent.click(screen.getByRole("button", { name: `Ver inscrições de ${nome}` }));
      await screen.findAllByTestId("membro-row");
    }

    it("mostra o histórico de exclusões da escola (origem, regra/motivo, contagens)", async () => {
      render(ListasPage);
      const linhas = await screen.findAllByTestId("exclusao-row");
      expect(linhas).toHaveLength(3);
      const origens = screen.getAllByTestId("exclusao-origem").map((td) => td.textContent.trim());
      expect(origens).toEqual(["Titular", "Retenção", "Gestor"]);
      const detalhes = screen.getAllByTestId("exclusao-detalhe").map((td) => td.textContent.trim());
      expect(detalhes[1]).toBe("Inscrições nunca confirmadas");
      expect(detalhes[2]).toBe("Pedido feito na secretaria");
      expect(screen.getAllByTestId("exclusao-inscricoes")[2]).toHaveTextContent("2");
    });

    it("histórico vazio mostra mensagem amigável", async () => {
      server.use(http.get("/api/gestor/:cod_inep/canais/exclusoes", () => HttpResponse.json([])));
      render(ListasPage);
      expect(await screen.findByText("Nenhuma exclusão registrada até agora.")).toBeInTheDocument();
    });

    it("remove um inscrito com motivo: DELETE, recarrega membros e histórico", async () => {
      let corpo = null;
      const ouvir = async ({ request }) => {
        if (request.method === "DELETE" && request.url.includes("/membros/")) {
          corpo = await request.clone().json();
        }
      };
      server.events.on("request:start", ouvir);
      await abrir("Responsáveis 6ºA");

      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito João Pai" }));
      const dialogo = screen.getByRole("alertdialog", { name: "Remover inscrito" });
      expect(dialogo).toHaveAccessibleDescription(/João Pai.*todas as listas desta escola/);
      const motivo = screen.getByRole("textbox", { name: /Motivo/ });
      expect(motivo).toHaveFocus();
      await fireEvent.input(motivo, { target: { value: "Pedido na secretaria" } });
      await fireEvent.click(screen.getByRole("button", { name: "Remover" }));

      await waitFor(() =>
        expect(addToast).toHaveBeenCalledWith(
          expect.stringMatching(/^Inscrito removido/),
          "success",
        ),
      );
      expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
      expect(corpo).toEqual({ motivo: "Pedido na secretaria" });
      await waitFor(() => expect(screen.queryByText("João Pai")).not.toBeInTheDocument());
      expect(screen.getAllByTestId("membro-row")).toHaveLength(1);
      await waitFor(() => expect(screen.getAllByTestId("exclusao-row")).toHaveLength(4));
      expect(screen.getAllByTestId("exclusao-detalhe")[0]).toHaveTextContent("Pedido na secretaria");
      expect(getExclusoesMock()[0]).toMatchObject({ origem: "gestor", motivo: "Pedido na secretaria" });
      server.events.removeListener("request:start", ouvir);
    });

    it("sem motivo, o DELETE vai sem corpo", async () => {
      let temCorpo = null;
      const ouvir = async ({ request }) => {
        if (request.method === "DELETE" && request.url.includes("/membros/")) {
          temCorpo = (await request.clone().text()).length > 0;
        }
      };
      server.events.on("request:start", ouvir);
      await abrir("Responsáveis 6ºA");
      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito Marina Responsável" }));
      await fireEvent.click(screen.getByRole("button", { name: "Remover" }));
      await waitFor(() => expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument());
      expect(temCorpo).toBe(false);
      expect(getExclusoesMock()[0]).toMatchObject({ origem: "gestor", motivo: null });
      server.events.removeListener("request:start", ouvir);
    });

    it("cancelar (botão ou Escape) não remove", async () => {
      await abrir("Responsáveis 6ºA");
      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito João Pai" }));
      await fireEvent.click(screen.getByRole("button", { name: "Cancelar" }));
      expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();

      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito João Pai" }));
      await fireEvent.keyDown(screen.getByRole("alertdialog"), { key: "Escape" });
      expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
      expect(screen.getByText("João Pai")).toBeInTheDocument();
      expect(getExclusoesMock()).toHaveLength(3);
    });

    it("404 avisa no diálogo e recarrega a lista", async () => {
      await abrir("Responsáveis 6ºA");
      server.use(
        http.delete("/api/gestor/:cod_inep/canais/listas/:id/membros/:membro_id", () =>
          HttpResponse.json({ error: "Inscrito não encontrado." }, { status: 404 }),
        ),
      );
      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito João Pai" }));
      await fireEvent.click(screen.getByRole("button", { name: "Remover" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/não existe mais/);
      expect(screen.getByRole("alertdialog")).toBeInTheDocument();
    });

    it("403 avisa no diálogo", async () => {
      await abrir("Responsáveis 6ºA");
      server.use(
        http.delete("/api/gestor/:cod_inep/canais/listas/:id/membros/:membro_id", () =>
          HttpResponse.json({ error: "Escola fora do seu acesso." }, { status: 403 }),
        ),
      );
      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito João Pai" }));
      await fireEvent.click(screen.getByRole("button", { name: "Remover" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/não tem acesso/);
    });

    it("remover tira o contato de todas as listas da escola (contador atualizado)", async () => {
      await abrir("Responsáveis 7ºB");
      await fireEvent.click(screen.getByRole("button", { name: "Remover inscrito Paulo Pendente" }));
      await fireEvent.click(screen.getByRole("button", { name: "Remover" }));
      await waitFor(() => expect(screen.queryByText("Paulo Pendente")).not.toBeInTheDocument());
      const linha = screen.getByText("Responsáveis 7ºB").closest("[data-testid='lista-row']");
      await waitFor(() => expect(linha.textContent).toContain("1 contato(s)"));
    });
  });

  describe("envio por e-mail (#216)", () => {
    it("cada lista tem a ação Enviar e-mail com o alvo na query", async () => {
      render(ListasPage);
      await screen.findByText("Família 8ºC");
      expect(screen.getByRole("link", { name: "Enviar e-mail para Família 8ºC" })).toHaveAttribute(
        "href",
        "/gestor/envios?novo=1&alvo_tipo=lista&alvo_id=4",
      );
    });

    it("tem links para Envios e Listas dinâmicas", async () => {
      render(ListasPage);
      await screen.findByText("Responsáveis 6ºA");
      expect(screen.getByRole("link", { name: "Envios" })).toHaveAttribute("href", "/gestor/envios");
      expect(screen.getByRole("link", { name: "Listas dinâmicas" })).toHaveAttribute(
        "href",
        "/gestor/segmentos",
      );
    });
  });

  describe("saídas e funil (#216, onda 2)", () => {
    beforeEach(() => {
      // só o Date é falso: o funil pede os últimos N dias até "hoje" (2026-10-12)
      vi.useFakeTimers({ toFake: ["Date"] });
      vi.setSystemTime(new Date("2026-10-12T15:00:00Z"));
    });
    afterEach(() => vi.useRealTimers());

    async function abrirFamilia() {
      render(ListasPage);
      await screen.findByText("Família 8ºC");
      await fireEvent.click(screen.getByRole("button", { name: "Ver inscrições de Família 8ºC" }));
      await screen.findByText("Clara Pendente");
    }

    it("mostra o contador de saídas por lista", async () => {
      render(ListasPage);
      await screen.findByText("Família 8ºC");
      const contadores = screen.getAllByTestId("lista-optouts");
      expect(contadores).toHaveLength(1);
      expect(contadores[0]).toHaveTextContent("1 saíram dos envios");
    });

    it("selo 'Saiu dos envios' só no membro com opt-out", async () => {
      await abrirFamilia();
      const selos = screen.getAllByTestId("membro-optout");
      expect(selos).toHaveLength(1);
      const linha = screen.getAllByTestId("membro-row").find((r) => r.textContent.includes("Clara Pendente"));
      expect(linha).toHaveTextContent("Saiu dos envios");
    });

    it("aba Funil: cartões com totais e taxas, barras por dia e troca de período", async () => {
      const pedidos = [];
      server.events.on("request:start", ({ request }) => {
        if (request.url.includes("/funil")) pedidos.push(new URL(request.url).search);
      });
      await abrirFamilia();
      await fireEvent.click(screen.getByRole("tab", { name: "Funil" }));
      expect(screen.getByRole("tab", { name: "Funil" })).toHaveAttribute("aria-selected", "true");

      expect(await screen.findByTestId("funil-acessos")).toHaveTextContent("20");
      expect(screen.getByTestId("funil-inscricoes")).toHaveTextContent("3");
      expect(screen.getByTestId("funil-confirmados")).toHaveTextContent("1");
      expect(screen.getByTestId("funil-optouts")).toHaveTextContent("1");
      expect(screen.getByTestId("funil-taxa-acesso-inscricao")).toHaveTextContent("15%");
      expect(screen.getByTestId("funil-taxa-inscricao-confirmacao")).toHaveTextContent("33,3%");
      expect(pedidos.at(-1)).toBe("?de=2026-09-13&ate=2026-10-12");
      expect(screen.getAllByTestId("funil-barra")).toHaveLength(30);
      expect(screen.getByTestId("funil-grafico")).toHaveAttribute(
        "aria-label",
        expect.stringContaining("Acessos ao QR por dia"),
      );
      expect(screen.getByTestId("funil-tabela").querySelectorAll("tbody tr")).toHaveLength(30);

      await fireEvent.click(screen.getByRole("button", { name: "7 dias" }));
      await waitFor(() => expect(screen.getAllByTestId("funil-barra")).toHaveLength(7));
      expect(pedidos.at(-1)).toBe("?de=2026-10-06&ate=2026-10-12");
      expect(screen.getByRole("button", { name: "7 dias" })).toHaveAttribute("aria-pressed", "true");

      await fireEvent.click(screen.getByRole("button", { name: "90 dias" }));
      await waitFor(() => expect(screen.getAllByTestId("funil-barra")).toHaveLength(90));
      expect(pedidos.at(-1)).toBe("?de=2026-07-15&ate=2026-10-12");
      server.events.removeAllListeners();
    });

    it("lista sem exigência de confirmação: confirmados e taxa '—'", async () => {
      render(ListasPage);
      await screen.findByText("Professores");
      await fireEvent.click(screen.getByRole("button", { name: "Ver inscrições de Professores" }));
      await fireEvent.click(await screen.findByRole("tab", { name: "Funil" }));

      expect(await screen.findByTestId("funil-confirmados")).toHaveTextContent("—");
      expect(screen.getByText("lista não exige confirmação")).toBeInTheDocument();
      expect(screen.getByTestId("funil-taxa-inscricao-confirmacao")).toHaveTextContent("—");
      expect(screen.getByTestId("funil-taxa-acesso-inscricao")).toHaveTextContent("0%");

      await fireEvent.click(screen.getByRole("button", { name: "Confirmados" }));
      expect(screen.getByTestId("funil-sem-metrica")).toBeInTheDocument();
      expect(screen.queryByTestId("funil-grafico")).not.toBeInTheDocument();
    });

    it("erro do funil aparece na aba", async () => {
      server.use(
        http.get("/api/gestor/:cod_inep/canais/listas/:id/funil", () =>
          HttpResponse.json({ error: "Período inválido." }, { status: 400 }),
        ),
      );
      await abrirFamilia();
      await fireEvent.click(screen.getByRole("tab", { name: "Funil" }));
      expect(await screen.findByRole("alert")).toHaveTextContent("Período inválido.");
    });
  });
});
