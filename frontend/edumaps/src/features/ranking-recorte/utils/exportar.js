// src/features/ranking-recorte/utils/exportar.js
//
// Tabelas dos CSVs do ranking. #448 (RG-02): a posição, o quinto de INSE e a
// média do mesmo quinto só valem dentro do recorte, então o recorte vai em
// toda linha (e não só no nome do arquivo), como a versão dos dados na base
// de análise. O recorte vem da resposta da API, não do estado da tela.
import { rotuloPorte } from "../constants.js";

/** "UF:ES", "regiao:NE" ou "BR", a partir de `recorte` da resposta. */
export function rotuloRecorte(recorte) {
  if (recorte?.uf) return `UF:${recorte.uf}`;
  if (recorte?.regiao) return `regiao:${recorte.regiao.id ?? recorte.regiao}`;
  return "BR";
}

/**
 * Ranking de redes: cabeçalho e linhas, com o recorte no fim de cada linha.
 * #453 (VJ-02): as duas posições, pelo valor e pela variação, com nomes que
 * dizem de qual ordem são; a ordem das linhas é a da tela.
 * #499: `escolas_variacao`, as escolas com dado nas duas edições, sobre as
 * quais a variação é calculada.
 */
export function tabelaRedes(r, redes) {
  const recorte = rotuloRecorte(r.recorte);
  const porte = r.recorte?.porte ?? "";
  return {
    cabecalho: [
      "posicao_valor", "posicao_variacao", "codigo_ibge", "municipio", "uf", "escolas", `media_${r.ano}`, `variacao_${r.ano_anterior ?? ""}_${r.ano}`,
      "escolas_variacao", "salto_atipico", "inse_medio", "quinto_inse", "media_dos_municipios_do_mesmo_quinto",
      `populacao_${r.populacao_fonte?.ano ?? ""}`, "porte", "recorte", "porte_filtro", "minimo_escolas",
    ],
    linhas: redes.map((x) => [
      x.posicao, x.posicao_variacao, x.codigo_ibge, x.municipio, x.uf, x.escolas, x.media, x.variacao, x.escolas_variacao, x.atipico ? "sim" : "",
      x.inse, x.quinto_inse, x.media_quinto_inse, x.populacao, x.porte ? rotuloPorte(x.porte) : null,
      recorte, porte, r.minimo_escolas,
    ]),
  };
}

/**
 * Escolas de um município: o município e a rede filtrada em cada linha.
 * #457: na infraestrutura básica, a coluna `faltam` lista os itens ausentes.
 */
/** Nome do CSV das escolas; com a versão da fórmula quando o índice é do EduMaps (#465, RY-02). */
export function nomeCsvEscolas(e) {
  const v = e.indicador?.versao;
  return `ranking-escolas-${e.municipio.codigo_ibge}-${e.indicador.id}-${e.ano}${v ? `-${v}` : ""}.csv`;
}

export function tabelaEscolas(e, escolas) {
  const comFaltas = escolas.some((x) => Array.isArray(x.faltam));
  // #462: índice do EduMaps leva a versão da fórmula em toda linha, para um
  // CSV de antes de uma mudança de fórmula não se confundir com um de depois.
  const versao = e.indicador?.versao;
  return {
    cabecalho: [
      "posicao", "inep", "escola", "rede", `${e.indicador.id}_${e.ano}`, ...(comFaltas ? ["faltam"] : []),
      "inse", "codigo_ibge", "municipio", "uf", "rede_filtro", ...(versao ? ["versao_indice"] : []),
    ],
    linhas: escolas.map((x) => [
      x.posicao, x.co_entidade, x.no_entidade, x.rede, x.valor, ...(comFaltas ? [(x.faltam ?? []).join(", ")] : []),
      x.inse, e.municipio?.codigo_ibge, e.municipio?.nome, e.municipio?.uf, e.rede ?? "", ...(versao ? [versao] : []),
    ]),
  };
}
