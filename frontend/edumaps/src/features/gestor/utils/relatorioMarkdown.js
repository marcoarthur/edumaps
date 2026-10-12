// src/features/gestor/utils/relatorioMarkdown.js
//
// Exportação do ReportResult (#219, fase 3) em Markdown, gerada no cliente.
// Uma implementação só serve o relatório recém-gerado e os salvos.
//
// Conteúdo: título, tema, recorte e data; cada seção pelo tipo
//   - texto        → o markdown da seção (títulos internos rebaixados um nível)
//   - indicadores  → lista "**rótulo:** valor (referência)"
//   - tabela       → tabela markdown com os formatos pt-BR, sem colunas `_*`
//   - grafico      → a tabela dos dados do gráfico
//   - associacoes  → lista com direção, segurança, corte e n
//   (tipos desconhecidos são ignorados, como na tela);
// depois os avisos e as fontes (sem o nome interno da ferramenta).
import { formatarValor, ehNumerico } from "./relatorioFormatos.js";

const DIRECAO = {
  maior: "associado a resultado maior",
  menor: "associado a resultado menor",
  sem_relacao_clara: "sem relação clara",
};

const SEGURANCA = { alta: "segurança alta", media: "segurança média", baixa: "segurança baixa" };

const vazio = (v) => v === null || v === undefined || v === "";

/** Texto do recorte como a tela mostra: "Porto Velho (RO)", "Rondônia"… */
export function textoRecorte(relatorio) {
  const r = relatorio?.recorte;
  if (!r) return "";
  if (r.nivel === "municipio" && r.uf && r.nome) return `${r.nome} (${r.uf})`;
  return String(r.nome ?? r.codigo ?? "");
}

/** Data de geração em pt-BR ("12/10/2026, 09:00"), ou null. */
export function dataGeracao(relatorio) {
  const d = relatorio?.gerado_em ? new Date(relatorio.gerado_em) : null;
  if (!d || Number.isNaN(d.getTime())) return null;
  return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}

/** Célula de tabela markdown: sem quebras de linha e com "|" escapado. */
export function celulaMarkdown(valor) {
  return String(valor ?? "")
    .replace(/\r?\n+/g, " ")
    .replace(/\|/g, "\\|")
    .trim();
}

/** Texto corrido em uma linha (títulos, itens de lista). */
const linha = (v) => String(v ?? "").replace(/\r?\n+/g, " ").trim();

/**
 * Tabela markdown a partir de colunas {id, rotulo, formato} e linhas.
 * Colunas iniciadas por "_" nunca entram; linha com `_destaque` ganha
 * "(sua escola)" na primeira célula.
 */
export function tabelaMarkdown(colunas, linhas) {
  const cols = (colunas ?? []).filter((c) => c && !String(c.id ?? "").startsWith("_"));
  if (!cols.length) return "";
  const cab = `| ${cols.map((c) => celulaMarkdown(c.rotulo ?? c.id)).join(" | ")} |`;
  const sep = `| ${cols.map((c) => (ehNumerico(c.formato) ? "---:" : "---")).join(" | ")} |`;
  const corpo = (linhas ?? []).map((l) => {
    const celulas = cols.map((c, j) => {
      let v = formatarValor(l?.[c.id], c.formato);
      if (j === 0 && l?._destaque === true) v = `${v} (sua escola)`;
      return celulaMarkdown(v);
    });
    return `| ${celulas.join(" | ")} |`;
  });
  if (!corpo.length) corpo.push(`| ${cols.map((_, j) => (j === 0 ? "Sem dados para este recorte." : "")).join(" | ")} |`);
  return [cab, sep, ...corpo].join("\n");
}

