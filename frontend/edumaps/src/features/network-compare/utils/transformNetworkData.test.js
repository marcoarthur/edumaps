// src/features/network-compare/utils/transformNetworkData.test.js
import { describe, it, expect } from "vitest";
import {
  NETWORK_PERFORMANCE_FIXTURE,
  NETWORK_SUMMARY_FIXTURE,
} from "../mocks/fixtures.js";
import {
  buildAtendimentoInfantil,
  formatPercent,
  networkCompareUrl,
  networkProfileUrl,
  buildIdedTimeline,
  idebTooltipText,
  buildShareDonut,
  buildShareRadarData,
  buildStageBars,
  buildTableRows,
  buildVolumeRadarData,
  formatDecimal,
  formatInt,
  municipalityHeader,
  redeLabel,
} from "./transformNetworkData.js";

describe("transformNetworkData", () => {
  it("normaliza o nome da rede em rótulo conhecido", () => {
    expect(redeLabel("estadual")).toBe("Estadual");
    expect(redeLabel("Municipal")).toBe("Municipal");
    expect(redeLabel("privada")).toBe("Privada");
    expect(redeLabel("desconhecida")).toBe("Desconhecida");
  });

  it("extrai o cabeçalho do município da primeira entrada", () => {
    expect(municipalityHeader(NETWORK_SUMMARY_FIXTURE)).toEqual({
      no_municipio: "Sertãozinho",
      sg_uf: "SP",
      no_regiao: "Sudeste",
    });
    expect(municipalityHeader([])).toEqual({
      no_municipio: "—",
      sg_uf: "",
      no_regiao: "",
    });
  });

  it("gera o radar de perfil com participação % por rede", () => {
    const rows = buildShareRadarData(NETWORK_SUMMARY_FIXTURE);
    expect(rows).toHaveLength(NETWORK_SUMMARY_FIXTURE.length * 7);

    const privada = rows.filter((r) => r.group === "Privada");
    expect(privada.map((r) => r.stage)).toEqual([
      "Creche",
      "Pré-escola",
      "Fundamental I",
      "Fundamental II",
      "Médio",
      "EJA",
      "Profissionalizante",
    ]);

    // 400 matrículas em creche de {total de stage columns} da privada.
    // Obs: a soma das colunas de etapa pode divergir de total_matriculas
    // (aluno pode ser contado em mais de uma etapa no censo).
    const privadaFixtures = NETWORK_SUMMARY_FIXTURE.find(
      (n) => n.rede === "privada",
    );
    const privadaStageTotal = privadaFixtures.matriculas_creche +
      privadaFixtures.matriculas_pre +
      privadaFixtures.matriculas_fundamental_ai +
      privadaFixtures.matriculas_fundamental_af +
      privadaFixtures.matriculas_medio +
      privadaFixtures.matriculas_eja +
      privadaFixtures.matriculas_profissional;
    // #516: creche e pré-escola separadas (400 + 588 = 988 da infantil)
    const creche = privada.find((r) => r.stage === "Creche");
    expect(creche.value).toBeCloseTo((400 / privadaStageTotal) * 100, 1);
    expect(creche.matricula).toBe(400);
    expect(privada.find((r) => r.stage === "Pré-escola").matricula).toBe(588);

    // Somatório da participação = 100% por rede
    const total = privada.reduce((acc, r) => acc + r.value, 0);
    expect(total).toBeCloseTo(100, 1);
  });

  it("gera o radar de volume normalizado pelo maior valor da etapa", () => {
    const rows = buildVolumeRadarData(NETWORK_SUMMARY_FIXTURE);
    const infantil = rows.filter((r) => r.stage === "Infantil");
    const max = Math.max(...infantil.map((r) => r.matricula));

    for (const row of infantil) {
      expect(row.value).toBeCloseTo((row.matricula / max) * 100, 1);
      expect(row.value).toBeGreaterThanOrEqual(0);
      expect(row.value).toBeLessThanOrEqual(100.1);
    }
  });

  it("gera barras agrupadas para todas as etapas × redes", () => {
    const rows = buildStageBars(NETWORK_SUMMARY_FIXTURE);
    expect(rows).toHaveLength(NETWORK_SUMMARY_FIXTURE.length * 7);
    expect(rows[0]).toMatchObject({ group: "Federal", key: "Creche" });
  });

  it("gera donut de participação ignorando redes sem valor", () => {
    const rows = buildShareDonut(NETWORK_SUMMARY_FIXTURE, "total_escolas");
    expect(rows).toHaveLength(4);
    expect(rows.find((r) => r.group === "Municipal").value).toBe(46);

    const zeroes = buildShareDonut(NETWORK_SUMMARY_FIXTURE, "ideb_medio");
    expect(zeroes.some((r) => r.value > 0)).toBe(true);
  });

  it("monta a série IDEB filtrando entradas sem resultado", () => {
    const rows = buildIdedTimeline(NETWORK_PERFORMANCE_FIXTURE);
    expect(rows.length).toBe(NETWORK_PERFORMANCE_FIXTURE.length);
    expect(rows.every((r) => r.value > 0)).toBe(true);
    expect(rows[0]).toMatchObject({ group: "Estadual · Ensino Médio", key: "2017" });
    expect(rows.some((r) => r.group === "Municipal · Fundamental II")).toBe(true);
  });

  it("prepara as linhas da tabela com rótulo de rede amigável", () => {
    const rows = buildTableRows(NETWORK_SUMMARY_FIXTURE);
    expect(rows.map((r) => r.rede)).toEqual([
      "Federal",
      "Estadual",
      "Municipal",
      "Privada",
    ]);
  });

  it("formata números para pt-BR", () => {
    expect(formatInt(15264)).toBe("15.264");
    expect(formatInt(null)).toBe("0");
    expect(formatDecimal("1.4")).toBe("1,4");
    expect(formatDecimal(3, 2)).toBe("3,00");
  });
});
describe("URLs do perfil e da comparação de redes", () => {
  it("perfil de uma rede leva o município e o código da rede", () => {
    expect(networkProfileUrl("3551702", 3)).toBe(
      "/municipio/perfil?codigo_ibge=3551702&dependencia=3",
    );
  });

  it("perfil de todas as redes não leva filtro de rede", () => {
    expect(networkProfileUrl(3551702)).toBe("/municipio/perfil?codigo_ibge=3551702");
  });

  it("voltar para a comparação usa codigo_ibge (o que a página lê)", () => {
    expect(networkCompareUrl("3551702")).toBe(
      "/municipio/compare?codigo_ibge=3551702",
    );
  });
});

