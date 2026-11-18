// src/features/schools/components/panel/SimilarSchools.test.js
// #413: sem alguma nota, a escola fica fora da comparação, e a lista vazia
// diz por quê (ausência não é 0, #154).
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import SimilarSchools from "./SimilarSchools.svelte";

describe("SimilarSchools", () => {
  it("sem semelhantes e sem motivo: mensagem genérica", () => {
    render(SimilarSchools, { schools: [] });
    expect(screen.getByText(/Nenhuma escola semelhante encontrada/)).toBeTruthy();
    expect(screen.queryByText(/Sem dado para comparar/)).toBeNull();
  });

  it('motivo "sem_dado": diz que falta nota, não que não há semelhantes', () => {
    render(SimilarSchools, { schools: [], motivo: "sem_dado" });
    expect(screen.getByText(/Sem dado para comparar/)).toBeTruthy();
    expect(screen.getByText(/nota zero/)).toBeTruthy();
    expect(screen.queryByText(/Nenhuma escola semelhante encontrada/)).toBeNull();
  });

  it("com semelhantes: lista as escolas, sem mensagem", () => {
    render(SimilarSchools, {
      schools: [
        { id_escola: 1, nome: "Escola Vizinha", rede: "municipal", matriculas: 100, etapas: {} },
      ],
      motivo: null,
    });
    expect(screen.getByText("Escola Vizinha")).toBeTruthy();
    expect(screen.queryByText(/Sem dado para comparar/)).toBeNull();
  });

  it("sem distância (caminho de reserva): sem número; explica o critério (#421)", () => {
    render(SimilarSchools, {
      schools: [
        { id_escola: 1, nome: "Escola Vizinha", rede: "municipal", matriculas: 100, etapas: {}, distancia: null, notas: [] },
      ],
    });
    expect(screen.queryByText(/^a [0-9]/)).toBeNull();
    expect(screen.getByText(/ao menos uma etapa de ensino em comum/)).toBeTruthy();
    expect(screen.getByText(/distância euclidiana, em\s+pontos/)).toBeTruthy();
  });

  it("mostra a distância em pontos e as notas ao lado das da escola (#487)", () => {
    render(SimilarSchools, {
      schools: [
        {
          id_escola: 1, nome: "Escola Vizinha", rede: "municipal", matriculas: 100, etapas: {},
          distancia: 1.56,
          notas: [
            { id: "score_infraestrutura", rotulo: "Infraestrutura", valor: 7.39, escola: 8.22 },
            { id: "score_capacidade_gestora", rotulo: "Gestão", valor: 7, escola: 7.07 },
          ],
        },
        { id_escola: 2, nome: "Outra", rede: "municipal", matriculas: 10, etapas: {}, distancia: 6.31, notas: [] },
      ],
    });
    expect(screen.getByText("a 1,6 ponto")).toBeTruthy();
    expect(screen.getByText("a 6,3 pontos")).toBeTruthy();
    expect(screen.getByText("Infraestrutura")).toBeTruthy();
    expect(screen.getByText("7,4")).toBeTruthy();
    expect(screen.getByText("8,2")).toBeTruthy();
  });
});
