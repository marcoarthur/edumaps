// src/features/schools/utils/leituraPosicao.test.js
import { describe, it, expect } from "vitest";
import { leituraPosicao } from "./leituraPosicao.js";

describe("leituraPosicao (#541)", () => {
  it("1º lugar dividido: diz o lugar, não 'acima de 16%'", () => {
    const l = leituraPosicao({ posicao: 1, total: 81, empate: 68, abaixo: 13, percentil: 16 }, "no município");
    expect(l.frase).toBe("1º lugar, dividido com 67 escolas com o mesmo valor");
    expect(l.empate).toBeNull();
  });

  it("último lugar dividido: diz o lugar, não 'acima de 0%'", () => {
    const l = leituraPosicao({ posicao: 767, total: 1432, empate: 666, abaixo: 0, percentil: 0 });
    expect(l.frase).toBe("Último lugar, dividido com 665 escolas com o mesmo valor");
  });

  it("meio da lista com empate: a linha do empate e o 'acima de'", () => {
    const l = leituraPosicao({ posicao: 148, total: 382, empate: 106, abaixo: 129, percentil: 34 }, "no município");
    expect(l.empate).toBe("empatada com 105 escolas");
    expect(l.frase).toBe("Acima de 34% das outras escolas no município");
  });

  it("posição isolada: só o 'acima de'", () => {
    const l = leituraPosicao({ posicao: 76, total: 81, empate: 1, abaixo: 5, percentil: 4 }, "no município");
    expect(l.empate).toBeNull();
    expect(l.frase).toBe("Acima de 4% das outras escolas no município");
  });

  it("todas empatadas", () => {
    expect(leituraPosicao({ posicao: 1, total: 3, empate: 3, abaixo: 0, percentil: 0 }).frase)
      .toBe("Todas as 3 escolas têm o mesmo valor");
  });

  it("empate com uma só escola: singular", () => {
    expect(leituraPosicao({ posicao: 1, total: 10, empate: 2, abaixo: 8, percentil: 89 }).frase)
      .toBe("1º lugar, dividido com 1 escola com o mesmo valor");
  });
});
