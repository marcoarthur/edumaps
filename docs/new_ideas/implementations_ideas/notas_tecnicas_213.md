# Nota técnica 213: posição pela variação no CSV e motivo da variação vazia (#453)

Achados VJ-02 e VJ-03 da terceira avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-16-p6-jornalismo.md`). Um PR:
#456 (merge `62c4dbe`). Só frontend.

## Por que só frontend

- A API já devolvia `posicao_variacao` em cada rede.
- No modelo, a variação fica vazia por um único motivo:
  `CASE WHEN p.n >= $min THEN a.media - p.media END`. A rede tinha menos
  escolas com dado que o mínimo na edição anterior, ou não havia edição
  anterior.

Por isso a contagem sai da própria lista da resposta. É o mesmo universo da
tabela e bate com os "–" que aparecem.

## VJ-02: as duas posições no CSV

- `posicao` virou `posicao_valor`, e `posicao_variacao` entra logo depois
  (vazia sem variação). As linhas seguem a ordem da tela.
  - Antes, com a tabela ordenada pela variação, o arquivo saía nessa ordem,
    mas a única posição era a do valor.
  - Renomear foi decisão do developer: o CSV tinha mudado de formato havia
    pouco (#448), e o nome antigo era o próprio problema.
- `variacao()` escreve "0" quando o valor arredonda a zero, em vez de "−0".
  O CSV continua com o número cru.

## VJ-03: o motivo na nota

A nota da tabela ganha a frase "N redes sem variação: tinham menos de M
escolas com dado em <ano anterior> (o mesmo mínimo do ranking)". Sem edição
anterior, ela diz "sem edição anterior para comparar". O caso que motivou o
achado foi São Luís (MA, 97 escolas): em 2021, só 9 escolas tinham IDEB.

## Validação

- **vitest:**
  - `formato.test.js`: ±0,004 vira "0";
  - `exportar.test.js`: as duas posições;
  - na página: o CSV na ordem da variação e as três formas da frase.
- **Suíte:** 153 arquivos e 1326 testes. CI verde.
- **Navegador:**
  - o Nordeste com mínimo de 10 mostra "105 redes sem variação: tinham
    menos de 10 escolas com dado em 2021";
  - Presidente Dutra (MA) mostra "0".

## Deploy

Só frontend. Entra no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
