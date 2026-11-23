// src/features/schools/components/panel/SchoolPanel.test.js
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolPanel from "./SchoolPanel.svelte";

// O motor do @carbon depende de APIs SVG que o jsdom não implementa; usamos o
// mesmo stub dos testes de charts para validar a fiação.
vi.mock("@carbon/charts-svelte", async () => {
  const stub = (
    await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")
  ).default;
  return { LineChart: stub };
});

describe("SchoolPanel", () => {
  // Dados no formato do contrato da API (português)
  const mockSchool = {
    id_escola: "12345678",
    nome: "Escola Municipal Exemplo",
    municipio: "São Paulo",
    uf: "SP",
    rede: "municipal",
    matriculas: 450,
    etapas: {
      creche: true,
      pre_escola: true,
      fundamental_i: true,
      fundamental_ii: false,
      ensino_medio: false,
      eja: false,
      profissionalizante: false,
    },
    infraestrutura: {
      agua_potavel: true,
      energia: true,
      esgoto: true,
      coleta_lixo: true,
      internet: true,
      biblioteca: true,
      laboratorio_ciencias: false,
      laboratorio_informatica: false,
      quadra_esportes: true,
      acessibilidade: false,
      alimentacao: true,
    },
  };

  it("deve renderizar o cabeçalho com nome, cidade, estado e INEP", () => {
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
    });

    expect(screen.getByText("Escola Municipal Exemplo")).toBeInTheDocument();
    expect(
      screen.getByText("São Paulo · SP · INEP 12345678"),
    ).toBeInTheDocument();
    // Verifica o SchoolSummary através dos textos que ele renderiza
    expect(screen.getByText(/Rede Municipal/i)).toBeInTheDocument();
    //expect(screen.getByText(/450 matrículas/i)).toBeInTheDocument();
  });

  it("deve renderizar as seções de etapas e infraestrutura", () => {
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
    });

    expect(screen.getByText("Etapas de ensino")).toBeInTheDocument();
    // Os ícones têm aria-label definido pelo label do icon-data.js
    expect(screen.getByLabelText("Creche")).toBeInTheDocument();
    expect(screen.getByLabelText("Pré-escola")).toBeInTheDocument();

    expect(screen.getByText("Infraestrutura")).toBeInTheDocument();
    expect(screen.getByLabelText("Água potável")).toBeInTheDocument();
    expect(
      screen.getByLabelText("Energia elétrica"),
    ).toBeInTheDocument();
  });

  it("#510: estados tem/não tem/sem dado, detalhe do esgoto e matrículas com o ano", () => {
    render(SchoolPanel, {
      school: {
        ...mockSchool,
        matriculas: 285,
        anoCenso: 2025,
        etapas: { ...mockSchool.etapas, eja: null },
        infraestrutura: { ...mockSchool.infraestrutura, energia: false, internet: null },
        infraDetalhe: { esgoto: "outra_solucao" },
      },
      indicators: [],
      similarSchools: [],
    });

    // pré-escola oferecida: acesa, sem × nem n/d
    expect(screen.queryByTestId("nd-pre_escola")).not.toBeInTheDocument();
    // sem dado: n/d, não ×
    expect(screen.getByTestId("nd-eja")).toBeInTheDocument();
    expect(screen.getByTestId("nd-internet")).toBeInTheDocument();
    // esgoto por fossa: aceso, com o detalhe
    expect(screen.getByTestId("detalhe-esgoto")).toHaveTextContent("outra solução");
    expect(screen.getByTitle("Energia elétrica · não tem")).toBeInTheDocument();
    expect(screen.getByTitle("Esgoto · outra solução")).toBeInTheDocument();

    expect(screen.getByText("285")).toBeInTheDocument();
    expect(screen.getByTestId("matriculas-ano")).toHaveTextContent("(Censo 2025)");
    expect(screen.queryByText(/porte (pequena|média|grande)/i)).not.toBeInTheDocument();
    expect(screen.getByTestId("fonte-censo")).toHaveTextContent("Censo Escolar 2025");
  });

  it("#541: posição sem verde e primeiro lugar dividido dito como lugar", () => {
    render(SchoolPanel, {
      school: mockSchool,
      similarSchools: [],
      indicators: [
        { indicador: { id: "ideb_anos_iniciais", label: "IDEB – Anos Iniciais", valor: 4.7 }, ano: 2023,
          ranking: { municipio: { posicao: 76, total: 81, percentil: 4, abaixo: 5, empate: 1 } } },
        { indicador: { id: "taxa_aprovacao_fund_i", label: "Taxa de Aprovação – Anos Iniciais", valor: 100 }, ano: 2023,
          ranking: { municipio: { posicao: 1, total: 81, percentil: 16, abaixo: 13, empate: 68 } } },
      ],
    });
    const ideb = screen.getByTestId("leitura-ideb_anos_iniciais");
    expect(ideb).toHaveTextContent("Acima de 4% das outras escolas no município");
    expect(ideb.className).not.toMatch(/green/);
    expect(screen.getByTestId("leitura-taxa_aprovacao_fund_i")).toHaveTextContent("1º lugar, dividido com 67 escolas com o mesmo valor");
    expect(screen.queryByText(/acima de 16%/i)).toBeNull();
  });

  it("#510: o cartão diz o empate e leva à posição da escola", () => {
    const indicators = [
      {
        indicador: { id: "sustentabilidade", label: "Sustentabilidade", valor: 0 },
        ano: 2025,
        ranking: {
          municipio: { posicao: 767, total: 1432, percentil: 0, abaixo: 0, empate: 666 },
        },
      },
    ];
    render(SchoolPanel, { school: mockSchool, indicators, similarSchools: [] });

    // #541: empate no fim da lista = último lugar dividido
    expect(screen.getByTestId("leitura-sustentabilidade")).toHaveTextContent("Último lugar, dividido com 665 escolas com o mesmo valor");
    expect(screen.queryByTestId("empate-sustentabilidade")).toBeNull();
    expect(screen.getByText("ver a posição →")).toHaveAttribute(
      "href",
      "/escola/ranking?inep=12345678",
    );
  });

  it("não deve renderizar a seção de indicadores se indicators estiver vazio", () => {
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
    });

    expect(screen.queryByText("Indicadores")).not.toBeInTheDocument();
    // Não deve ter o selo de ranking
    expect(screen.queryByText(/Acima de \d+%/i)).not.toBeInTheDocument();
  });

  it("deve renderizar a seção de indicadores se houver indicadores", () => {
    const indicators = [
      {
        indicador: { id: "ideb", label: "IDEB", valor: 5.7 },
        ano: 2023,
        ranking: {
          municipio: { posicao: 10, total: 100, percentil: 90 },
        },
      },
    ];
    render(SchoolPanel, { school: mockSchool, indicators, similarSchools: [] });

    expect(screen.getByText("Indicadores")).toBeInTheDocument();
    expect(screen.getByText("IDEB")).toBeInTheDocument();
    expect(screen.getByText("5.7")).toBeInTheDocument();
    expect(screen.getByText("(2023)")).toBeInTheDocument();
    expect(screen.getByText(/Acima de.*no município/i)).toBeInTheDocument();
  });

  it("deve exibir mensagem de carregamento quando loadingSimilarSchools for true", () => {
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
      loadingSimilarSchools: true,
    });

    expect(
      screen.getByText("Buscando escolas semelhantes…"),
    ).toBeInTheDocument();
    expect(screen.queryByText(/Escola Similar/i)).not.toBeInTheDocument();
  });

  it("deve renderizar a lista de escolas semelhantes quando loadingSimilarSchools for false", () => {
    const similarSchools = [
      {
        id_escola: "1",
        nome: "Escola Similar 1",
        rede: "municipal",
        matriculas: 400,
        etapas: {},
      },
      {
        id_escola: "2",
        nome: "Escola Similar 2",
        rede: "estadual",
        matriculas: 500,
        etapas: {},
      },
    ];
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools,
      loadingSimilarSchools: false,
    });

    expect(screen.getByText("Escolas semelhantes")).toBeInTheDocument();
    expect(screen.getByText("Escola Similar 1")).toBeInTheDocument();
    expect(screen.getByText("Escola Similar 2")).toBeInTheDocument();
  });

  it("deve chamar onSelectSimilarSchool quando uma escola semelhante for selecionada", async () => {
    const onSelectMock = vi.fn();
    const similarSchools = [
      {
        id_escola: "1",
        nome: "Escola Similar 1",
        rede: "municipal",
        matriculas: 400,
        etapas: {},
      },
    ];
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools,
      loadingSimilarSchools: false,
      onSelectSimilarSchool: onSelectMock,
    });

    // O card é um botão que contém o nome da escola
    const card = screen.getByText("Escola Similar 1").closest("button");
    expect(card).toBeInTheDocument();
    await fireEvent.click(card);

    expect(onSelectMock).toHaveBeenCalledWith("1");
  });

  it("deve renderizar a seção Desempenho abaixo de Escolas semelhantes", () => {
    const desempenho = [
      { ano: 2021, etapa: "fundamental_ii", ideb_observado: 5.2 },
      { ano: 2023, etapa: "fundamental_ii", ideb_observado: 4.8 },
    ];
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
      desempenho,
    });

    const headers = screen
      .getAllByRole("heading", { level: 2 })
      .map((h) => h.textContent.trim());
    expect(headers).toContain("Desempenho");
    expect(headers.indexOf("Desempenho")).toBeGreaterThan(
      headers.indexOf("Escolas semelhantes"),
    );
  });

  it("não deve renderizar a seção Desempenho sem histórico", () => {
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
      desempenho: [],
    });

    expect(screen.queryByText("Desempenho")).not.toBeInTheDocument();
  });

  it("tem link para o painel financeiro da escola", () => {
    render(SchoolPanel, {
      school: mockSchool,
      indicators: [],
      similarSchools: [],
    });

    const link = screen.getByRole("link", { name: /painel financeiro/i });
    expect(link).toHaveAttribute(
      "href",
      `/escola/financeiro?inep=${mockSchool.id_escola}`,
    );
  });
});
