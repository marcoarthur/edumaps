import { describe, it, expect } from "vitest";
import { listaMeses, sufixoIncompletos, faixasMeses, textoAnoFolha, textoSalarioRede, textoPisoRede, textoPisoPerfil, textoSalarioEscola } from "./utils.js";

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

describe("piso na rede inteira (#575)", () => {
  it("a contagem com a Secretaria e o aviso", () => {
    const t = textoPisoRede({ piso: 5130.63, abaixo_piso: 1559, abaixo_piso_so_secretaria: 1421 }, 2026);
    expect(t).toContain("Abaixo do piso de 2026 (R$ 5.130,63 por 40 horas) no mês típico, entre quem recebeu 3 meses ou mais: 1.559 profissionais do magistério, 1.421 deles só no total da Secretaria.");
    expect(t).toContain("Não é a verificação legal do piso");
  });
  it("#597: por situação e o perfil de quem fica abaixo", () => {
    const t = textoPisoRede({ piso: 5130.63, abaixo_piso: 1559, abaixo_piso_so_secretaria: 1421,
      abaixo_piso_situacao: { efetivo: 137, temporario: 1422, outros: 0 },
      abaixo_piso_perfil: { carga: 30, base: 3212.71, piso_proporcional: 3847.97 } }, 2026);
    expect(t).toContain("Deles, 1.422 temporários e 137 efetivos (pela situação dos mais meses no ano).");
    expect(t).toContain("O mais comum entre eles: 30 horas, com salário base mediano de R$ 3.212,71 por mês (o piso proporcional a 30 horas é R$ 3.847,97).");
    expect(t.indexOf("Deles")).toBeLessThan(t.indexOf("Não é a verificação legal"));
  });
  it("#597: 40 horas sem o proporcional; um só de cada", () => {
    const t = textoPisoPerfil({ abaixo_piso: 3, abaixo_piso_situacao: { efetivo: 1, temporario: 1, outros: 1 },
      abaixo_piso_perfil: { carga: 40, base: 3500, piso_proporcional: 5130.63 } });
    expect(t).toContain("Deles, 1 temporário, 1 efetivo e 1 de outra situação");
    expect(t).not.toContain("proporcional");
    expect(textoPisoPerfil({ abaixo_piso: 0, abaixo_piso_situacao: { efetivo: 0, temporario: 0, outros: 0 } })).toBe("");
    expect(textoPisoPerfil({ abaixo_piso: 5 })).toBe("");
  });
  it("sem contagem, nada", () => {
    expect(textoPisoRede({ piso: 5130.63, abaixo_piso: null }, 2026)).toBe("");
    expect(textoPisoRede(null, 2026)).toBe("");
  });
});

describe("mês incompleto com a carga registrada (#576)", () => {
  it("diz que já está na planilha do SIOPE", () => {
    expect(sufixoIncompletos([{ nome: "setembro" }, { nome: "outubro" }], "2026-11-24")).toBe(" (setembro e outubro incompletos já na planilha do SIOPE)");
    expect(textoAnoFolha({ meses: 12, escolas: 167, incompletos: [{ nome: "setembro" }], carga: "2026-11-24" }))
      .toBe("12 meses (setembro incompleto já na planilha do SIOPE), 167 escolas; carga em 24/11/2026");
  });
});

describe("salário da escola (#589)", () => {
  it("mesma conta da rede e a diferença no total", () => {
    expect(textoSalarioEscola({ pessoas: 36, total: 9341, base: 6100, carga_comum: 30 }, { total: 7186 }))
      .toBe("salário total R$ 9.341 e base R$ 6.100 (medianas por mês, sem dezembro, de 36 profissionais do magistério); carga mais comum: 30; 30% acima da rede no salário total");
    expect(textoSalarioEscola({ pessoas: 2, total: 1000, base: 600 }, { total: 1250 })).toContain("20% abaixo da rede");
    expect(textoSalarioEscola(null, { total: 1 })).toBe("");
  });
});
