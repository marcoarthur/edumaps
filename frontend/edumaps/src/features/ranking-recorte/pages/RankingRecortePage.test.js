import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, afterEach, beforeEach, vi } from "vitest";
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
import { REDES_FIXTURE, ESCOLAS_FIXTURE } from "../mocks/fixtures.js";

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

describe("RankingRecortePage — recorte no CSV (#448)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => {
    window.history.replaceState({}, "", "/");
    vi.restoreAllMocks();
  });

  async function baixado(botao) {
    let blob = null;
    URL.createObjectURL = vi.fn((b) => { blob = b; return "blob:teste"; });
    URL.revokeObjectURL = vi.fn();
    const clique = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});
    await fireEvent.click(botao);
    expect(clique).toHaveBeenCalled();
    // O Blob do jsdom não tem .text(); o FileReader lê.
    const texto = await new Promise((ok) => {
      const fr = new FileReader();
      fr.onload = () => ok(fr.result);
      fr.readAsText(blob);
    });
    return texto.replace(/^﻿/, "").split("\r\n").filter(Boolean).map((l) => l.split(";"));
  }

  it("CSV das redes da região com porte traz o recorte em toda linha", async () => {
    server.use(http.get("*/api/ranking/redes", () =>
      HttpResponse.json({ ...REDES_FIXTURE, recorte: { regiao: { id: "NE", nome: "Nordeste" }, porte: "10_20mil" } })));
    abrir("?aba=redes&regiao=NE&porte=10_20mil");
    await screen.findByTestId("tabela-redes");
    const l = await baixado(screen.getByRole("button", { name: "Baixar CSV" }));
    expect(l[0].slice(-3)).toEqual(["recorte", "porte_filtro", "minimo_escolas"]);
    expect(l).toHaveLength(4);
    for (const linha of l.slice(1)) expect(linha.slice(-3)).toEqual(["regiao:NE", "10_20mil", "3"]);
  });

  it("CSV das redes traz as duas posições com nome (#453)", async () => {
    abrir("?aba=redes&uf=ES&ordem=variacao");
    await screen.findByTestId("tabela-redes");
    const l = await baixado(screen.getByRole("button", { name: "Baixar CSV" }));
    expect(l[0].slice(0, 2)).toEqual(["posicao_valor", "posicao_variacao"]);
    // Linhas na ordem da tela (variação): Mantenópolis, Vitória, Itarana.
    expect(l.slice(1).map((x) => x.slice(0, 2))).toEqual([["2", "1"], ["3", "2"], ["1", ""]]);
  });

  it("CSV das escolas traz o município e a rede filtrada", async () => {
    abrir("?aba=escolas&codigo_ibge=3205309&rede=municipal");
    await screen.findByTestId("tabela-escolas");
    const l = await baixado(screen.getByRole("button", { name: "Baixar CSV" }));
    expect(l[0].slice(-4)).toEqual(["codigo_ibge", "municipio", "uf", "rede_filtro"]);
    expect(l[1].slice(-4)).toEqual(["3205309", "Vitória", "ES", "municipal"]);
  });
});

