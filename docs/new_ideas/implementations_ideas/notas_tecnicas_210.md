# Nota técnica 210: região na base de análise e recorte nos CSVs do ranking (#448)

Achados RG-01 e RG-02 da quarta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-ranking-regiao.md`). Um PR:
#450 (merge `0a25fbb`). O developer aprovou também a proposta extra: o CSV do
ranking de escolas.

## RG-01: coluna `regiao` na base de análise

- Para comparar regiões, a ajuda manda baixar as UFs e juntar os arquivos.
  Na rodada, a pesquisadora escreveu à mão o mapa das 27 UFs para as cinco
  regiões, e é aí que o erro entra.
- A coluna `regiao` entra na identificação, logo depois de `uf`. O valor é o
  nome da região (Norte, Nordeste…).
- `EduMaps::Regiao->case_sql($expr)`, no molde do `Porte->case_sql`, monta o
  `CASE` a partir de `@REGIOES`. A base e o ranking usam a mesma tabela de
  regiões.
- Não usamos o `no_regiao` do Censo:
  - a região derivada da UF não depende de a carga ter preenchido a coluna;
  - as escolas criadas pelos testes também não a preenchem.
- O dicionário diz "Região geográfica do IBGE (…), derivada da UF".
- A coluna nova muda a posição das que vêm depois dela. Quem lê pelo nome,
  como a ajuda mostra, não percebe.

## RG-02: o recorte em cada linha dos CSVs do ranking

A posição, o quinto de INSE e a média do mesmo quinto só valem dentro do
recorte. Até aqui o recorte estava só no nome do arquivo, e quem juntava
arquivos de duas regiões misturava quintos sem aviso. É a mesma lição da
versão dos dados (#438, #439): a informação viaja na linha.

- Redes: `recorte` (`UF:ES`, `regiao:NE` ou `BR`), `porte_filtro` e
  `minimo_escolas`. O mínimo entra porque também define quem disputa a
  posição.
- Escolas: `codigo_ibge`, `municipio`, `uf` e `rede_filtro`.
- O recorte vem da **resposta** da API (`recorte`, `minimo_escolas`,
  `municipio`, `rede`), não do estado da tela, que pode ter mudado durante a
  carga.
- As tabelas saem de `features/ranking-recorte/utils/exportar.js`, funções
  puras e testadas à parte. A página só monta o CSV e dispara o download.

## Validação

- **Perl:**
  - o cabeçalho tem `regiao`, e a escola do AC sai como Norte;
  - o dicionário traz a região;
  - `case_sql` foi conferido no Postgres para as 27 UFs; UF desconhecida
    sai sem região.
- **vitest:** 4 casos para as tabelas e 2 na página, que capturam o arquivo
  baixado. O Blob do jsdom não tem `.text()`, então o arquivo é lido com
  `FileReader`.
- **Suítes:** Perl com 193 arquivos e 1710 testes; vitest com 153 arquivos e
  1316 testes. CI verde.
- **Dados reais:**
  - o ES sai com 3.046 linhas, todas como "Sudeste";
  - AM sai como Norte, BA e SE como Nordeste, DF como Centro-Oeste e RS como
    Sul;
  - a tela da base mostra a identificação com 8 colunas.

## Deploy

Backend e frontend, sem migração. Entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
