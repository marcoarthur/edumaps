# Nota técnica 214: infraestrutura básica e método dos índices no ranking de escolas (#457)

Achado VK-01 da quarta avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-16-p6-pautas-revisitadas.md`).
Um PR: #458 (merge `d2ff160`). Abriu a #459 (fórmula da diversidade
discente).

## O problema

O índice "Infraestrutura" do ranking de escolas aparecia sem escala nem
método. Ele também não mede infraestrutura básica:

- é a média de quatro grupos de peso igual, e o básico pesa um quarto;
- a energia conta só se vier da rede pública.

Em Gilbués (PI), uma escola sem água, energia e esgoto ficava em 20º de 27.

## Indicador "Infraestrutura básica"

- **Valor:** quantos dos 4 itens a escola tem, de 0 a 4. Os itens saem das
  respostas "inexistente" do Censo (`in_agua_inexistente`,
  `in_energia_inexistente`, `in_esgoto_inexistente`) e de `in_banheiro`.
  - Conta-se o que a escola tem, não o que falta: o ranking ordena "maior é
    melhor", e "menor primeiro" mostra quem tem mais faltas.
  - `faltam` lista os itens ausentes, montado em SQL com
    `array_remove(ARRAY[CASE …], NULL)`.
- **Ausência não vira falta:** a escola sem resposta em algum item fica fora
  da lista. Hoje os quatro itens vêm preenchidos em todas as escolas em
  funcionamento.
- **Fora do `indicator_registry`:** fica numa lista própria,
  `indicadores_municipio`.
  - `bin/ranking.pl` (ranking pré-calculado) e `available_indicators`
    (painel da escola) percorrem o registro e conhecem só as fontes `mv` e
    `ideb`. Uma fonte nova ali cairia no ramo do IDEB.
  - `escolas_do_municipio` procura primeiro no registro e depois na lista
    própria. O filtro de rede usa o mapa `tp_dependencia` do Censo.
- **Tela e CSV:** a tabela mostra "2 de 4" (`indicador.maximo`) e a coluna
  **Falta**. O CSV ganha `faltam`. No seletor, o índice antigo virou
  "Infraestrutura (índice)".

## Método dos índices

- `%METODO`, no modelo, traz o texto de cada índice, lido de
  `escolas_scores.sql`: a escala de 0 a 10, as partes com os pesos e as
  ressalvas da fórmula.
  - Um item sem resposta conta como ausente (`COALESCE(…, 0)`).
  - A escola sem o registro (docentes, gestores, matrículas) fica com 0
    (`COALESCE(score, 0)` na junção).
  - No índice de infraestrutura, a energia conta só da rede pública.
- A API devolve o texto em `indicador.metodo`. A nota da tabela o mostra, e
  a ajuda ganhou a seção "O que cada índice mede".

## Achado: a diversidade discente soma turnos (#459)

- **O erro:** ao escrever o método, apareceu que o componente de 20% que
  deveria medir alunos com deficiência soma `qt_mat_bas_d/dm/dv`. Essas
  colunas são turnos; a change `censo_turno_comments` corrigiu os
  comentários, mas não o índice.
- **O efeito:** a média do componente é 0,976, e a proporção real de
  educação especial é 0,056.
- **Decisão do developer:** o texto de método diz o que o índice calcula de
  fato, e a fórmula fica para a #459. Corrigi-la muda o agrupamento, as
  escolas semelhantes e o ranking pré-calculado.

## Validação

- **Perl** (município fictício): 4/4, 3/4 e 1/4; a fechada e a sem resposta
  ficam fora; as faltas na ordem; o filtro de rede; os métodos; o indicador
  fora do registro geral.
- **Suítes:** Perl com 193 arquivos e 1713 testes (`inep_teste_unico.t` ok);
  vitest com 153 arquivos e 1329 testes. CI verde.
- **Dados reais:**
  - Gilbués tem 11 escolas com falta, igual à base de análise, e a escola
    22063960 vem por último, com "água, energia, esgoto";
  - Teresina tem 13, em 0,02 s;
  - conferido no navegador.

## Deploy

Backend e frontend, sem migração. Entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
