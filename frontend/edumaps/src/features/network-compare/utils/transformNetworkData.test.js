// src/features/network-compare/utils/transformNetworkData.test.js
import { describe, it, expect } from "vitest";
import {
  NETWORK_PERFORMANCE_FIXTURE,
  NETWORK_SUMMARY_FIXTURE,
} from "../mocks/fixtures.js";
import {
  buildIdedTimeline,
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
    expect(rows).toHaveLength(NETWORK_SUMMARY_FIXTURE.length * 6);

    const privada = rows.filter((r) => r.group === "Privada");
    expect(privada.map((r) => r.stage)).toEqual([
      "Infantil",
      "Fundamental I",
      "Fundamental II",
      "Médio",
      "EJA",
      "Profissionalizante",
    ]);

    // 988 matrículas infantil de {total de stage columns} da privada.
    // Obs: a soma das colunas de etapa pode divergir de total_matriculas
    // (aluno pode ser contado em mais de uma etapa no censo).
    const privadaFixtures = NETWORK_SUMMARY_FIXTURE.find(
      (n) => n.rede === "privada",
    );
    const privadaStageTotal = privadaFixtures.matriculas_infantil +
      privadaFixtures.matriculas_fundamental_ai +
      privadaFixtures.matriculas_fundamental_af +
      privadaFixtures.matriculas_medio +
      privadaFixtures.matriculas_eja +
      privadaFixtures.matriculas_profissional;
    const infantil = privada.find((r) => r.stage === "Infantil");
    expect(infantil.value).toBeCloseTo((988 / privadaStageTotal) * 100, 1);
    expect(infantil.matricula).toBe(988);

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
    expect(rows).toHaveLength(NETWORK_SUMMARY_FIXTURE.length * 6);
    expect(rows[0]).toMatchObject({ group: "Federal", key: "Infantil" });
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