// src/features/gestor/pages/RelatoriosPage.test.js
// Assistente de Relatório (#219): recorte, cascata, temas, opções, geração e polling.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import {
  resetRelatoriosMockState,
  configurarRelatoriosMock,
  getPedidosRelatorioMock,
  getConsultasJobMock,
  getSalvosMock,
} from "../mocks/relatoriosHandlers.js";
import { server } from "../../../mocks/server.js";
import RelatoriosPage from "./RelatoriosPage.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

const temasVisiveis = () =>
  within(screen.getByTestId("temas"))
    .getAllByRole("radio")
    .map((r) => r.value);

// Espera uma condição fora do DOM com setTimeout real: o waitFor da
// testing-library checa por setInterval (falso aqui) e o vi.waitFor avança os
// timers falsos, o que estragaria a medição do intervalo do polling.
async function ate(cond, limite = 2000) {
  const inicio = Date.now();
  while (!cond()) {
    if (Date.now() - inicio > limite) throw new Error("condição não atingida");
    await new Promise((r) => setTimeout(r, 5));
  }
}

async function abrir() {
  const r = render(RelatoriosPage);
  await screen.findByTestId("temas");
  return r;
}

async function gerarEPollar(vezes = 3) {
  await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
  await ate(() => getPedidosRelatorioMock().length === 1);
  if (vezes > 0) await ate(() => vi.getTimerCount() > 0); // polling agendado
  for (let i = 0; i < vezes; i += 1) {
    await vi.advanceTimersByTimeAsync(1500);
  }
}

