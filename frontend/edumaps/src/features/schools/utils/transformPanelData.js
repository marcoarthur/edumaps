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

  // #510 (RA-01): a API manda cada etapa/item com o estado (1 tem, 0 não
  // tem, null sem dado), com as chaves de ETAPAS_ORDER/INFRA_ORDER
  // (t/06-tools/painel_chaves.t confere no backend). Sem dado fica null
  // (n/d), nunca false (#154).
  const estado = (obj, key) => {
    const v = obj?.[key];
    return v === null || v === undefined ? null : Boolean(Number(v));
  };
  const infraApi = apiData.escola.infraestrutura || {};

  const school = {
    id_escola: apiData.escola.id_escola,
    nome: apiData.escola.nome || apiData.escola.no_entidade, // fallback
    municipio: apiData.escola.municipio,
    uf: apiData.escola.uf,
    rede: apiData.escola.rede?.toLowerCase() || "municipal",
    matriculas: apiData.escola.matriculas ?? null,
    anoCenso: apiData.escola.ano_censo ?? null,
    latitude: apiData.escola.latitude ?? null,
    longitude: apiData.escola.longitude ?? null,
    etapas: Object.fromEntries(
      etapasKeys.map((key) => [key, estado(apiData.escola.etapas, key)]),
    ),
    infraestrutura: Object.fromEntries(
      infraKeys.map((key) => [key, estado(infraApi, key)]),
    ),
    // esgoto/energia: "rede_publica" ou "outra_solucao" (fossa, gerador…)
    infraDetalhe: { ...(infraApi.detalhe || {}) },
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

    // #487 (RL-02): a distância agora é a euclidiana entre as seis notas, em
    // pontos da escala de 0 a 10, e se lê. Vem com as notas da vizinha ao
    // lado das da escola. O caminho de reserva do backend não manda a
    // distância (outra métrica): aí o cartão fica sem número.
    const distancia =
      item.distancia === null || item.distancia === undefined
        ? null
        : Number(item.distancia);
    const notas = (item.notas || []).map((n) => ({
      id: n.id,
      rotulo: n.rotulo,
      valor: n.valor === null || n.valor === undefined ? null : Number(n.valor),
      escola: n.escola === null || n.escola === undefined ? null : Number(n.escola),
    }));

    return {
      id_escola: record.co_entidade,
      nome: record.no_entidade,
      rede,
      matriculas: record.qt_matriculas || record.matriculas || 0, // pode não existir no censo
      etapas,
      distancia,
      notas,
      latitude: record.latitude,
      longitude: record.longitude,
    };
  });

  // 4. Série de desempenho (IDEB observado por etapa/ano). Vem só quando a
  //    escola tem histórico em clean.ideb_notas_escolas.
  const desempenho = (apiData.desempenho || []).map((row) => ({
    ano: Number(row.ano),
    etapa: row.etapa,
    ideb_observado:
      row.ideb_observado == null ? null : Number(row.ideb_observado),
  }));

  // Motivo de não haver escolas semelhantes (#413): "sem_dado" quando falta
  // alguma das notas da escola. Ausência não é 0 (#154): a escola fica fora
  // da comparação em vez de ser comparada com um 0 no lugar da nota.
  const similarSchoolsMotivo = apiData.similar_schools_motivo ?? null;

  return { school, indicators, similarSchools, similarSchoolsMotivo, desempenho };
}
