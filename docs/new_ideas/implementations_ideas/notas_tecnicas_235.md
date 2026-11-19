# Nota técnica 235: variação do ranking de redes nas mesmas escolas (#499)

Achado RF-01 da vigésima terceira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-19-p4-variacao-redes.md`).
Um PR: #500 (merge `af99120`).

## O problema

- **RF-01 (atrapalha).** A variação do ranking de redes municipais
  (`EduMaps::Model::Rank::School::redes_municipais`) era a média das escolas
  com o indicador na edição atual menos a média das escolas com o indicador
  na anterior (CTEs `atual` e `anterior`, cada uma com o seu `avg`). Os dois
  conjuntos de escolas podiam ser diferentes: em 2021 muitas escolas ficaram
  sem IDEB.
  - **Medido** (IDEB anos iniciais, 2021 → 2023, 2.476 redes com pelo menos
    3 escolas nas duas edições): diferença média de 0,13 ponto para a
    variação nas mesmas escolas; 279 redes com diferença ≥ 0,3; 129 com o
    sinal trocado.
  - São Sebastião da Boa Vista/PA: +1,15 (salto atípico) com 4 escolas nas
    duas edições, que variaram +0,03. Parnaguá/PI liderava o Brasil (+3,54)
    com uma escola nas duas edições.

## Decisões

- **A variação é a média das diferenças escola a escola** (CTE `pares`,
  junção por `id_escola` das duas edições, mesma etapa, rede municipal,
  indicador não nulo nas duas). É o mesmo número que a diferença das médias
  desse conjunto, e responde "estas escolas melhoraram?", que é a pergunta de
  quem procura redes para entrevistar.
  - **Por que não manter as duas variações:** a antiga mistura mudança de
    resultado com mudança de composição e não tem leitura útil sozinha; a
    composição aparece no número de escolas.
- **O mínimo de escolas vale para as escolas das duas edições.** Abaixo
  dele a variação fica "–", como antes. O valor da edição, a posição pelo
  valor, o INSE e o mínimo do ranking continuam sobre a edição atual.
- **A posição pela variação e o salto atípico** já liam a coluna
  `variacao`; passam a usar a pareada sem mudar de código.
- **O número de escolas fica visível:** `escolas_variacao` em cada rede, na
  tela entre parênteses quando não são todas, e no CSV; `variacao_regra =
  "mesmas_escolas"` no payload.
- **O filtro de UF na junção** usa o alias (`$uf_sql_i`), porque as duas
  edições têm `sg_uf`.

## Validação

- Docker local, IDEB dos anos iniciais, 2021 → 2023:

  | | Antes | Agora |
  |---|---|---|
  | São Sebastião da Boa Vista/PA | +1,15, salto atípico, 3ª do PA | +0,03 (4 escolas), 62ª |
  | Santa Maria/RS | 0,00 | +0,46 (16 escolas), 18ª do RS |
  | Óbidos/PA | +0,05 | −0,52 (12 escolas) |
  | Redes com variação (Brasil) | 2.476 | 2.279 |
  | Saltos atípicos (Brasil) | 113 | 103 |

- **Testes:**
  - Perl: subtest em `t/04-api/ranking_recorte.t` com uma rede em que a
    diferença das médias seria +1,875 e a variação nas mesmas escolas é
    −0,5, outra abaixo do mínimo nas duas edições, e a rede antiga (mesmas
    escolas, mesma variação); 199 arquivos e 1.759 testes;
  - vitest: 1.362 testes;
  - CI do PR verde.

## Pendências

- Outras telas que comparam edições do IDEB por média de escolas (a linha do
  IDEB da comparação de redes) mostram níveis por edição, não variação; não
  foram mudadas. Vale conferir se alguma outra tela calcula "quanto mudou"
  da mesma forma.
