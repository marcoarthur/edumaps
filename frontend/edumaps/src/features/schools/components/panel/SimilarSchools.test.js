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
});