describe("RankingRecortePage — município destacado (#449)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  const VITORIA = { codigo_ibge: "3205309", municipio: "Vitória", uf: "ES", regiao: "SE", populacao: 368000, porte: "100_500mil", escolas: 51, situacao: "no_ranking", posicao: 3 };

  function capturar(destaque) {
    const pedidos = [];
    server.use(http.get("*/api/ranking/redes", ({ request }) => {
      const q = new URL(request.url).searchParams;
      pedidos.push(q);
      return HttpResponse.json({ ...REDES_FIXTURE, ...(q.get("destaque") ? { destaque } : {}) });
    }));
    return pedidos;
  }

  it("pelo link: destaca a linha, resume a posição e sugere recortes", async () => {
    const pedidos = capturar(VITORIA);
    abrir("?aba=redes&uf=ES&destaque=3205309");
    const linha = await screen.findByTestId("linha-destaque");
    expect(pedidos.at(-1).get("destaque")).toBe("3205309");
    expect(linha).toHaveTextContent("Vitória");
    expect(screen.getAllByTestId("linha-destaque")).toHaveLength(1);
    const resumo = screen.getByTestId("destaque-resumo");
    expect(resumo).toHaveTextContent("Vitória (ES, Sudeste, 100 a 500 mil hab.)");
    expect(resumo).toHaveTextContent("3ª de 3 redes neste recorte");
    expect(screen.getByTestId("sugerir-porte-regiao")).toHaveTextContent("mesmo porte no Sudeste");
    expect(screen.queryByTestId("sugerir-uf")).toBeNull();
    expect(window.location.search).toContain("destaque=3205309");

    const rolar = vi.fn();
    linha.scrollIntoView = rolar;
    await fireEvent.click(screen.getByTestId("ir-destaque"));
    expect(rolar).toHaveBeenCalledWith({ block: "center" });
  });

  it("sugestão de porte e região troca o recorte e mantém o destaque", async () => {
    const pedidos = capturar(VITORIA);
    abrir("?aba=redes&uf=ES&destaque=3205309");
    await fireEvent.click(await screen.findByTestId("sugerir-porte-regiao"));
    await waitFor(() => expect(pedidos.at(-1).get("regiao")).toBe("SE"));
    const q = pedidos.at(-1);
    expect(q.get("porte")).toBe("100_500mil");
    expect(q.get("destaque")).toBe("3205309");
    expect(q.get("uf")).toBeNull();
    expect(screen.getByLabelText("Abrangência").value).toBe("regiao");
    expect(window.location.search).toContain("regiao=SE");
  });

  it("rede fora da lista: diz o motivo", async () => {
    capturar({ codigo_ibge: "3200102", municipio: "Afonso Cláudio", uf: "ES", regiao: "SE", populacao: 30000, porte: "20_50mil", escolas: 2, situacao: "poucas_escolas", posicao: null });
    abrir("?aba=redes&uf=ES&destaque=3200102");
    const resumo = await screen.findByTestId("destaque-resumo");
    expect(resumo).toHaveTextContent("A rede não está nesta lista: só 2 escolas municipais com dado em 2023; o mínimo é 3.");
    expect(screen.queryByTestId("linha-destaque")).toBeNull();
  });

  it("município de outra UF: motivo e sugestão da UF dele", async () => {
    capturar({ codigo_ibge: "2304400", municipio: "Fortaleza", uf: "CE", regiao: "NE", populacao: 2400000, porte: "mais_500mil", escolas: 200, situacao: "fora_do_recorte", posicao: null });
    abrir("?aba=redes&uf=ES&destaque=2304400");
    const resumo = await screen.findByTestId("destaque-resumo");
    expect(resumo).toHaveTextContent("o município é de CE (Nordeste), fora deste recorte");
    expect(screen.getByTestId("sugerir-uf")).toHaveTextContent("Comparar na UF (CE)");
  });

  it("tirar o destaque e levar o município para a aba de escolas", async () => {
    const pedidos = capturar(VITORIA);
    let escolasPedido = null;
    server.use(http.get("*/api/ranking/escolas", ({ request }) => {
      escolasPedido = new URL(request.url).searchParams;
      return HttpResponse.json(ESCOLAS_FIXTURE);
    }));
    abrir("?aba=redes&uf=ES&destaque=3205309");
    await screen.findByTestId("linha-destaque");
    await fireEvent.click(screen.getByRole("tab", { name: "Escolas de um município" }));
    await waitFor(() => expect(escolasPedido?.get("codigo_ibge")).toBe("3205309"));

    await fireEvent.click(screen.getByRole("tab", { name: "Redes municipais" }));
    await screen.findByTestId("linha-destaque");
    await fireEvent.click(screen.getByRole("button", { name: "Tirar o destaque" }));
    await waitFor(() => expect(pedidos.at(-1).get("destaque")).toBeNull());
    await waitFor(() => expect(screen.queryByTestId("destaque-resumo")).toBeNull());
    expect(window.location.search).not.toContain("destaque");
  });
});

