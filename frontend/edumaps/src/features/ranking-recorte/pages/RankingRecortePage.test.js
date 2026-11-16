import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, afterEach, beforeEach } from "vitest";
import RankingRecortePage from "./RankingRecortePage.svelte";
import { _resetFontes } from "@/features/fontes/api/fontesApi.js";

function abrir(query = "") {
  window.history.replaceState({}, "", `/ranking${query}`);
  return render(RankingRecortePage);
}

describe("RankingRecortePage (#430)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("redes municipais: tabela, nota de método, contexto de INSE e URL", async () => {
    abrir("?aba=redes&uf=ES");
    const tabela = await screen.findByTestId("tabela-redes");
    expect(tabela).toHaveTextContent("Itarana");
    expect(tabela).toHaveTextContent("+0,84");
    expect(tabela).toHaveTextContent("−0,3");
    expect(tabela).toHaveTextContent("1,2 acima dos de INSE parecido");
    expect(tabela).toHaveTextContent("0,4 abaixo dos de INSE parecido");
    const nota = screen.getByTestId("nota-redes");
    expect(nota).toHaveTextContent("média simples das escolas municipais");
    expect(nota).toHaveTextContent("pelo menos 3 escolas");
    expect(nota).toHaveTextContent("2 ficaram de fora");
    expect(window.location.search).toBe("?aba=redes&indicador=ideb_anos_iniciais&uf=ES");
  });

  it("ordenar pela variação põe quem mais mudou primeiro e sem variação no fim", async () => {
    abrir("?aba=redes&uf=ES&ordem=variacao");
    const tabela = await screen.findByTestId("tabela-redes");
    const linhas = [...tabela.querySelectorAll("tbody tr")].map((tr) => tr.querySelectorAll("td")[1].textContent.trim());
    expect(linhas).toEqual(["Mantenópolis", "Vitória", "Itarana"]);
  });

  it("escolas de um município pelo link (?codigo_ibge=)", async () => {
    abrir("?aba=escolas&codigo_ibge=3205309&rede=municipal");
    const tabela = await screen.findByTestId("tabela-escolas");
    expect(tabela).toHaveTextContent("EMEF MARIA MADALENA");
    expect(tabela.querySelector('a[href="/escola/panel?inep=32095406"]')).not.toBeNull();
    expect(screen.getByTestId("nota-escolas")).toHaveTextContent("2 escolas de Vitória (ES)");
    expect(screen.getByLabelText("Rede").value).toBe("municipal");
  });

  it("aba de escolas sem município pede a escolha", async () => {
    abrir("?aba=escolas");
    expect(await screen.findByText("Escolha um município para ver as escolas.")).toBeInTheDocument();
    await fireEvent.click(screen.getByRole("tab", { name: "Redes municipais" }));
    await waitFor(() => expect(screen.getByTestId("tabela-redes")).toBeInTheDocument());
  });
});

import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import { REDES_FIXTURE } from "../mocks/fixtures.js";

describe("RankingRecortePage — atípico, mínimo e ordem (#437)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("marca o salto atípico e explica a regra na nota", async () => {
    abrir("?aba=redes&uf=ES");
    const tabela = await screen.findByTestId("tabela-redes");
    const marcas = screen.getAllByTestId("salto-atipico");
    expect(marcas).toHaveLength(1);
    expect(marcas[0].closest("tr")).toHaveTextContent("Mantenópolis");
    expect(tabela).toBeInTheDocument();
    const nota = screen.getByTestId("nota-redes");
    expect(nota).toHaveTextContent("a mais de 2 desvios padrão");
    expect(nota).toHaveTextContent("fora de −0,33 a +0,8");
    expect(nota).toHaveTextContent("1 rede marcada");
  });

  it("mínimo de escolas vai na consulta e na URL", async () => {
    let pedido = null;
    server.use(http.get("*/api/ranking/redes", ({ request }) => {
      pedido = new URL(request.url).searchParams;
      return HttpResponse.json({ ...REDES_FIXTURE, minimo_escolas: Number(pedido.get("minimo") ?? 3) });
    }));
    abrir("?aba=redes&uf=ES&minimo=10");
    await screen.findByTestId("tabela-redes");
    expect(pedido.get("minimo")).toBe("10");
    expect(screen.getByLabelText("Mínimo de escolas por rede").value).toBe("10");
    expect(window.location.search).toContain("minimo=10");
  });

  it("porte (#439): coluna de população, filtro na consulta e na URL", async () => {
    let pedido = null;
    server.use(http.get("*/api/ranking/redes", ({ request }) => {
      pedido = new URL(request.url).searchParams;
      const p = pedido.get("porte");
      const redes = p ? REDES_FIXTURE.redes.filter((r) => r.porte === p) : REDES_FIXTURE.redes;
      return HttpResponse.json({ ...REDES_FIXTURE, recorte: { uf: "ES", porte: p }, total: redes.length, redes });
    }));
    abrir("?aba=redes&uf=ES&porte=10_20mil");
    const tabela = await screen.findByTestId("tabela-redes");
    expect(pedido.get("porte")).toBe("10_20mil");
    expect(screen.getByLabelText("Porte do município").value).toBe("10_20mil");
    expect(tabela).toHaveTextContent("11.500");
    expect(tabela).not.toHaveTextContent("Vitória");
    const nota = screen.getByTestId("nota-redes");
    expect(nota).toHaveTextContent("população estimada pelo IBGE (2025)");
    expect(nota).toHaveTextContent("10 a 20 mil habitantes");
    expect(window.location.search).toContain("porte=10_20mil");

    await fireEvent.change(screen.getByLabelText("Porte do município"), { target: { value: "mais_500mil" } });
    expect(await screen.findByTestId("redes-vazio")).toHaveTextContent("Nenhuma rede");
  });

  it("menor primeiro inverte as redes e as escolas, e vai na URL", async () => {
    abrir("?aba=redes&uf=ES");
    await screen.findByTestId("tabela-redes");
    await fireEvent.click(screen.getByTestId("sentido-redes"));
    const nomes = () => [...screen.getByTestId("tabela-redes").querySelectorAll("tbody tr")]
      .map((tr) => tr.querySelectorAll("td")[1].textContent.trim());
    expect(nomes()).toEqual(["Vitória", "Mantenópolis", "Itarana"]);
    expect(window.location.search).toContain("sentido=asc");
  });

  it("ordem pela variação, menor primeiro: sem variação continua no fim", async () => {
    abrir("?aba=redes&uf=ES&ordem=variacao&sentido=asc");
    const tabela = await screen.findByTestId("tabela-redes");
    const nomes = [...tabela.querySelectorAll("tbody tr")].map((tr) => tr.querySelectorAll("td")[1].textContent.trim());
    expect(nomes).toEqual(["Vitória", "Mantenópolis", "Itarana"]);
  });

  it("escolas do menor para o maior mantêm a posição publicada", async () => {
    abrir("?aba=escolas&codigo_ibge=3205309&sentido=asc");
    const tabela = await screen.findByTestId("tabela-escolas");
    const primeira = tabela.querySelector("tbody tr");
    expect(primeira).toHaveTextContent("EMEF EXEMPLO; TESTE");
    expect(primeira.querySelector("td")).toHaveTextContent("2");
  });
});

