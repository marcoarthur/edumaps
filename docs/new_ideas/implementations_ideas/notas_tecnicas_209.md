# Nota técnica 209: recorte por região no ranking de redes (#445)

Achado BA-02 da terceira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-base-analise.md`). Um PR:
#447 (merge `b412062`).

## Decisão de produto

O developer decidiu (2026-11-16) que **a região entra só no ranking**. A base
de análise continua uma UF por vez: a base por região ou nacional fica com a
assinatura de dados, a mesma decisão da #439. A ajuda da base orienta a
juntar as UFs da região, porque as colunas são as mesmas em todas elas.

## `EduMaps::Regiao`

- As cinco regiões do IBGE (`N`, `NE`, `SE`, `S`, `CO`), cada uma com o nome
  e as UFs. As siglas são as do geotag dos relatórios do gestor.
- Funções `ids`, `valido`, `nome`, `ufs` e `lista`, no molde do
  `EduMaps::Porte`. O `Relatorios.pm` passou a montar o `%REGIAO_NOME` a
  partir delas, para o mapa ficar num lugar só.
- Sem cache: as funções varrem as cinco regiões a cada chamada. Assim o
  teste estende `@REGIOES` com `local` e cria uma região fictícia com as UFs
  de teste (`XX`, `XY`). Usar as UFs reais misturaria o teste com as
  fixtures do CI.
- A sigla `SE` é Sudeste no parâmetro `regiao` e Sergipe no `uf`. São
  parâmetros diferentes, sem ambiguidade na API. Na tela, a região aparece
  pelo nome.

## Ranking

- `redes_municipais` aceita `regiao`, que vira `sg_uf = ANY(?)` em todos os
  pontos onde a UF já filtrava:
  - as edições disponíveis;
  - as edições atual e anterior;
  - a contagem de quem fica de fora pelo mínimo de escolas.
- Como o filtro entra antes de `elegiveis`, a posição, os quintos de INSE e
  o salto atípico passam a ser da região. É a mesma regra do porte, e os dois
  se combinam.
- Precedência: a UF vence a região, e a região vence o nacional. A resposta
  traz `recorte.regiao {id, nome}` e `regioes`.
- Tela: o checkbox "Brasil inteiro" virou o seletor **Abrangência** (uma
  UF · uma região · Brasil inteiro).
  - A URL guarda `regiao=`, e o link antigo `nacional=1` continua abrindo o
    Brasil.
  - A UF aparece ao lado do município sempre que o recorte não é uma UF.
  - O CSV leva a sigla da região no nome.
  - A nota de método diz que a comparação é dentro da região.

## Validação

- `t/04-api/ranking_recorte.t` cobre:
  - as 27 UFs, cada uma em exatamente uma região;
  - a região fictícia: total, UFs, posição recalculada (a rede com salto
    passa a Beta), salto atípico e porte;
  - a precedência da UF;
  - erro 400 para uma região inválida.
- vitest: o link com região, a troca de abrangência, o link antigo e uma
  região inválida.
- Suítes: Perl `-j4` com 193 arquivos e 1710 testes; vitest com 152 arquivos
  e 1310 testes. CI verde.
- Dados reais (stack local):
  - o Nordeste, com IDEB anos iniciais, dá 1.334 redes, igual à soma das 9
    UFs;
  - com 10 a 20 mil habitantes, dá 519 redes;
  - o Sudeste dá 792 redes no navegador.

## Deploy

Backend e frontend, sem migração. Entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
