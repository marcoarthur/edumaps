// src/features/schools/components/panel/SchoolPanel.test.js
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolPanel from "./SchoolPanel.svelte";

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
      screen.getByLabelText("Energia da rede pública"),
    ).toBeInTheDocument();
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
});