describe("RankingRecortePage — variação vazia com motivo (#453)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("conta as redes sem variação e diz o motivo com o mínimo", async () => {
    abrir("?aba=redes&uf=ES");
    const s = await screen.findByTestId("sem-variacao");
    expect(s).toHaveTextContent("1 rede sem variação: tinham menos de 3 escolas com dado em 2021 e em 2023 (o mesmo mínimo do ranking).");
  });

  it("variação nas mesmas escolas: a regra na nota e quantas entre parênteses (#499)", async () => {
    abrir("?aba=redes&uf=ES");
    await screen.findByTestId("tabela-redes");
    expect(screen.getByTestId("regra-variacao")).toHaveTextContent("nas mesmas escolas, as que têm dado nas duas edições");
    const n = screen.getAllByTestId("escolas-variacao");
    // Vitória: 51 escolas, 40 nas duas edições; Mantenópolis: todas (sem parênteses); Itarana: sem variação
    expect(n).toHaveLength(1);
    expect(n[0]).toHaveTextContent("(40)");
    expect(n[0].closest("tr")).toHaveTextContent("Vitória");
  });

  it("sem edição anterior: diz que não há com o que comparar", async () => {
    server.use(http.get("*/api/ranking/redes", () => HttpResponse.json({
      ...REDES_FIXTURE, ano_anterior: null, redes: REDES_FIXTURE.redes.map((r) => ({ ...r, variacao: null })),
    })));
    abrir("?aba=redes&uf=ES");
    expect(await screen.findByTestId("sem-variacao")).toHaveTextContent("3 redes sem variação: sem edição anterior para comparar.");
  });

  it("todas com variação: sem a frase", async () => {
    server.use(http.get("*/api/ranking/redes", () => HttpResponse.json({
      ...REDES_FIXTURE, redes: REDES_FIXTURE.redes.filter((r) => r.variacao != null),
    })));
    abrir("?aba=redes&uf=ES");
    await screen.findByTestId("tabela-redes");
    expect(screen.queryByTestId("sem-variacao")).toBeNull();
  });
});

describe("RankingRecortePage — infraestrutura básica e método (#457)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  const BASICA = {
    indicador: { id: "infraestrutura_basica", label: "Infraestrutura básica", fonte: "censo", maximo: 4,
      metodo: "Quantos dos 4 itens básicos a escola tem, de 0 a 4 (maior é melhor)." },
    ano: 2025, municipio: { codigo_ibge: "2204402", nome: "Gilbués", uf: "PI" }, rede: null, total: 2,
    escolas: [
      { co_entidade: "22000001", no_entidade: "ESCOLA COMPLETA", rede: "Municipal", valor: 4, posicao: 1, inse: null, faltam: [] },
      { co_entidade: "22063960", no_entidade: "ESCOLA SEM TRES", rede: "Municipal", valor: 1, posicao: 2, inse: null, faltam: ["água", "energia", "esgoto"] },
    ],
  };

  it("mostra 'x de 4', a coluna Falta e o método", async () => {
    let pedido = null;
    server.use(http.get("*/api/ranking/escolas", ({ request }) => {
      pedido = new URL(request.url).searchParams;
      return HttpResponse.json(BASICA);
    }));
    abrir("?aba=escolas&indicador=infraestrutura_basica&codigo_ibge=2204402&sentido=asc");
    const tabela = await screen.findByTestId("tabela-escolas");
    expect(pedido.get("indicador")).toBe("infraestrutura_basica");
    expect(screen.getByLabelText("Indicador").value).toBe("infraestrutura_basica");
    const linhas = [...tabela.querySelectorAll("tbody tr")];
    expect(linhas[0]).toHaveTextContent("ESCOLA SEM TRES");
    expect(linhas[0]).toHaveTextContent("1 de 4");
    expect(linhas[0]).toHaveTextContent("água, energia, esgoto");
    expect(linhas[1]).toHaveTextContent("4 de 4");
    expect(screen.getAllByTestId("faltam")[1]).toHaveTextContent("–");
    expect(screen.getByTestId("metodo-indicador")).toHaveTextContent("Quantos dos 4 itens básicos");
    expect(screen.queryByTestId("versao-indicador")).toBeNull();
  });

  it("índice antigo: método na nota, sem a coluna Falta", async () => {
    server.use(http.get("*/api/ranking/escolas", () => HttpResponse.json({
      ...ESCOLAS_FIXTURE, indicador: { id: "infraestrutura", label: "Infraestrutura", fonte: "censo", metodo: "Índice de 0 a 10. Não é infraestrutura básica.",
        versao: "indices-v2", versao_data: "2026-11-16" },
    })));
    abrir("?aba=escolas&indicador=infraestrutura&codigo_ibge=3205309");
    await screen.findByTestId("tabela-escolas");
    expect(screen.getByTestId("metodo-indicador")).toHaveTextContent("Não é infraestrutura básica");
    expect(screen.getByTestId("metodo-indicador")).toHaveTextContent("Como se calcula (indices-v2, de 16/11/2026):");
    expect(screen.queryAllByTestId("faltam")).toHaveLength(0);
  });
});

