// src/features/schools/utils/transformProfileData.js
//
// Transforma a resposta do `GET /api/school/:cod_inep/profile` no formato
// que os componentes do painel esperam.
//
// O serviço analítico (Plumber) pode serializar uma tabela de uma linha
// como objeto em vez de array (auto_unbox) — `asArray` normaliza os dois
// formatos, de modo que os componentes sempre recebem arrays.

/** @returns {Array} Sempre um array (objeto único vira [objeto]). */
export function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") return [value];
  return [];
}

export const CLUSTER_SOURCE_LABELS = {
  persisted: "cluster da base",
  fallback_kmeans: "cluster estimado (município)",
  contexto_municipio: "grupo de contexto (município)",
  none: "sem cluster",
};

export const PEERS_SOURCE_LABELS = {
  // #495: o mesmo contexto do grupo de referência, no município inteiro
  contexto_municipio: "contexto, no município inteiro",
  // perfis em cache antigo (até a regra 5)
  similarity_pairs: "pares da base (Gower)",
  gower_municipio: "Gower calculado no município",
};

/**
 * Diferença de IDEB entre uma escola similar e a escola do perfil (#495),
 * com sinal e uma casa: "+1,2", "−0,4", "0,0". `null` se faltar um dos dois.
 */
export function idebDiferencaTexto(peerIdeb, escolaIdeb) {
  if (peerIdeb === null || peerIdeb === undefined || peerIdeb === "") return null;
  if (escolaIdeb === null || escolaIdeb === undefined || escolaIdeb === "") return null;
  const d = Math.round((Number(peerIdeb) - Number(escolaIdeb)) * 10) / 10;
  if (!Number.isFinite(d)) return null;
  const abs = Math.abs(d).toFixed(1).replace(".", ",");
  if (d > 0) return `+${abs}`;
  if (d < 0) return `−${abs}`;
  return abs;
}

export const SEVERIDADE_LABELS = {
  alta: "Alta",
  media: "Média",
  baixa: "Baixa",
};

/** Indicadores expressos como proporção 0..1 (exibidos como %). */
export function isProporcao(indicador) {
  return /^prop_/.test(String(indicador));
}

/**
 * Formata o valor de um indicador para exibição.
 * `null`/`undefined`/NaN viram "–".
 */
export function formatIndicator(indicador, value) {
  if (value === null || value === undefined || value === "") return "–";
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  if (isProporcao(indicador)) return `${(n * 100).toFixed(1)}%`;
  return n.toFixed(1);
}

/** Similaridade (0..1) como percentual inteiro. */
export function formatSimilarity(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  return `${Math.round(n * 100)}%`;
}

/**
 * Formata o carimbo de atualização (ISO ou timestamp do Postgres) em
 * data/hora pt-BR. Devolve `null` quando vazio/não parseável de forma útil.
 */
export function formatComputedAt(value) {
  if (value === null || value === undefined || value === "") return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}

/** Quartil do cluster (1..4) como rótulo curto. */
export function formatQuartil(quartil) {
  const q = Number(quartil);
  if (!q || Number.isNaN(q)) return "–";
  return `Q${q}`;
}

/**
 * @param {object} raw Payload cru do endpoint /profile.
 * @returns {{
 *   analysis: string,
 *   school: object,
 *   cluster: object,
 *   peersSource: string,
 *   peersSourceLabel: string,
 *   peersCriterio: string|null,
 *   escolaIdeb: number|null,
 *   metrics: object,
 *   indicadores: Array<object>,
 *   clusterResumo: Array<object>,
 *   peers: Array<object>,
 *   flags: Array<object>,
 * }}
 */
