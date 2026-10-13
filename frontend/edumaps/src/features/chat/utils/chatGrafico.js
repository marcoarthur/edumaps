// src/features/chat/utils/chatGrafico.js
//
// Converte o `chart` do Assistente do Censo (#224) para o formato dos
// wrappers Carbon ({group, key, value}). O R (`chat_chart_plotly_json`, em
// analysis/edumapsr/R/chat-plotly.R) devolve uma spec estilo Plotly:
//
//   barra: {data: [{x: [...], y: [...], type: "bar"}], layout}
//   linha: {data: [{x: [...], y: [...], type: "scatter", mode: "lines+markers"}], layout}
//   pizza: {data: [{labels: [...], values: [...], type: "pie"}], layout}
//   layout: {title: {text}, xaxis: {title}, yaxis: {title}}
//
// O Plumber pode serializar escalares como arrays de 1 elemento (e vetores de
// 1 elemento como escalares); os dois casos são aceitos. Qualquer formato
// irreconhecível devolve null — a mensagem segue sem gráfico.

/** Valor escalar: desembrulha array de 1 elemento. */
function escalar(v) {
  return Array.isArray(v) && v.length === 1 ? v[0] : v;
}

/** Lista: escalar vira lista de 1; null/undefined vira []. */
function lista(v) {
  if (Array.isArray(v)) return v;
  return v === null || v === undefined ? [] : [v];
}

/** Texto de um título Plotly ({text} ou string). */
function texto(v) {
  const t = escalar(v);
  if (t && typeof t === "object") return texto(t.text);
  return typeof t === "string" || typeof t === "number" ? String(t) : "";
}

function numero(v) {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

/**
 * Spec normalizada do gráfico do chat, ou null se o formato não for
 * reconhecível ou não houver nenhum ponto numérico.
 *
 * @param {unknown} chart
 * @returns {null | {tipo: "barra"|"linha"|"pizza", titulo: string, xRotulo: string,
 *   yRotulo: string, pontos: Array<{key: string, value: number}>}}
 */
export function graficoDoChat(chart) {
  if (!chart || typeof chart !== "object" || Array.isArray(chart)) return null;
  const traco = lista(chart.data)[0];
  if (!traco || typeof traco !== "object") return null;

  const type = escalar(traco.type);
  let tipo;
  let chaves;
  let valores;
  if (type === "bar" || type === "scatter") {
    tipo = type === "bar" ? "barra" : "linha";
    chaves = lista(traco.x);
    valores = lista(traco.y);
  } else if (type === "pie") {
    tipo = "pizza";
    chaves = lista(traco.labels);
    valores = lista(traco.values);
  } else {
    return null;
  }

  const pontos = [];
  chaves.forEach((k, i) => {
    const value = numero(valores[i]);
    if (value === null || k === null || k === undefined) return;
    pontos.push({ key: String(k), value });
  });
  if (pontos.length === 0) return null;

  const layout = chart.layout && typeof chart.layout === "object" ? chart.layout : {};
  return {
    tipo,
    titulo: texto(layout.title),
    xRotulo: texto(layout.xaxis?.title),
    yRotulo: texto(layout.yaxis?.title),
    pontos,
  };
}

/** Linhas no formato dos wrappers Carbon. */
export function linhasGrafico(spec) {
  const group = spec.yRotulo || spec.titulo || "Valor";
  return spec.pontos.map((p) => ({ group: spec.tipo === "pizza" ? p.key : group, key: p.key, value: p.value }));
}

const NOME_TIPO = { barra: "Gráfico de barras", linha: "Gráfico de linhas", pizza: "Gráfico de pizza" };

/** Descrição em texto do gráfico, para leitores de tela. */
export function descricaoGraficoChat(spec) {
  const fmt = (v) => v.toLocaleString("pt-BR");
  const titulo = spec.titulo ? ` "${spec.titulo}"` : "";
  const por = spec.xRotulo ? ` por ${spec.xRotulo}` : "";
  const valores = spec.pontos.map((p) => `${p.key}: ${fmt(p.value)}`).join("; ");
  return `${NOME_TIPO[spec.tipo]}${titulo}${por}. ${valores}.`;
}
