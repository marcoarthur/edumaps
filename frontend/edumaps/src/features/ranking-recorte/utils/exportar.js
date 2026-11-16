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
 */
export function tabelaRedes(r, redes) {
  const recorte = rotuloRecorte(r.recorte);
  const porte = r.recorte?.porte ?? "";
  return {
    cabecalho: [
      "posicao_valor", "posicao_variacao", "codigo_ibge", "municipio", "uf", "escolas", `media_${r.ano}`, `variacao_${r.ano_anterior ?? ""}_${r.ano}`,
      "salto_atipico", "inse_medio", "quinto_inse", "media_dos_municipios_do_mesmo_quinto",
      `populacao_${r.populacao_fonte?.ano ?? ""}`, "porte", "recorte", "porte_filtro", "minimo_escolas",
    ],
    linhas: redes.map((x) => [
      x.posicao, x.posicao_variacao, x.codigo_ibge, x.municipio, x.uf, x.escolas, x.media, x.variacao, x.atipico ? "sim" : "",
      x.inse, x.quinto_inse, x.media_quinto_inse, x.populacao, x.porte ? rotuloPorte(x.porte) : null,
      recorte, porte, r.minimo_escolas,
    ]),
  };
}

/** Escolas de um município: o município e a rede filtrada em cada linha. */
export function tabelaEscolas(e, escolas) {
  return {
    cabecalho: ["posicao", "inep", "escola", "rede", `${e.indicador.id}_${e.ano}`, "inse", "codigo_ibge", "municipio", "uf", "rede_filtro"],
    linhas: escolas.map((x) => [
      x.posicao, x.co_entidade, x.no_entidade, x.rede, x.valor, x.inse,
      e.municipio?.codigo_ibge, e.municipio?.nome, e.municipio?.uf, e.rede ?? "",
    ]),
  };
}
