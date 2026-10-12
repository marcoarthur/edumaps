// src/features/gestor/pages/ListasPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetCanaisMockState } from "../mocks/canaisHandlers.js";
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
});
