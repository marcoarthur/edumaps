# Nota técnica 260: as fontes dentro do CSV do ranking (#550)

Achado QJ-02 da terceira avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-23-p5-meta1-pernambuco.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #552 (merge `7ab52fb`).

## O problema

- **QJ-02 (incomoda).** O CSV do ranking trazia os anos (população e Censo
  Escolar), mas não o nome das bases, a data da carga nem o link oficial.
  Isso ficava só no rodapé "Fonte:" da página (#539).
- Solta num processo, a planilha não dizia de onde veio.

## Decisões

- **A1, duas colunas em toda linha:** `fontes` ("Censo Escolar 2025 (INEP,
  carga em 14/10/2026) | …") e `fontes_links` (os links oficiais, na mesma
  ordem). É o padrão do recorte e do método: o arquivo segue uma tabela
  limpa (Excel e `read.csv2` sem tratamento), e cada linha leva a fonte
  mesmo copiada sozinha. Linhas comentadas no topo (A2) quebrariam a
  leitura; um dicionário à parte (A3) deixaria o arquivo solto de novo.
- **B1, os três CSVs da página:** redes do IDEB, taxa da educação infantil
  e escolas de um município, com o mesmo mecanismo.
- **As bases do rodapé, nem mais nem menos:** o catálogo de `/api/fontes`
  (já em cache pela promessa do rodapé), filtrado pela tela do indicador
  (`ranking_atendimento` na taxa, `ranking` nas outras). O texto usa o
  mesmo rótulo do selo (`rotuloFonte`, `dataBR`) e "carga não registrada"
  quando falta a data.
- **O download não depende do catálogo:** se a busca falhar, o arquivo
  sai com "ver /fontes no EduMaps" em `fontes`. A exportação virou
  assíncrona; as linhas são fixadas antes do `await`.
- **Sem `;` no texto,** porque é o separador (o `csv()` poria aspas, mas
  leitores ingênuos quebrariam).
- **Só frontend:** nenhuma rota nova nem mudança no backend.

## Validação

- **Docker local:** o CSV capturado na página, sem baixar arquivo:
  - taxa da creche em PE: 185 municípios, Censo Escolar, estimativa da
    população e população por idade (sem IDEB);
  - redes do IDEB em PE: 166 redes, 5 bases;
  - escolas de Recife: 194 escolas, 5 bases.
- **Testes:** vitest, 1.414 (as colunas nos três CSVs, a taxa sem o IDEB,
  o catálogo fora do ar); CI do PR verde.

## Pendências

- No LXC: `deploy_frontend_dev`.
- QJ-01 e QJ-02 da P5 resolvidos; segue aberto o AN-12 (comparação de
  gasto, SICONFI vazio).
