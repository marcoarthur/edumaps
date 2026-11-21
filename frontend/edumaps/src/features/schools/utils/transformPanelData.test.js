// src/features/schools/utils/transformPanelData.test.js
import { describe, it, expect } from "vitest";
import { transformPanelData } from "./transformPanelData.js";

const API = {
  escola: {
    id_escola: "1",
    no_entidade: "Escola X",
    municipio: "Ubatuba",
    uf: "SP",
    rede: "Municipal",
    matriculas: 100,
    latitude: null,
    longitude: null,
    ano_censo: 2025,
    etapas: { creche: 0, pre_escola: 1, fundamental_i: 1, fundamental_ii: 0, ensino_medio: 0, eja: null, profissionalizante: 0 },
    infraestrutura: {
      agua_potavel: 1, energia: 0, esgoto: 1, coleta_lixo: 1, internet: null, biblioteca: 0,
      laboratorio_ciencias: 0, laboratorio_informatica: 0, quadra_esportes: 1, acessibilidade: 1,
      alimentacao: 1, detalhe: { esgoto: "outra_solucao" },
    },
  },
  indicators: {},
  similar_schools: [],
  desempenho: [
    {
      ano: "2021",
      etapa: "fundamental_ii",
      ideb_observado: "5.2",
      nota_media: "6.1",
    },
    {
      ano: "2023",
      etapa: "fundamental_ii",
      ideb_observado: null,
      nota_media: "5.0",
    },
  ],
};

describe("transformPanelData", () => {
  it("#510: etapas e infraestrutura com o estado de cada item (n/d como null)", () => {
    const { school } = transformPanelData(API);
    expect(school.etapas.pre_escola).toBe(true);
    expect(school.etapas.creche).toBe(false);
    expect(school.etapas.eja).toBeNull();
    expect(school.infraestrutura.quadra_esportes).toBe(true);
    expect(school.infraestrutura.acessibilidade).toBe(true);
    expect(school.infraestrutura.energia).toBe(false);
    expect(school.infraestrutura.internet).toBeNull();
    expect(school.infraDetalhe).toEqual({ esgoto: "outra_solucao" });
    expect(school.matriculas).toBe(100);
    expect(school.anoCenso).toBe(2025);
  });

  it("escolas semelhantes: distância em pontos e notas comparadas (#487)", () => {
    const { similarSchools } = transformPanelData({
      ...API,
      similar_schools: [
        {
          record: { co_entidade: 2, no_entidade: "Vizinha", tp_rede_local: 3 },
          distance: 1.5634,
          distancia: 1.56,
          notas: [{ id: "score_infraestrutura", rotulo: "Infraestrutura", valor: "7.39", escola: "8.22" }],
        },
        { record: { co_entidade: 3, no_entidade: "Reserva", tp_rede_local: 3 }, distance: 4 },
      ],
    });
    expect(similarSchools[0].distancia).toBe(1.56);
    expect(similarSchools[0].notas).toEqual([
      { id: "score_infraestrutura", rotulo: "Infraestrutura", valor: 7.39, escola: 8.22 },
    ]);
    // caminho de reserva do backend: outra métrica, sem a distância em pontos
    expect(similarSchools[1].distancia).toBeNull();
    expect(similarSchools[1].notas).toEqual([]);
  });

  it("normaliza a série de desempenho (ano/ideb como número)", () => {
    const { desempenho } = transformPanelData(API);

    expect(desempenho).toEqual([
      { ano: 2021, etapa: "fundamental_ii", ideb_observado: 5.2 },
      { ano: 2023, etapa: "fundamental_ii", ideb_observado: null },
    ]);
  });

  it("retorna lista vazia quando a API não traz desempenho", () => {
    const { desempenho } = transformPanelData({ ...API, desempenho: undefined });
    expect(desempenho).toEqual([]);
  });

  it("repassa o motivo de não haver semelhantes (#413)", () => {
    expect(transformPanelData(API).similarSchoolsMotivo).toBeNull();
    expect(
      transformPanelData({ ...API, similar_schools_motivo: "sem_dado" })
        .similarSchoolsMotivo,
    ).toBe("sem_dado");
  });
});
