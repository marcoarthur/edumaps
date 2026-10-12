// src/features/inscricao/utils/markdownSimples.js
//
// Converte o "markdown simples" do texto de consentimento (issue #214) numa
// árvore de blocos que o Svelte renderiza com elementos próprios — nunca com
// {@html}. Suporta: parágrafos (separados por linha em branco), títulos (#),
// listas (`- `, `* `, `1. `) e **negrito**. Todo o resto vira texto puro,
// inclusive HTML (escapado pelo próprio Svelte ao renderizar texto).

/**
 * @typedef {{texto: string, negrito: boolean}} Trecho
 * @typedef {{tipo: "p"|"h", trechos: Trecho[]} | {tipo: "ul"|"ol", itens: Trecho[][]}} Bloco
 */

/** Divide uma linha em trechos normais e em **negrito**. @returns {Trecho[]} */
export function trechos(linha) {
  const out = [];
  const re = /\*\*(.+?)\*\*/g;
  let ultimo = 0;
  let m;
  while ((m = re.exec(linha)) !== null) {
    if (m.index > ultimo) out.push({ texto: linha.slice(ultimo, m.index), negrito: false });
    out.push({ texto: m[1], negrito: true });
    ultimo = m.index + m[0].length;
  }
  if (ultimo < linha.length) out.push({ texto: linha.slice(ultimo), negrito: false });
  return out;
}

const ITEM_UL = /^\s*[-*]\s+(.*)$/;
const ITEM_OL = /^\s*\d+[.)]\s+(.*)$/;
const TITULO = /^\s*#{1,6}\s+(.*)$/;

/** @param {string} texto @returns {Bloco[]} */
export function markdownSimples(texto) {
  const blocos = [];
  let paragrafo = [];
  let lista = null;

  const fecharParagrafo = () => {
    if (paragrafo.length) blocos.push({ tipo: "p", trechos: trechos(paragrafo.join(" ")) });
    paragrafo = [];
  };
  const fecharLista = () => {
    if (lista) blocos.push(lista);
    lista = null;
  };

  for (const bruta of String(texto ?? "").replace(/\r\n?/g, "\n").split("\n")) {
    const linha = bruta.trim();
    if (!linha) {
      fecharParagrafo();
      fecharLista();
      continue;
    }
    const ul = linha.match(ITEM_UL);
    const ol = ul ? null : linha.match(ITEM_OL);
    if (ul || ol) {
      fecharParagrafo();
      const tipo = ul ? "ul" : "ol";
      if (lista && lista.tipo !== tipo) fecharLista();
      if (!lista) lista = { tipo, itens: [] };
      lista.itens.push(trechos((ul ?? ol)[1]));
      continue;
    }
    const h = linha.match(TITULO);
    if (h) {
      fecharParagrafo();
      fecharLista();
      blocos.push({ tipo: "h", trechos: trechos(h[1]) });
      continue;
    }
    fecharLista();
    paragrafo.push(linha);
  }
  fecharParagrafo();
  fecharLista();
  return blocos;
}