export function transformProfileData(raw) {
  const meta = raw?.metadata ?? {};
  const tables = raw?.tables ?? {};

  return {
    analysis: raw?.analysis ?? "school_profile",
    school: {
      co_entidade: meta.co_entidade,
      nome: meta.no_entidade,
      municipio: meta.no_municipio,
      uf: meta.sg_uf,
      anoCenso: meta.nu_ano_censo,
    },
    cluster: {
      id: meta.cluster_id,
      label: meta.cluster_label,
      source: meta.cluster_source,
      sourceLabel: CLUSTER_SOURCE_LABELS[meta.cluster_source] ?? meta.cluster_source,
      scope: meta.cluster_scope,
      size: meta.cluster_size,
      criterio: meta.grupo_criterio ?? null,
    },
    peersSource: meta.peers_source,
    peersSourceLabel: PEERS_SOURCE_LABELS[meta.peers_source] ?? meta.peers_source,
    peersCriterio: meta.peers_criterio ?? null,
    // IDEB da escola (mesma etapa das similares), para a diferença (#495)
    escolaIdeb:
      asArray(tables.indicadores_comparados).find((i) => i.indicador === "ideb_observado")
        ?.escola ?? null,
    cached: meta.cached === true,
    computedAt: meta.computed_at ?? null,
    computedAtLabel: formatComputedAt(meta.computed_at),
    clusterRunId: meta.cluster_run_id ?? null,
    metrics: raw?.metrics ?? {},
    indicadores: asArray(tables.indicadores_comparados),
    clusterResumo: asArray(tables.cluster_resumo),
    peers: asArray(tables.peers),
    flags: asArray(tables.flags),
    // #483 (RN-02): o IDEB de cada etapa da escola, com as comparações da
    // mesma etapa. Perfil em cache antigo: lista vazia.
    idebPorEtapa: asArray(tables.ideb_por_etapa).map((e) => ({
      etapa: e.etapa,
      etapaTexto: e.etapa_texto ?? e.etapa,
      ano: e.ano ?? null,
      escola: e.escola ?? null,
      municipio: e.municipio ?? null,
      rede: e.rede ?? null,
      brasil: e.brasil ?? null,
      nMunicipio: e.n_municipio ?? null,
      nRede: e.n_rede ?? null,
      nBrasil: e.n_brasil ?? null,
      principal: e.principal === true,
    })),
  };
}

/**
 * #542 (P1-PN-02 da P1): o sinal de atenção em linguagem do dia a dia e com
 * os números — o valor da escola, a mediana das escolas parecidas e de que
 * lado a escola está em relação ao município e ao Brasil (decisão B1:
 * sempre, melhor ou pior). "Quartil" e "grupo de referência" ficam no "?".
 * Sem o valor da escola ou a mediana do grupo, devolve null e a tela usa a
 * mensagem do motor.
 *
 * @param {object} flag  linha de `flags` (indicador, mensagem…)
 * @param {Array<object>} indicadores  `indicadores_comparados`
 * @param {Array<object>} clusterResumo  `cluster_resumo` (p50, n)
 * @param {number|null} [tamanhoGrupo]  escolas do grupo, se faltar o n
 * @returns {{ titulo: string, texto: string } | null}
 */
export function fraseSinal(flag, indicadores = [], clusterResumo = [], tamanhoGrupo = null) {
  const ind = indicadores.find((i) => i.indicador === flag?.indicador);
  const grupo = clusterResumo.find((r) => r.indicador === flag?.indicador);
  const num = (v) => (v === null || v === undefined || v === "" || !Number.isFinite(Number(v)) ? null : Number(v));
  const escola = num(ind?.escola ?? flag?.escola);
  const mediana = num(grupo?.p50);
  if (!ind || escola === null || mediana === null) return null;

  const prop = isProporcao(flag.indicador);
  const fmt = (v) => (prop
    ? `${Math.round(v * 100)}%`
    : v.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 }));
  const menor = (ind.direcao ?? "maior") === "menor";
  const n = num(grupo?.n) ?? num(tamanhoGrupo);
  const noTeto = prop && !menor && mediana >= 1;
  const noPiso = menor && mediana <= 0;
  const limite = noTeto || noPiso ? "" : menor ? " ou menos" : " ou mais";
  const quem = n ? `Nas ${n} escolas parecidas do município` : "Nas escolas parecidas do município";

  // melhor/pior pelo sentido do indicador; igual quando arredonda igual
  const lado = (outro) => {
    if (outro === null) return null;
    if (fmt(outro) === fmt(escola)) return "igual";
    return (menor ? escola < outro : escola > outro) ? "melhor" : "pior";
  };
  const partes = [
    ["o município", num(ind.municipio)],
    ["o Brasil", num(ind.brasil)],
  ].map(([nome, v]) => ({ nome, v, lado: lado(v) })).filter((p) => p.lado);
  let contexto = "";
  if (partes.length === 2 && partes[0].lado === partes[1].lado && partes[0].lado !== "igual") {
    contexto = ` A escola está ${partes[0].lado} que o município (${fmt(partes[0].v)}) e o Brasil (${fmt(partes[1].v)}).`;
  } else if (partes.length > 0) {
    const txt = partes.map((p) => (p.lado === "igual"
      ? `igual ${p.nome.replace(/^o /, "ao ")} (${fmt(p.v)})`
      : `${p.lado} que ${p.nome} (${fmt(p.v)})`));
    contexto = ` A escola está ${txt.join(" e ")}.`;
  }

  return {
    titulo: ind.label ?? flag.indicador,
    texto: `${fmt(escola)} nesta escola. ${quem}, metade tem ${fmt(mediana)}${limite}.${contexto}`,
  };
}
