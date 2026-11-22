// src/shared/utils/sentidoIndicador.test.js
import { describe, it, expect } from "vitest";
import { sentidoIndicador, diferencaFavoravel } from "./sentidoIndicador.js";

describe("sentidoIndicador (#421, AN-02)", () => {
  it("sem formação continuada e aluno/docente: menor é melhor", () => {
    expect(sentidoIndicador("prop_sem_especializacao")).toBe("menor");
    expect(sentidoIndicador("ratio_aluno_docente")).toBe("menor");
    expect(sentidoIndicador("ideb_observado")).toBe("maior");
  });

  it("a direção do payload prevalece", () => {
    expect(sentidoIndicador("ideb_observado", "menor")).toBe("menor");
    expect(sentidoIndicador("prop_sem_especializacao", "x")).toBe("menor");
  });

  it("queda de 'sem formação continuada' é favorável; queda do IDEB não", () => {
    expect(diferencaFavoravel("prop_sem_especializacao", -0.436)).toBe(true);
    expect(diferencaFavoravel("ratio_aluno_docente", -2.7)).toBe(true);
    expect(diferencaFavoravel("ratio_aluno_docente", 1)).toBe(false);
    expect(diferencaFavoravel("ideb_observado", 0.8)).toBe(true);
    expect(diferencaFavoravel("ideb_observado", -0.8)).toBe(false);
  });

  it("zero ou ausente não é bom nem ruim", () => {
    expect(diferencaFavoravel("ideb_observado", 0)).toBeNull();
    expect(diferencaFavoravel("ideb_observado", null)).toBeNull();
    expect(diferencaFavoravel("ideb_observado", "")).toBeNull();
  });
});