describe("RelatoriosPage", () => {
  beforeEach(() => {
    resetRelatoriosMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    vi.useRealTimers();
    window.history.replaceState({}, "", "/");
  });

  it("sem sessão mostra o login", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(RelatoriosPage);
    expect(await screen.findByText("Entre para gerar relatórios.")).toBeInTheDocument();
  });

  it("401 no recorte-padrão volta ao login", async () => {
    server.use(
      http.get("/api/gestor/:cod_inep/relatorios/recorte-padrao", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    render(RelatoriosPage);
    expect(await screen.findByText("Entre para gerar relatórios.")).toBeInTheDocument();
  });

  it("carrega o recorte-padrão (município da escola) e os temas do nível", async () => {
    await abrir();
    expect(screen.getByRole("heading", { name: "Relatórios" })).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "Município" })).toBeChecked();
    expect(screen.getByLabelText(/Da minha escola: Porto Velho/)).toBeChecked();
    expect(temasVisiveis()).toEqual([
      "ideb_territorio",
      "redes_territorio",
      "docentes_territorio",
      "ideb_escolas",
    ]);
    const primeiro = screen.getByRole("radio", { name: /IDEB do território/ });
    expect(primeiro).toBeChecked();
    expect(primeiro).toHaveAccessibleDescription("IDEB do recorte comparado ao nível de cima.");
    // opções do tema: etapa (com default) e rede (opcional)
    expect(screen.getByLabelText("Etapa")).toHaveValue("fundamental_i");
    expect(screen.getByLabelText("Rede")).toHaveValue("");
    expect(screen.getByTestId("geotag-resumo")).toHaveTextContent("Porto Velho");
  });

  it("troca de nível recarrega os temas e as opções", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("radio", { name: "Região" }));
    await waitFor(() => expect(temasVisiveis()).toContain("tendencia_ideb"));
    expect(temasVisiveis()).toContain("gestores_territorio");
    expect(screen.getByLabelText(/Da minha escola: Norte/)).toBeChecked();

    await fireEvent.click(screen.getByRole("radio", { name: /Redes de ensino/ }));
    expect(screen.queryByLabelText("Etapa")).toBeNull();
    expect(screen.getByLabelText("Rede")).toBeInTheDocument();

    await fireEvent.click(screen.getByRole("radio", { name: "Minha escola" }));
    await waitFor(() =>
      expect(temasVisiveis()).toEqual(["minha_escola", "historico_escola", "escolas_parecidas"]),
    );
    expect(screen.getByTestId("recorte-atual")).toHaveTextContent("INEP 11000040");
    expect(screen.queryByTestId("opcoes-tema")).toBeNull();
    expect(screen.queryByLabelText("Escolher outro")).toBeNull();
  });

  it("temas profundos levam o selo \"Análise aprofundada\"; descritivos não", async () => {
    await abrir();
    const itemDe = (id) =>
      screen.getByTestId("temas").querySelector(`input[value="${id}"]`).closest("li");
    expect(within(itemDe("ideb_escolas")).getByTestId("selo-profunda")).toHaveTextContent(
      "Análise aprofundada",
    );
    expect(within(itemDe("ideb_territorio")).queryByTestId("selo-profunda")).toBeNull();
    expect(within(screen.getByTestId("temas")).getAllByTestId("selo-profunda")).toHaveLength(1);

    await fireEvent.click(screen.getByRole("radio", { name: "Estado" }));
    await waitFor(() => expect(temasVisiveis()).toContain("infraestrutura_ideb"));
    expect(within(itemDe("infraestrutura_ideb")).getByTestId("selo-profunda")).toBeInTheDocument();
  });

  it("gera com o recorte-padrão e as opções escolhidas", async () => {
    vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    await abrir();
    await fireEvent.change(screen.getByLabelText("Etapa"), { target: { value: "ensino_medio" } });
    await fireEvent.change(screen.getByLabelText("Rede"), { target: { value: "Municipal" } });
    await gerarEPollar();
    expect(getPedidosRelatorioMock()[0]).toEqual({
      geotag: { nivel: "municipio", codigo: "1100205" },
      tema: "ideb_territorio",
      opcoes: { etapa: "ensino_medio", rede: "Municipal" },
    });
    expect(await screen.findByTestId("relatorio-view")).toBeInTheDocument();
  });

  it("nível escola envia o INEP do gestor e sem opções", async () => {
    vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    await abrir();
    await fireEvent.click(screen.getByRole("radio", { name: "Minha escola" }));
    await waitFor(() =>
      expect(temasVisiveis()).toEqual(["minha_escola", "historico_escola", "escolas_parecidas"]),
    );
    await gerarEPollar(0);
    expect(getPedidosRelatorioMock()[0]).toEqual({
      geotag: { nivel: "escola", codigo: "11000040" },
      tema: "minha_escola",
    });
  });

  it("opção sem padrão no catálogo (escolas_parecidas) vem em \"Todas as etapas\" e não vai no pedido", async () => {
    vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    await abrir();
    await fireEvent.click(screen.getByRole("radio", { name: "Minha escola" }));
    await waitFor(() => expect(temasVisiveis()).toContain("escolas_parecidas"));
    await fireEvent.click(screen.getByRole("radio", { name: /Escolas parecidas/ }));
    const etapa = await screen.findByLabelText("Etapa");
    expect(etapa.value).toBe("");
    expect(within(etapa).getByRole("option", { name: "Todas as etapas" })).toBeInTheDocument();
    await gerarEPollar(0);
    expect(getPedidosRelatorioMock()[0]).toEqual({
      geotag: { nivel: "escola", codigo: "11000040" },
      tema: "escolas_parecidas",
    });
  });

  describe("cascata (outro recorte)", () => {
    it("município: região → UF → município vira código de 7 dígitos", async () => {
      await abrir();
      await fireEvent.click(screen.getByLabelText("Escolher outro"));
      const cascata = await screen.findByTestId("cascata");
      const regiao = within(cascata).getByLabelText("Região");
      await waitFor(() => expect(within(regiao).getAllByRole("option")).toHaveLength(6));
      expect(screen.getByRole("button", { name: "Gerar relatório" })).toBeDisabled();
      expect(within(cascata).getByLabelText("Estado (UF)")).toBeDisabled();

      await fireEvent.change(regiao, { target: { value: "1" } });
      const uf = within(cascata).getByLabelText("Estado (UF)");
      await waitFor(() => expect(uf).not.toBeDisabled());
      await waitFor(() => expect(within(uf).getAllByRole("option").length).toBeGreaterThan(1));
      await fireEvent.change(uf, { target: { value: "12" } });

      const mun = within(cascata).getByLabelText("Município");
      await waitFor(() => expect(within(mun).getAllByRole("option").length).toBeGreaterThan(1));
      await fireEvent.change(mun, { target: { value: "1200401" } });
      expect(screen.getByTestId("geotag-resumo")).toHaveTextContent("Rio Branco");

      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0].geotag).toEqual({ nivel: "municipio", codigo: "1200401" });
    });

    it("UF vira a sigla; região vira N|NE|SE|S|CO", async () => {
      await abrir();
      await fireEvent.click(screen.getByRole("radio", { name: "Estado" }));
      await fireEvent.click(screen.getByLabelText("Escolher outro"));
      const cascata = await screen.findByTestId("cascata");
      expect(within(cascata).queryByLabelText("Município")).toBeNull();
      const regiao = within(cascata).getByLabelText("Região");
      await waitFor(() => expect(within(regiao).getAllByRole("option")).toHaveLength(6));
      await fireEvent.change(regiao, { target: { value: "1" } });
      const uf = within(cascata).getByLabelText("Estado (UF)");
      await waitFor(() => expect(within(uf).getAllByRole("option").length).toBeGreaterThan(1));
      await fireEvent.change(uf, { target: { value: "12" } });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0].geotag).toEqual({ nivel: "uf", codigo: "AC" });

      // região: troca de nível mantém a região escolhida
      await fireEvent.click(screen.getByRole("radio", { name: "Região" }));
      await waitFor(() => expect(temasVisiveis()).toContain("tendencia_ideb"));
      await fireEvent.change(within(screen.getByTestId("cascata")).getByLabelText("Região"), {
        target: { value: "2" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 2);
      expect(getPedidosRelatorioMock()[1].geotag).toEqual({ nivel: "regiao", codigo: "NE" });
    });
  });

  it("infraestrutura_ideb: associações, aviso e detalhes técnicos recolhidos", async () => {
    vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    await abrir();
    await fireEvent.click(screen.getByRole("radio", { name: "Estado" }));
    await waitFor(() => expect(temasVisiveis()).toContain("infraestrutura_ideb"));
    await fireEvent.click(screen.getByRole("radio", { name: /Infraestrutura e IDEB/ }));
    await gerarEPollar();
    expect(getPedidosRelatorioMock()[0]).toMatchObject({
      geotag: { nivel: "uf", codigo: "RO" },
      tema: "infraestrutura_ideb",
    });
    await screen.findByTestId("relatorio-view");
    expect(screen.getByTestId("secao-associacoes")).toBeInTheDocument();
    expect(screen.getByTestId("aviso-associacao")).toHaveTextContent("Associação não é causa");
    const recolhidas = screen.getAllByTestId("tabela-recolhida");
    expect(recolhidas).toHaveLength(2);
    recolhidas.forEach((d) => expect(d.open).toBe(false));
  });

  it("ideb_escolas: a escola do gestor sai destacada", async () => {
    vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    await abrir();
    await fireEvent.click(screen.getByRole("radio", { name: /IDEB escola a escola/ }));
    await gerarEPollar();
    await screen.findByTestId("relatorio-view");
    const destaque = screen.getByRole("rowheader", { name: /\(sua escola\)/ });
    expect(destaque).toHaveTextContent("EEEF Professora Maria de Lourdes");
    expect(destaque.closest("tr")).toHaveAttribute("data-destaque", "true");
  });

  describe("geração e polling (1,5 s)", () => {
    beforeEach(() => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
    });

    it("consulta o job a cada 1,5 s até finished e para", async () => {
      await abrir();
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(await screen.findByTestId("job-estado")).toHaveTextContent("Na fila");
      await ate(() => vi.getTimerCount() > 0);
      expect(screen.getByRole("button", { name: "Gerar relatório" })).toBeDisabled();

      await vi.advanceTimersByTimeAsync(1499);
      expect(getConsultasJobMock(900)).toBe(0);
      await vi.advanceTimersByTimeAsync(1);
      await ate(() => getConsultasJobMock(900) === 1);
      await vi.advanceTimersByTimeAsync(1500);
      await waitFor(() => expect(screen.getByTestId("job-estado")).toHaveTextContent("Gerando"));
      await vi.advanceTimersByTimeAsync(1500);

      const view = await screen.findByTestId("relatorio-view");
      expect(within(view).getByRole("heading", { name: /Porto Velho \(RO\)/ })).toBeInTheDocument();
      expect(screen.queryByTestId("job-estado")).toBeNull();
      expect(screen.queryByTestId("selo-cache")).toBeNull();
      expect(screen.getByTestId("secao-grafico")).toBeInTheDocument();

      const n = getConsultasJobMock(900);
      await vi.advanceTimersByTimeAsync(6000);
      expect(getConsultasJobMock(900)).toBe(n);
    });

    it("failed mostra a mensagem do job", async () => {
      configurarRelatoriosMock({ falha: "Tema inválido para o recorte.", consultasAteFim: 1 });
      await abrir();
      await gerarEPollar(1);
      expect(await screen.findByTestId("erro-gerar")).toHaveTextContent("Tema inválido para o recorte.");
      expect(screen.queryByTestId("relatorio-view")).toBeNull();
      const n = getConsultasJobMock(900);
      await vi.advanceTimersByTimeAsync(4500);
      expect(getConsultasJobMock(900)).toBe(n);
    });

    it("400 no POST mostra a mensagem", async () => {
      server.use(
        http.post("/api/gestor/:cod_inep/relatorios", () =>
          HttpResponse.json({ error: "Tema indisponível para este nível." }, { status: 400 }),
        ),
      );
      await abrir();
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      expect(await screen.findByTestId("erro-gerar")).toHaveTextContent(
        "Tema indisponível para este nível.",
      );
      expect(screen.queryByTestId("job-estado")).toBeNull();
    });

    it("401 durante o polling volta ao login", async () => {
      await abrir();
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      server.use(
        http.get("/api/gestor/:cod_inep/relatorios/jobs/:id", () =>
          HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
        ),
      );
      await ate(() => vi.getTimerCount() > 0);
      await vi.advanceTimersByTimeAsync(1500);
      expect(await screen.findByText("Entre para gerar relatórios.")).toBeInTheDocument();
    });

    it("LLM indisponível: relatório sai com aviso visível", async () => {
      configurarRelatoriosMock({ llmIndisponivel: true, consultasAteFim: 1 });
      await abrir();
      await gerarEPollar(1);
      expect(await screen.findByTestId("aviso-llm")).toBeInTheDocument();
    });

    it("cache_hit mostra o selo", async () => {
      configurarRelatoriosMock({ cacheHit: true, consultasAteFim: 1 });
      await abrir();
      await gerarEPollar(1);
      expect(await screen.findByTestId("selo-cache")).toHaveTextContent("Gerado a partir do cache");
    });

    it("para o polling ao desmontar", async () => {
      const { unmount } = await abrir();
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      await ate(() => vi.getTimerCount() > 0);
      await vi.advanceTimersByTimeAsync(1500);
      await ate(() => getConsultasJobMock(900) === 1);
      unmount();
      await vi.advanceTimersByTimeAsync(6000);
      expect(getConsultasJobMock(900)).toBe(1);
    });

    it("para o polling ao trocar o nível", async () => {
      await abrir();
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      await screen.findByTestId("job-estado");
      await fireEvent.click(screen.getByRole("radio", { name: "Estado" }));
      expect(screen.queryByTestId("job-estado")).toBeNull();
      await vi.advanceTimersByTimeAsync(6000);
      expect(getConsultasJobMock(900)).toBe(0);
      expect(screen.queryByTestId("relatorio-view")).toBeNull();
    });
  });

  it("cabeçalho tem o link \"Meus relatórios\"", async () => {
    await abrir();
    expect(screen.getByRole("link", { name: "Meus relatórios" })).toHaveAttribute(
      "href",
      "/gestor/relatorios/salvos",
    );
  });

  describe("fase 3: salvar e preenchimento por query", () => {
    it("o relatório gerado traz as ações e salva pelo job_id", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      await abrir();
      await gerarEPollar();
      const view = await screen.findByTestId("relatorio-view");
      expect(within(view).getByRole("button", { name: "Imprimir / salvar PDF" })).toBeInTheDocument();
      expect(within(view).getByRole("button", { name: "Baixar Markdown" })).toBeInTheDocument();
      await fireEvent.click(within(view).getByRole("button", { name: "Salvar relatório" }));
      expect(await screen.findByTestId("relatorio-salvo")).toHaveTextContent("Salvo");
      expect(screen.getByRole("link", { name: "Ver meus relatórios" })).toHaveAttribute(
        "href",
        "/gestor/relatorios/salvos",
      );
      expect(getSalvosMock()).toHaveLength(1);
      expect(getSalvosMock()[0]).toMatchObject({ job_id: 900, tema: { id: "ideb_territorio" } });
    });

    it("gerar outro relatório volta o botão \"Salvar relatório\"", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      configurarRelatoriosMock({ consultasAteFim: 1 });
      await abrir();
      await gerarEPollar(1);
      await fireEvent.click(await screen.findByRole("button", { name: "Salvar relatório" }));
      await screen.findByTestId("relatorio-salvo");
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 2);
      await ate(() => vi.getTimerCount() > 0);
      await vi.advanceTimersByTimeAsync(1500);
      expect(await screen.findByRole("button", { name: "Salvar relatório" })).toBeInTheDocument();
      expect(screen.queryByTestId("relatorio-salvo")).toBeNull();
    });

    it("409 ao salvar mostra a mensagem", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      configurarRelatoriosMock({ consultasAteFim: 1 });
      server.use(
        http.post("/api/gestor/:cod_inep/relatorios/salvos", () =>
          HttpResponse.json({ error: "O relatório ainda não terminou de ser gerado." }, { status: 409 }),
        ),
      );
      await abrir();
      await gerarEPollar(1);
      await fireEvent.click(await screen.findByRole("button", { name: "Salvar relatório" }));
      expect(await screen.findByTestId("erro-salvar")).toHaveTextContent("ainda não terminou");
    });

    it("gerar de novo: recorte de fora da escola, tema e opções da query; gera uma vez", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      window.history.replaceState(
        {},
        "",
        "/gestor/relatorios?nivel=municipio&codigo=1200401&nome=Rio%20Branco&tema=ideb_territorio&etapa=ensino_medio&rede=Municipal&gerar=1",
      );
      render(RelatoriosPage);
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0]).toEqual({
        geotag: { nivel: "municipio", codigo: "1200401" },
        tema: "ideb_territorio",
        opcoes: { etapa: "ensino_medio", rede: "Municipal" },
      });
      expect(screen.getByTestId("recorte-query")).toHaveTextContent("Recorte: Rio Branco");
      expect(screen.getByRole("radio", { name: "Município" })).toBeChecked();
      expect(screen.getByLabelText("Etapa")).toHaveValue("ensino_medio");
      expect(screen.getByLabelText("Rede")).toHaveValue("Municipal");
      // a query sai da URL: recarregar não gera outra vez
      expect(window.location.search).toBe("");
      expect(window.location.pathname).toBe("/gestor/relatorios");
      await ate(() => vi.getTimerCount() > 0);
      for (let i = 0; i < 3; i += 1) await vi.advanceTimersByTimeAsync(1500);
      expect(await screen.findByTestId("relatorio-view")).toBeInTheDocument();
      expect(getPedidosRelatorioMock()).toHaveLength(1);
    });

    it("sem gerar=1 só preenche; \"Trocar recorte\" volta ao da escola", async () => {
      window.history.replaceState(
        {},
        "",
        "/gestor/relatorios?nivel=uf&codigo=AC&nome=Acre&tema=infraestrutura_ideb&etapa=fundamental_ii",
      );
      render(RelatoriosPage);
      await screen.findByTestId("temas");
      expect(screen.getByRole("radio", { name: "Estado" })).toBeChecked();
      expect(screen.getByTestId("recorte-query")).toHaveTextContent("Recorte: Acre");
      expect(screen.getByRole("radio", { name: /Infraestrutura e IDEB/ })).toBeChecked();
      expect(screen.getByLabelText("Etapa")).toHaveValue("fundamental_ii");
      expect(screen.getByTestId("geotag-resumo")).toHaveTextContent("Acre");
      expect(screen.queryByLabelText("Escolher outro")).toBeNull();
      expect(getPedidosRelatorioMock()).toHaveLength(0);

      await fireEvent.click(screen.getByRole("button", { name: "Trocar recorte" }));
      expect(screen.queryByTestId("recorte-query")).toBeNull();
      expect(screen.getByLabelText(/Da minha escola: Rondônia/)).toBeChecked();
      expect(screen.getByTestId("geotag-resumo")).toHaveTextContent("Rondônia");

      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0].geotag).toEqual({ nivel: "uf", codigo: "RO" });
    });

    it("trocar o nível descarta o recorte da query", async () => {
      window.history.replaceState({}, "", "/gestor/relatorios?nivel=regiao&codigo=NE&nome=Nordeste");
      render(RelatoriosPage);
      await screen.findByTestId("temas");
      expect(screen.getByTestId("recorte-query")).toHaveTextContent("Recorte: Nordeste");
      await fireEvent.click(screen.getByRole("radio", { name: "Município" }));
      expect(screen.queryByTestId("recorte-query")).toBeNull();
      expect(screen.getByLabelText(/Da minha escola: Porto Velho/)).toBeChecked();
    });

    it("recorte igual ao da escola fica como \"Da minha escola\"; escola usa o INEP do gestor", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      window.history.replaceState(
        {},
        "",
        "/gestor/relatorios?nivel=escola&codigo=99999999&tema=historico_escola&gerar=1",
      );
      render(RelatoriosPage);
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0]).toEqual({
        geotag: { nivel: "escola", codigo: "11000040" },
        tema: "historico_escola",
      });
      expect(screen.queryByTestId("recorte-query")).toBeNull();
    });

    it("município da própria escola pela query não vira recorte externo", async () => {
      window.history.replaceState({}, "", "/gestor/relatorios?nivel=municipio&codigo=1100205&nome=Porto%20Velho");
      render(RelatoriosPage);
      await screen.findByTestId("temas");
      expect(screen.queryByTestId("recorte-query")).toBeNull();
      expect(screen.getByLabelText(/Da minha escola: Porto Velho/)).toBeChecked();
    });

    it("query inválida é ignorada (nível, código, tema e opção)", async () => {
      window.history.replaceState(
        {},
        "",
        "/gestor/relatorios?nivel=uf&codigo=acre&tema=nao_existe&etapa=xyz&gerar=1",
      );
      render(RelatoriosPage);
      await screen.findByTestId("temas");
      expect(screen.getByRole("radio", { name: "Estado" })).toBeChecked();
      expect(screen.queryByTestId("recorte-query")).toBeNull();
      expect(screen.getByRole("radio", { name: /IDEB do território/ })).toBeChecked();
      expect(screen.getByLabelText("Etapa")).toHaveValue("fundamental_i");
      // gerar=1 com recorte-padrão válido ainda gera (o recorte da escola)
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0].geotag).toEqual({ nivel: "uf", codigo: "RO" });
    });

    it("sem sessão, a query fica na URL para depois do login", async () => {
      window.localStorage.clear();
      setApiToken(null);
      window.history.replaceState({}, "", "/gestor/relatorios?nivel=regiao&codigo=NE&nome=Nordeste");
      render(RelatoriosPage);
      expect(await screen.findByText("Entre para gerar relatórios.")).toBeInTheDocument();
      // a query continua lá para depois do login
      expect(window.location.search).toContain("nivel=regiao");
    });
  });

  describe("fase 4: assistentes", () => {
    const niveisVisiveis = () =>
      within(screen.getByRole("radiogroup", { name: "Nível do recorte" }))
        .getAllByRole("radio")
        .map((r) => r.value);

    async function irParaEda() {
      await fireEvent.click(screen.getByRole("radio", { name: "EDA do município" }));
      return screen.findByTestId("capitulos");
    }

    it("seletor no topo com \"Relatório por tema\" marcado; modo tema igual às fases anteriores", async () => {
      await abrir();
      const grupo = screen.getByTestId("assistentes");
      expect(within(grupo).getByRole("radio", { name: "Relatório por tema" })).toBeChecked();
      expect(within(grupo).getByRole("radio", { name: "EDA do município" })).toHaveAccessibleDescription(
        "Relatório exploratório completo de um município, em capítulos.",
      );
      expect(niveisVisiveis()).toEqual(["escola", "municipio", "uf", "regiao"]);
      expect(screen.queryByTestId("capitulos")).toBeNull();
    });

    it("EDA: só o nível município, sumário dos capítulos no lugar dos temas e as opções do assistente", async () => {
      await abrir();
      await fireEvent.click(screen.getByRole("radio", { name: "Região" }));
      await waitFor(() => expect(temasVisiveis()).toContain("tendencia_ideb"));

      const capitulos = await irParaEda();
      expect(within(capitulos).getAllByRole("listitem").map((li) => li.textContent)).toEqual([
        "IDEB do município",
        "Escolas do município pelo IDEB",
        "Redes de ensino",
        "Professores",
      ]);
      expect(screen.queryByTestId("temas")).toBeNull();
      expect(niveisVisiveis()).toEqual(["municipio"]);
      expect(screen.getByRole("radio", { name: "Município" })).toBeChecked();
      expect(screen.getByLabelText(/Da minha escola: Porto Velho/)).toBeChecked();
      // etapa com padrão no assistente: obrigatória, sem "Todas"; sem rede
      const etapa = screen.getByLabelText("Etapa");
      expect(etapa).toHaveValue("fundamental_i");
      expect(within(etapa).queryByRole("option", { name: "Todas as etapas" })).toBeNull();
      expect(screen.queryByLabelText("Rede")).toBeNull();
      expect(screen.getByRole("button", { name: "Gerar relatório" })).toBeEnabled();

      // de volta ao relatório por tema: temas e níveis de volta, primeiro tema escolhido
      await fireEvent.click(screen.getByRole("radio", { name: "Relatório por tema" }));
      await waitFor(() => expect(temasVisiveis()).toContain("ideb_territorio"));
      expect(screen.getByRole("radio", { name: /IDEB do território/ })).toBeChecked();
      expect(niveisVisiveis()).toEqual(["escola", "municipio", "uf", "regiao"]);
      expect(screen.getByLabelText("Rede")).toHaveValue("");
    });

    it("pede /temas com ?assistente só fora do padrão", async () => {
      const assistentesPedidos = [];
      server.use(
        http.get("/api/gestor/:cod_inep/relatorios/temas", ({ request }) => {
          assistentesPedidos.push(new URL(request.url).searchParams.get("assistente"));
          return undefined; // segue para o handler padrão
        }),
      );
      await abrir();
      expect(assistentesPedidos).toEqual([null]);
    });

    it("gera a EDA sem tema, com assistente e opções; o relatório sai em capítulos", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      await abrir();
      await irParaEda();
      await fireEvent.change(screen.getByLabelText("Etapa"), { target: { value: "fundamental_ii" } });
      await gerarEPollar();
      expect(getPedidosRelatorioMock()[0]).toEqual({
        geotag: { nivel: "municipio", codigo: "1100205" },
        opcoes: { etapa: "fundamental_ii" },
        assistente: "eda_municipio",
      });
      const view = await screen.findByTestId("relatorio-view");
      expect(within(view).getByRole("navigation", { name: "Sumário" })).toBeInTheDocument();
      expect(within(view).getAllByTestId("relatorio-capitulo")).toHaveLength(2);
    });

    it("trocar de assistente para o polling", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      await abrir();
      await fireEvent.click(screen.getByRole("button", { name: "Gerar relatório" }));
      await ate(() => getPedidosRelatorioMock().length === 1);
      await screen.findByTestId("job-estado");
      await irParaEda();
      expect(screen.queryByTestId("job-estado")).toBeNull();
      await vi.advanceTimersByTimeAsync(6000);
      expect(getConsultasJobMock(900)).toBe(0);
      expect(screen.queryByTestId("relatorio-view")).toBeNull();
    });

    it("query com assistente: escolhe a EDA, aplica as opções e gera uma vez", async () => {
      vi.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });
      window.history.replaceState(
        {},
        "",
        "/gestor/relatorios?assistente=eda_municipio&nivel=municipio&codigo=1200401&nome=Rio%20Branco&etapa=ensino_medio&gerar=1",
      );
      render(RelatoriosPage);
      await ate(() => getPedidosRelatorioMock().length === 1);
      expect(getPedidosRelatorioMock()[0]).toEqual({
        geotag: { nivel: "municipio", codigo: "1200401" },
        opcoes: { etapa: "ensino_medio" },
        assistente: "eda_municipio",
      });
      expect(screen.getByRole("radio", { name: "EDA do município" })).toBeChecked();
      expect(screen.getByTestId("recorte-query")).toHaveTextContent("Recorte: Rio Branco");
      expect(window.location.search).toBe("");
    });

    it("query só com o assistente seleciona-o; nível fora do assistente cai no município", async () => {
      window.history.replaceState({}, "", "/gestor/relatorios?assistente=eda_municipio&nivel=uf&codigo=RO");
      render(RelatoriosPage);
      await screen.findByTestId("capitulos");
      expect(screen.getByRole("radio", { name: "Município" })).toBeChecked();
      expect(screen.queryByTestId("recorte-query")).toBeNull();
      expect(getPedidosRelatorioMock()).toHaveLength(0);
    });

    it("assistente desconhecido na query fica no padrão", async () => {
      window.history.replaceState({}, "", "/gestor/relatorios?assistente=nao_existe");
      await abrir();
      expect(screen.getByRole("radio", { name: "Relatório por tema" })).toBeChecked();
    });

    it("sem /assistentes (servidor antigo) segue no relatório por tema, sem seletor", async () => {
      server.use(
        http.get("/api/gestor/:cod_inep/relatorios/assistentes", () =>
          HttpResponse.json({ error: "not found" }, { status: 404 }),
        ),
      );
      await abrir();
      expect(screen.queryByTestId("assistentes")).toBeNull();
      expect(temasVisiveis()).toContain("ideb_territorio");
    });
  });
});