describe("linha do IDEB: escolas por ponto (#479)", () => {
  it("leva numero_escolas para o ponto e o tooltip diz quantas", () => {
    const rows = buildIdedTimeline([{ rede: "Estadual", etapa: "ensino_medio", ano: 2023, numero_escolas: 69, ideb_medio: 3.72 }]);
    expect(rows[0]).toMatchObject({ key: "2023", value: 3.72, escolas: 69 });
    expect(idebTooltipText(rows[0])).toBe("Estadual · Ensino Médio, 2023: 3,72 (69 escolas com IDEB)");
    expect(idebTooltipText({ ...rows[0], escolas: 1 })).toContain("(1 escola com IDEB)");
    expect(idebTooltipText({ ...rows[0], escolas: null })).toBe("Estadual · Ensino Médio, 2023: 3,72");
  });
});

describe("buildAtendimentoInfantil (#533)", () => {
  it("taxa de todas as redes, da municipal e o teto com as conveniadas", () => {
    const a = buildAtendimentoInfantil(NETWORK_SUMMARY_FIXTURE);
    expect(a.ano).toBe(2022);
    // creche: 2106 municipal + 400 privada = 2506 de 6000 crianças
    expect(a.creche.populacao).toBe(6000);
    expect(a.creche.todas).toBeCloseTo(2506 / 6000);
    expect(a.creche.municipal).toBeCloseTo(2106 / 6000);
    expect(a.creche.teto).toBeCloseTo((2106 + 210) / 6000);
    expect(a.creche.meta).toBe(0.5);
    // pré-escola: passa de 100% com todas as redes
    expect(a.pre.todas).toBeCloseTo(3488 / 3200);
    expect(a.pre.teto).toBeCloseTo((2900 + 45) / 3200);
    expect(formatPercent(a.pre.todas)).toBe("109,0%");
  });

  it("sem conveniadas, sem teto", () => {
    const nets = NETWORK_SUMMARY_FIXTURE.map((n) => ({
      ...n, matriculas_creche_conveniada: 0, matriculas_pre_conveniada: 0,
    }));
    const a = buildAtendimentoInfantil(nets);
    expect(a.creche.teto).toBeNull();
    expect(a.pre.teto).toBeNull();
  });

  it("sem a população carregada, null", () => {
    const nets = NETWORK_SUMMARY_FIXTURE.map((n) => ({ ...n, populacao_0_3: null, populacao_4_5: null }));
    expect(buildAtendimentoInfantil(nets)).toBeNull();
    expect(buildAtendimentoInfantil([])).toBeNull();
  });
});
