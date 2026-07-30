/**
 * src/features/schools/utils/transformPanelData.js
 * Transforma a resposta bruta do endpoint /api/school/:id/panel/info
 * no formato esperado pelo componente SchoolPanel.
 */
export function transformPanelData(apiData) {
  // 1. Transformar escola
  const etapasKeys = [
    "creche",
    "pre_escola",
    "fundamental_i",
    "fundamental_ii",
    "ensino_medio",
    "eja",
    "profissionalizante",
  ];
  const infraKeys = [
    "agua_potavel",
    "energia",
    "esgoto",
    "coleta_lixo",
    "internet",
    "biblioteca",
    "laboratorio_ciencias",
    "laboratorio_informatica",
    "quadra_esportes",
    "acessibilidade",
    "alimentacao",
  ];

  const school = {
    id_escola: apiData.escola.id_escola,
    nome: apiData.escola.nome || apiData.escola.no_entidade, // fallback
    municipio: apiData.escola.municipio,
    uf: apiData.escola.uf,
    rede: apiData.escola.rede?.toLowerCase() || "municipal",
    matriculas: apiData.escola.matriculas,
    latitude: apiData.escola.latitude ?? null,
    longitude: apiData.escola.longitude ?? null,
    etapas: Object.fromEntries(
      etapasKeys.map((key) => [key, apiData.escola.etapas.includes(key)]),
    ),
    infraestrutura: Object.fromEntries(
      infraKeys.map((key) => [
        key,
        apiData.escola.infraestrutura.includes(key),
      ]),
    ),
  };

  // 2. Transformar indicadores (objeto -> array)
  const indicators = Object.entries(apiData.indicators || {})
    .filter(([_, data]) => data !== null)
    .map(([id, data]) => ({
      indicador: data.indicador,
      ano: data.ano,
      ranking: data.ranking,
    }));

  // 3. Transformar escolas semelhantes
  const similarSchools = (apiData.similar_schools || []).map((item) => {
    const record = item.record;
    // Mapear rede (tp_rede_local: 3=municipal, 1=estadual, 2=privada)
    const redeMap = { 3: "municipal", 1: "estadual", 2: "privada" };
    const rede = redeMap[record.tp_rede_local] || "municipal";

    // Inferir etapas a partir dos campos in_comum_*
    const etapas = {
      creche: !!record.in_comum_creche,
      pre_escola: !!record.in_comum_pre,
      fundamental_i: !!record.in_comum_fund_ai,
      fundamental_ii: !!record.in_comum_fund_af,
      ensino_medio: !!record.in_comum_medio_medio,
      eja: !!record.in_eja,
      profissionalizante: !!record.in_profissionalizante,
    };

    // Usar distance como indicador principal (ou deixar null)
    const mainIndicator = {
      label: "Distância",
      valor: item.distance.toFixed(2),
    };

    return {
      id_escola: record.co_entidade,
      nome: record.no_entidade,
      rede,
      matriculas: record.qt_matriculas || record.matriculas || 0, // pode não existir no censo
      etapas,
      indicador_principal: mainIndicator,
      latitude: record.latitude,
      longitude: record.longitude,
    };
  });

  return { school, indicators, similarSchools };
}
