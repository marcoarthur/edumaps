import { describe, it, expect } from "vitest";
import { listaMeses, sufixoIncompletos, faixasMeses, textoAnoFolha, textoSalarioRede } from "./utils.js";

describe("meses incompletos da folha (#557)", () => {
  const SET = { nome: "setembro" };
  const OUT = { nome: "outubro" };
  it("lista em português", () => {
    expect(listaMeses([SET])).toBe("setembro");
    expect(listaMeses([SET, OUT])).toBe("setembro e outubro");
    expect(listaMeses([{ nome: "maio" }, SET, OUT])).toBe("maio, setembro e outubro");
    expect(listaMeses([])).toBe("");
  });
  it("sufixo da cobertura", () => {
    expect(sufixoIncompletos([SET, OUT])).toBe(" (setembro e outubro incompletos)");
    expect(sufixoIncompletos([SET])).toBe(" (setembro incompleto)");
    expect(sufixoIncompletos(undefined)).toBe("");
  });
});

describe("meses da folha por escola e da Secretaria (#558)", () => {
  it("intervalos de 3 ou mais meses", () => {
    expect(faixasMeses([3, 4, 5, 6, 7, 8])).toBe("de março a agosto");
    expect(faixasMeses([1, 2])).toBe("janeiro e fevereiro");
    expect(faixasMeses([1, 2, 5, 6, 7])).toBe("janeiro, fevereiro e de maio a julho");
    expect(faixasMeses([6])).toBe("junho");
  });
  it("o texto do ano na cobertura", () => {
    expect(textoAnoFolha({ meses: 8, escolas: 48 })).toBe("8 meses, 48 escolas; carga não registrada");
    expect(textoAnoFolha({ meses: 8, escolas: 48, carga: "2026-11-24" })).toBe("8 meses, 48 escolas; carga em 24/11/2026");
    expect(textoAnoFolha({ meses: 2, escolas: 168, meses_escola: [1, 2], meses_secretaria: [3, 4, 5, 6, 7, 8], incompletos: [{ nome: "junho" }] }))
      .toBe("por escola só em janeiro e fevereiro; de março a agosto, só o total da Secretaria; junho incompleto; 168 escolas; carga não registrada");
    expect(textoAnoFolha({ meses: 8, escolas: 0, incompletos: [{ nome: "julho" }] })).toBe("só o total da Secretaria; julho incompleto; carga não registrada");
    expect(textoAnoFolha({ meses: 12, escolas: 167, meses_escola: [1], meses_secretaria: [] , incompletos: [{ nome: "setembro" }] }))
      .toBe("12 meses (setembro incompleto), 167 escolas; carga não registrada");
  });
});

describe("salário do magistério da rede (#571)", () => {
  it("medianas, pessoas e a carga mais comum", () => {
    expect(textoSalarioRede({ pessoas: 2961, total: 6975, base: 2669, carga_comum: 18 })).toBe(
      "salário total R$ 6.975 e base R$ 2.669 (medianas por mês, sem dezembro, de 2.961 profissionais do magistério); carga mais comum: 18");
    expect(textoSalarioRede(null)).toBe("");
  });
  it("#572: avisa quando a carga não parece em horas", () => {
    expect(textoSalarioRede({ pessoas: 2961, total: 6975, base: 2669, carga_comum: 18, carga_suspeita: true }))
      .toContain("carga mais comum: 18 (não parece ser em horas semanais, e sim em aulas ou numa jornada parcial: as contas por 40 horas não valem aqui)");
    expect(textoSalarioRede({ pessoas: 10, total: 1, base: 1, carga_comum: 30, carga_suspeita: false })).not.toContain("não parece");
  });
});