describe("RankingRecortePage — cobertura do IDEB na lista de escolas (#503)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  const COM_COBERTURA = {
    ...ESCOLAS_FIXTURE,
    rede: null,
    indicador: { ...ESCOLAS_FIXTURE.indicador, metodo: "IDEB observado da escola. Dado do INEP, publicado com o IDEB, na edição 2023, para os anos iniciais do fundamental. Só escolas em funcionamento no Censo 2025. A falta não é aleatória." },
    cobertura: {
      ano_censo: 2025, etapa_texto: "os anos iniciais do fundamental", oferecem: 794, com_indicador: 2,
      publicas: { oferecem: 282, com_indicador: 2 }, privadas: { oferecem: 512, com_indicador: 0 },
    },
  };

  it("diz quantas oferecem a etapa, públicas e privadas, e o método", async () => {
    server.use(http.get("*/api/ranking/escolas", () => HttpResponse.json(COM_COBERTURA)));
    abrir("?aba=escolas&codigo_ibge=3205309");
    await screen.findByTestId("tabela-escolas");
    const nota = screen.getByTestId("nota-escolas");
    expect(nota).toHaveTextContent("2 escolas em funcionamento de Vitória (ES)");
    expect(screen.getByTestId("cobertura-escolas")).toHaveTextContent(
      "No Censo 2025, 794 escolas oferecem os anos iniciais do fundamental (282 públicas, 2 com o dado; 512 privadas, 0 com o dado).",
    );
    expect(screen.getByTestId("metodo-indicador")).toHaveTextContent("A falta não é aleatória");
  });

  it("com rede filtrada, só o total da rede", async () => {
    server.use(http.get("*/api/ranking/escolas", () => HttpResponse.json({
      ...COM_COBERTURA, rede: "municipal",
      cobertura: { ...COM_COBERTURA.cobertura, oferecem: 282 },
    })));
    abrir("?aba=escolas&codigo_ibge=3205309&rede=municipal");
    await screen.findByTestId("tabela-escolas");
    const c = screen.getByTestId("cobertura-escolas");
    expect(c).toHaveTextContent("No Censo 2025, 282 escolas oferecem os anos iniciais do fundamental.");
    expect(c).not.toHaveTextContent("privadas");
  });

  it("resposta antiga sem cobertura: nota como antes", async () => {
    abrir("?aba=escolas&codigo_ibge=3205309&rede=municipal");
    await screen.findByTestId("tabela-escolas");
    expect(screen.queryByTestId("cobertura-escolas")).toBeNull();
    expect(screen.getByTestId("nota-escolas")).toHaveTextContent("2 escolas de Vitória (ES)");
  });
});