describe("RankingRecortePage — região (#445)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  function capturar() {
    const pedidos = [];
    server.use(http.get("*/api/ranking/redes", ({ request }) => {
      const q = new URL(request.url).searchParams;
      pedidos.push(q);
      const regiao = q.get("regiao");
      const recorte = regiao ? { regiao: { id: regiao, nome: "Sudeste" } } : q.get("nacional") ? { nacional: true } : { uf: q.get("uf") };
      return HttpResponse.json({ ...REDES_FIXTURE, recorte });
    }));
    return pedidos;
  }

  it("região pelo link: consulta, UF ao lado do município, nota e URL", async () => {
    const pedidos = capturar();
    abrir("?aba=redes&regiao=SE");
    const tabela = await screen.findByTestId("tabela-redes");
    const q = pedidos.at(-1);
    expect(q.get("regiao")).toBe("SE");
    expect(q.get("uf")).toBeNull();
    expect(q.get("nacional")).toBeNull();
    expect(screen.getByLabelText("Abrangência").value).toBe("regiao");
    expect(screen.getByLabelText("Região").value).toBe("SE");
    expect(screen.queryByLabelText("UF")).toBeNull();
    expect(tabela).toHaveTextContent("Itarana · ES");
    expect(screen.getByTestId("nota-redes")).toHaveTextContent("Só as redes da região Sudeste");
    expect(window.location.search).toBe("?aba=redes&indicador=ideb_anos_iniciais&regiao=SE");
  });

  it("trocar a abrangência muda a consulta; o link antigo nacional=1 abre o Brasil", async () => {
    const pedidos = capturar();
    abrir("?aba=redes&nacional=1");
    await screen.findByTestId("tabela-redes");
    expect(screen.getByLabelText("Abrangência").value).toBe("brasil");
    expect(pedidos.at(-1).get("nacional")).toBe("1");

    await fireEvent.change(screen.getByLabelText("Abrangência"), { target: { value: "regiao" } });
    await waitFor(() => expect(pedidos.at(-1).get("regiao")).toBe("SE"));
    await fireEvent.change(screen.getByLabelText("Região"), { target: { value: "NE" } });
    await waitFor(() => expect(pedidos.at(-1).get("regiao")).toBe("NE"));
    expect(window.location.search).toContain("regiao=NE");

    await fireEvent.change(screen.getByLabelText("Abrangência"), { target: { value: "uf" } });
    await waitFor(() => expect(pedidos.at(-1).get("uf")).toBe("ES"));
    expect(pedidos.at(-1).get("regiao")).toBeNull();
    await waitFor(() => expect(screen.getByTestId("nota-redes")).not.toHaveTextContent("Só as redes da região"));
  });

  it("região desconhecida no link: volta para a UF", async () => {
    const pedidos = capturar();
    abrir("?aba=redes&regiao=XX&uf=ES");
    await screen.findByTestId("tabela-redes");
    expect(screen.getByLabelText("Abrangência").value).toBe("uf");
    expect(pedidos.at(-1).get("uf")).toBe("ES");
  });
});
