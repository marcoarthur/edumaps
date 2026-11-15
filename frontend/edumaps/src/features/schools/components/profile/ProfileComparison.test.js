// src/features/schools/components/profile/ProfileComparison.test.js
// #421 (AN-02): o destaque e o ⚠ seguem o `atencao` do motor (que já
// considera o sentido do indicador); a tabela diz onde menor é melhor.
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import ProfileComparison from "./ProfileComparison.svelte";

const IND = [
  {
    indicador: "prop_sem_especializacao",
    label: "Docentes sem especialização",
    escola: 0.04, municipio: 0.305, rede: 0.482, brasil: 0.538, cluster: 0.294,
    quartil_no_cluster: 1, atencao: false, direcao: "menor",
  },
  {
    indicador: "prop_efetivos",
    label: "Docentes efetivos (concursados)",
    escola: 0.2, municipio: 0.4, rede: 0.5, brasil: 0.4, cluster: 0.42,
    quartil_no_cluster: 1, atencao: true, direcao: "maior",
  },
];

describe("ProfileComparison (#421)", () => {
  it("Q1 em indicador 'menor é melhor' não leva ⚠ nem destaque", () => {
    render(ProfileComparison, { indicadores: IND });
    const linhaSem = screen.getByText("Docentes sem especialização").closest("tr");
    expect(linhaSem.className).toMatch(/bg-white/);
    expect(linhaSem.textContent).not.toMatch(/⚠/);
    expect(linhaSem.textContent).toMatch(/menor é melhor/);

    const linhaEfet = screen.getByText("Docentes efetivos (concursados)").closest("tr");
    expect(linhaEfet.className).toMatch(/bg-amber-50/);
    expect(linhaEfet.textContent).toMatch(/⚠/);
    expect(linhaEfet.textContent).not.toMatch(/menor é melhor/);
  });

  it("legenda explica o lado ruim por sentido", () => {
    render(ProfileComparison, { indicadores: IND });
    expect(screen.getByText(/no Q4 se menor é melhor/)).toBeInTheDocument();
  });
});
