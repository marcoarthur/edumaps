// src/features/gestor/components/GestorPanel.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import GestorPanel from "./GestorPanel.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (
    await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")
  ).default;
  return { LineChart: stub, DonutChart: stub, BarChartGrouped: stub };
});

const PROPS = {
  inep: "11000040",
  escola: {
    nome: "EMEIEF PEQUENOS TALENTOS",
    municipio: "Porto Velho",
    uf: "RO",
    rede: "Municipal",
    ano_censo: 2025,
  },
  resumo: {
    matriculas: 211,
    docentes: 9,
    salas_utilizadas: 6,
    alunos_por_sala: 35.2,
    regime_integral: 26,
  },
  matriculas: {
    total: 211,
    por_etapa: [
      { key: "pre_escola", label: "Pré-escola", value: 211 },
      { key: "creche", label: "Creche", value: 0 },
    ],
    por_turno: [{ key: "matutino", label: "Matutino", value: 211 }],
    por_modalidade: [{ key: "especial", label: "Educação especial", value: 27 }],
    por_faixa_etaria: [{ key: "4-5", label: "4 a 5 anos", value: 195 }],
    inclusao: { educacao_especial: 27, classes_comuns: 27, classes_exclusivas: 0 },
  },
  turmas: { salas_utilizadas: 6, salas_climatizadas: 6, salas_acessiveis: 6, nota: "nota" },
  docentes: {
    total: 9,
    por_formacao: [{ key: "superior", label: "Superior", value: 9 }],
    por_vinculo: [{ key: "concurso", label: "Concurso público", value: 9 }],
    por_disciplina: [{ key: "matematica", label: "Matemática", value: 3 }],
  },
  infraestrutura: {
    basica: [{ key: "agua_potavel", label: "Água potável", present: 1 }],
    espacos: [{ key: "biblioteca", label: "Biblioteca", present: 0 }],
  },
  equipamentos: {
    itens: [{ key: "computador", label: "Computador", present: 1 }],
    dispositivos: [{ key: "desktop_aluno", label: "Computadores (aluno)", present: 1, qtd: 10 }],
    conectividade: [{ key: "internet", label: "Internet", present: 1 }],
    sem_equipamentos: 0,
  },
  acessibilidade: [{ key: "rampas", label: "Rampas", present: 1 }],
};

describe("GestorPanel", () => {
  it("exibe o cabeçalho da escola e os cartões de resumo", () => {
    render(GestorPanel, { props: PROPS });

    expect(screen.getByText("EMEIEF PEQUENOS TALENTOS")).toBeInTheDocument();
    expect(screen.getByText(/Porto Velho/)).toBeInTheDocument();
    expect(screen.getAllByText("Matrículas").length).toBeGreaterThan(0);
    expect(screen.getAllByText("35,2").length).toBeGreaterThan(0);
  });

  it("renderiza as cinco seções e os gráficos", () => {
    render(GestorPanel, { props: PROPS });

    for (const titulo of [
      "Docentes",
      "Infraestrutura",
      "Equipamentos",
      "Acessibilidade",
    ]) {
      expect(screen.getAllByText(titulo).length).toBeGreaterThan(0);
    }
    const stubs = document.querySelectorAll('[data-testid="carbon-chart-stub"]');
    expect(stubs.length).toBeGreaterThanOrEqual(3);
  });

  it("mostra itens ausentes e presentes na infraestrutura", () => {
    render(GestorPanel, { props: PROPS });

    expect(screen.getByText("Água potável")).toBeInTheDocument();
    expect(screen.getByText("Biblioteca")).toBeInTheDocument();
    expect(screen.getAllByRole("img").length).toBeGreaterThan(0);
  });

  it("inclui a seção de escolas similares no painel", () => {
    render(GestorPanel, { props: PROPS });

    expect(screen.getAllByText("Escolas similares").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByRole("button", { name: /Buscar escolas similares/ })).toBeInTheDocument();
  });
});