/** Rebaixa os títulos do markdown da seção (## → ###) para caber sob o "##" dela. */
function rebaixarTitulos(md) {
  return String(md ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/^(#{1,5})(\s)/gm, "#$1$2")
    .trim();
}

function secaoTexto(s) {
  const partes = [];
  if (s.titulo) partes.push(`## ${linha(s.titulo)}`);
  const corpo = rebaixarTitulos(s.markdown);
  if (corpo) partes.push(corpo);
  return partes;
}

function secaoIndicadores(s) {
  const partes = [];
  if (s.titulo) partes.push(`## ${linha(s.titulo)}`);
  const itens = (s.itens ?? []).map((item) => {
    let t = `- **${linha(item?.rotulo)}:** ${formatarValor(item?.valor, item?.formato)}`;
    if (item?.referencia) {
      const ref = item.referencia;
      t += ` (${linha(ref.rotulo)}: ${formatarValor(ref.valor, ref.formato ?? item.formato)})`;
    }
    return t;
  });
  if (itens.length) partes.push(itens.join("\n"));
  return partes;
}

function secaoTabela(s) {
  const titulo = linha(s.titulo ?? "Tabela");
  const partes = [`## ${s.recolhida === true ? `Detalhes técnicos: ${titulo}` : titulo}`];
  const t = tabelaMarkdown(s.colunas, s.linhas);
  if (t) partes.push(t);
  if (s.nota) partes.push(`_${linha(s.nota)}_`);
  return partes;
}

function secaoGrafico(s) {
  const partes = [];
  partes.push(`## ${linha(s.titulo ?? "Gráfico")}`);
  const tipo = s.grafico === "linhas" ? "Gráfico de linhas" : "Gráfico de barras";
  partes.push(`_${tipo} — dados:_`);
  const colunas = [
    { id: s.x?.id, rotulo: s.x?.rotulo ?? s.x?.id, formato: "texto" },
    ...(s.series ?? []).map((serie) => ({
      id: serie.id,
      rotulo: serie.rotulo ?? serie.id,
      formato: serie.formato,
    })),
  ];
  const t = tabelaMarkdown(colunas, s.dados ?? []);
  if (t) partes.push(t);
  return partes;
}

function secaoAssociacoes(s) {
  const partes = [`## ${linha(s.titulo ?? "Associações")}`];
  const itens = (s.itens ?? []).map((item) => {
    const nome = `**${linha(item?.rotulo)}**${item?.corte ? ` (${linha(item.corte)})` : ""}`;
    const detalhes = [DIRECAO[item?.direcao] ?? DIRECAO.sem_relacao_clara];
    detalhes.push(SEGURANCA[item?.seguranca] ?? SEGURANCA.baixa);
    if (!vazio(item?.n)) detalhes.push(`n = ${formatarValor(item.n, "inteiro")}`);
    return `- ${nome}: ${detalhes.join(" · ")}`;
  });
  partes.push(itens.length ? itens.join("\n") : "Sem associações para este recorte.");
  if (s.nota) partes.push(`_${linha(s.nota)}_`);
  return partes;
}

const POR_TIPO = {
  texto: secaoTexto,
  indicadores: secaoIndicadores,
  tabela: secaoTabela,
  grafico: secaoGrafico,
  associacoes: secaoAssociacoes,
};

function fonteMarkdown(f) {
  const partes = [linha(f?.descricao ?? "Dados públicos")];
  if (f?.edicao) partes.push(linha(f.edicao));
  if (f?.escopo) partes.push(linha(f.escopo));
  if (!vazio(f?.n)) partes.push(`n = ${formatarValor(f.n, "inteiro")}`);
  return `- ${partes.join(" · ")}`;
}

/**
 * Converte o ReportResult em Markdown (função pura).
 * @param {object} relatorio
 * @returns {string}
 */
export function relatorioParaMarkdown(relatorio) {
  const r = relatorio ?? {};
  const blocos = [`# ${linha(r.titulo ?? "Relatório")}`];

  const meta = [];
  if (r.tema?.titulo) meta.push(`**Tema:** ${linha(r.tema.titulo)}`);
  const recorte = textoRecorte(r);
  if (recorte) meta.push(`**Recorte:** ${linha(recorte)}`);
  const data = dataGeracao(r);
  if (data) meta.push(`**Gerado em:** ${data}`);
  // dois espaços no fim = quebra de linha no markdown
  if (meta.length) blocos.push(meta.join("  \n"));

  if (r.rastreio?.llm === "indisponivel") {
    blocos.push(
      "> A redação automática não estava disponível. O resumo é uma versão curta gerada sem o assistente; os dados das seções não foram afetados.",
    );
  }

  for (const s of r.secoes ?? []) {
    if (!s || typeof s !== "object") continue;
    const fn = POR_TIPO[s.tipo];
    if (!fn) continue;
    blocos.push(...fn(s));
  }

  const avisos = (r.avisos ?? []).filter((a) => a?.mensagem);
  if (avisos.length) {
    blocos.push("## Avisos");
    blocos.push(avisos.map((a) => `- ${linha(a.mensagem)}`).join("\n"));
  }

  const fontes = r.fontes ?? [];
  if (fontes.length) {
    blocos.push("## Fontes");
    blocos.push(fontes.map(fonteMarkdown).join("\n"));
  }

  return `${blocos.join("\n\n")}\n`;
}

/** Slug ASCII: sem acentos, minúsculo, só [a-z0-9-]. */
export function slug(texto) {
  return String(texto ?? "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/**
 * Nome do arquivo: relatorio-<tema>-<recorte>-<data>.md (data AAAA-MM-DD do
 * `gerado_em`; sem data válida, a de hoje).
 */
export function nomeArquivoMarkdown(relatorio) {
  const tema = slug(relatorio?.tema?.id ?? relatorio?.tema?.titulo);
  const recorte = slug(relatorio?.recorte?.nome ?? relatorio?.recorte?.codigo);
  const d = relatorio?.gerado_em ? new Date(relatorio.gerado_em) : null;
  const data = (d && !Number.isNaN(d.getTime()) ? d : new Date()).toISOString().slice(0, 10);
  return `${["relatorio", tema, recorte, data].filter(Boolean).join("-")}.md`;
}

/**
 * Baixa um texto como arquivo (Blob + link temporário). O revokeObjectURL vai
 * num setTimeout: revogar no mesmo tick pode cancelar o download.
 */
export function baixarArquivo(conteudo, nome, tipo = "text/markdown;charset=utf-8") {
  const blob = new Blob([conteudo], { type: tipo });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nome;
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  return blob;
}

/** Gera e baixa o Markdown do relatório. */
export function baixarMarkdown(relatorio) {
  return baixarArquivo(relatorioParaMarkdown(relatorio), nomeArquivoMarkdown(relatorio));
}
