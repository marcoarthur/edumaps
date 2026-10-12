// src/features/gestor/utils/relatorioSalvos.js
//
// Apoio às páginas de relatórios salvos (#219, fase 3): datas, texto do
// recorte e o link "Gerar de novo com os dados atuais", que leva à
// RelatoriosPage com o recorte, o tema e as opções por query (e, na fase 4,
// o assistente quando não é o padrão).
import { NIVEIS } from "./relatorioFormatos.js";

/** Data e hora em pt-BR ("12/10/2026, 09:00"); ausente/ inválida → "—". */
export function formatarDataHora(iso) {
  const d = iso ? new Date(iso) : null;
  if (!d || Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}

/** Só a data em pt-BR ("12/10/2026"); ausente/ inválida → "—". */
export function formatarData(iso) {
  const d = iso ? new Date(iso) : null;
  if (!d || Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("pt-BR");
}

const ROTULO_NIVEL = {
  ...Object.fromEntries(NIVEIS.map((n) => [n.valor, n.rotulo])),
  escola: "Escola",
};

/** "Porto Velho (Município)" — o nome do recorte com o nível. */
export function textoRecorteSalvo(recorte) {
  if (!recorte) return "—";
  const nome = recorte.nome ?? recorte.codigo ?? "—";
  const nivel = ROTULO_NIVEL[recorte.nivel];
  return nivel ? `${nome} (${nivel})` : String(nome);
}

const ASSISTENTE_PADRAO = "relatorio";

/**
 * Assistente do salvo ({id, titulo}) quando não é o padrão "Relatório por
 * tema"; senão null (fase 4). Aceita o resumo (`assistente`) ou o ReportResult.
 */
export function assistenteNaoPadrao(salvo) {
  const a = salvo?.assistente ?? salvo?.relatorio?.assistente;
  if (!a?.id || a.id === ASSISTENTE_PADRAO) return null;
  return { id: a.id, titulo: a.titulo ?? a.id };
}

/**
 * Link para gerar de novo:
 * /gestor/relatorios?[assistente]&nivel&codigo&nome&[tema]&<opções>&gerar=1.
 * O `assistente` só vai quando não é o padrão; o `tema` não vai quando é o
 * próprio assistente (modo composto: o ReportResult leva `tema.id = assistente.id`).
 * @param {{recorte?: object, tema?: object, opcoes?: object, assistente?: object, relatorio?: object}} salvo
 */
export function urlGerarDeNovo(salvo) {
  const recorte = salvo?.recorte ?? salvo?.relatorio?.recorte ?? {};
  const tema = salvo?.tema?.id ?? salvo?.relatorio?.tema?.id;
  const assistente = assistenteNaoPadrao(salvo);
  const q = new URLSearchParams();
  if (assistente) q.set("assistente", assistente.id);
  if (recorte.nivel) q.set("nivel", recorte.nivel);
  if (recorte.codigo !== undefined && recorte.codigo !== null) q.set("codigo", String(recorte.codigo));
  if (recorte.nome) q.set("nome", recorte.nome);
  if (tema && tema !== assistente?.id) q.set("tema", tema);
  for (const [k, v] of Object.entries(salvo?.opcoes ?? {})) {
    if (v !== undefined && v !== null && v !== "") q.set(k, String(v));
  }
  q.set("gerar", "1");
  return `/gestor/relatorios?${q.toString()}`;
}
