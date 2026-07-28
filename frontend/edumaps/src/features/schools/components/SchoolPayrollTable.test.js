import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import SchoolPayrollTable from "./SchoolPayrollTable.svelte";

describe("SchoolPayrollTable", () => {
  const mockData = [
    {
      ano: 2025,
      carga_horaria: 40,
      categoria: "Docente habilitado em curso de pedagogia",
      cod_inep: 35224662,
      cod_municipio: "354990",
      cpf: "xxx.076.068-xx",
      escola: "LADIEL BENEDITO DE CARVALHO PROF EMEI",
      mes: "Outubro",
      nome_profissional: "ALINE GABRIELA MARTINS DOS SANTOS",
      rede: "Municipal",
      salario_base: "4388.40",
      salario_fundeb_max: "4388.40",
      salario_fundeb_min: "0.00",
      salario_outros: "0.00",
      salario_total: "4388.40",
      segmento_ensino: "Pre-escola",
      situacao: "Temporário",
      tipo: "Profissionais do magistério",
    },
    {
      ano: 2025,
      carga_horaria: 40,
      categoria: "Docente pós-graduado em cursos de especialização",
      cod_inep: 35224662,
      cod_municipio: "354990",
      cpf: "xxx.594.491-xx",
      escola: "LADIEL BENEDITO DE CARVALHO PROF EMEI",
      mes: "Outubro",
      nome_profissional: "ALCIONE DOS SANTOS FERNANDES",
      rede: "Municipal",
      salario_base: "5136.00",
      salario_fundeb_max: "5793.41",
      salario_fundeb_min: "0.00",
      salario_outros: "0.00",
      salario_total: "5793.41",
      segmento_ensino: "Pre-escola",
      situacao: "Efetivo",
      tipo: "Profissionais do magistério",
    },
  ];

  it("renders the table with caption and data", () => {
    render(SchoolPayrollTable, {
      payrollData: mockData,
      caption: "Teste de Folha",
      footer: "Total de 2 registros",
    });

    expect(screen.getByText("Teste de Folha")).toBeInTheDocument();
    expect(screen.getByText("Total de 2 registros")).toBeInTheDocument();
    expect(
      screen.getByText("ALINE GABRIELA MARTINS DOS SANTOS"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("ALCIONE DOS SANTOS FERNANDES"),
    ).toBeInTheDocument();
  });

  it("formats currency values", () => {
    render(SchoolPayrollTable, { payrollData: mockData });

    // Obtém todas as células da tabela
    const allCells = screen.getAllByRole("cell");

    // Filtra células que contêm "R$ 4.388,40" ignorando espaços
    const cellsWith4388 = allCells.filter((cell) => {
      const text = cell.textContent?.replace(/\s/g, "") ?? "";
      return text.includes("R$4.388,40");
    });
    expect(cellsWith4388.length).toBe(3);

    // Filtra células que contêm "R$ 5.793,41"
    const cellsWith5793 = allCells.filter((cell) => {
      const text = cell.textContent?.replace(/\s/g, "") ?? "";
      return text.includes("R$5.793,41");
    });
    expect(cellsWith5793.length).toBe(2);

    // Verifica "R$ 5.136,00" (aparece apenas uma vez)
    const cellsWith5136 = allCells.filter((cell) => {
      const text = cell.textContent?.replace(/\s/g, "") ?? "";
      return text.includes("R$5.136,00");
    });
    expect(cellsWith5136.length).toBe(1);
  });

  it("displays carga horária with suffix", () => {
    render(SchoolPayrollTable, { payrollData: mockData });

    // 40h aparece duas vezes
    const cargaElements = screen.getAllByText("40h");
    expect(cargaElements.length).toBe(2);
  });

  it("shows fallback when data is empty", () => {
    render(SchoolPayrollTable, { payrollData: [] });
    const rows = screen.queryAllByRole("row");
    expect(rows.length).toBe(1); // apenas cabeçalho
  });
});
