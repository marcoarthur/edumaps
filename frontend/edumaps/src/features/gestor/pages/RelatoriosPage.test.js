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
});
