# Nota técnica 237: lista de escolas pelo IDEB com cobertura e só escolas em funcionamento (#503)

Achados RD-01 e RD-02 da vigésima quinta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-19-p4-ranking-escolas.md`).
Um PR: #504 (merge `92b6936`).

## O problema

- **RD-01 (atrapalha).** Na aba "Escolas de um município" de `/ranking`, a
  nota do IDEB/SAEB dizia só "N escolas … com <indicador> em <ano>", sem
  método e sem dizer quantas escolas oferecem a etapa. Salvador: 794 escolas
  em funcionamento oferecem os anos iniciais, 243 com IDEB 2023, nenhuma
  privada. Brasil: 52% das públicas que oferecem os anos iniciais têm IDEB
  2023; entre as rurais, 24%. A base de análise avisava que a falta não é
  aleatória; o ranking, não.
- **RD-02 (detalhe).** O ramo do IDEB de `escolas_do_municipio` fazia
  `LEFT JOIN` no Censo sem filtrar a situação: 10 das 257 escolas de
  Salvador não estavam em funcionamento (254 no Brasil, anos iniciais), e a
  ajuda de comparação de redes dizia que o ranking contava só as em
  funcionamento.

## Decisões

- **Só escolas em funcionamento** no Censo mais recente (`JOIN` com
  `tp_situacao_funcionamento = 1`), como os índices e a infraestrutura
  básica. A lista é para escolher escolas, e uma escola fechada não serve.
- **A cobertura vai na resposta** (`cobertura`): escolas em funcionamento
  que oferecem a etapa (anos iniciais, anos finais ou médio regular,
  integrado e normal) e as da lista, no total e em públicas e privadas, com
  o filtro de rede.
  - **Lado a lado, não "x de y":** uma escola pode ter IDEB 2023 e não
    oferecer mais a etapa em 2025 (4 em Salvador), então as da lista não
    estão contidas nas que oferecem.
- **O método do IDEB/SAEB** (`indicador.metodo`) diz o que é o número, que é
  dado do INEP, a edição, a etapa, "só escolas em funcionamento" e o aviso de
  que a falta não é aleatória, no mesmo bloco "Como se calcula" dos índices.
- **Lista vazia segue 404** (ex.: rede privada sem IDEB); a cobertura não vai
  na mensagem de erro.
- **O ranking de redes não mudou:** é a média das escolas com IDEB naquela
  edição, inclusive as que fecharam depois; a ajuda de comparação de redes
  passa a separar as duas contas.

## Validação

- Docker local, Salvador, IDEB anos iniciais: lista de 257 para 247;
  cobertura 794 (282 públicas, 247 com IDEB; 512 privadas, 0); rede
  municipal 246 na lista, 281 oferecem; nota SAEB de Matemática dos anos
  finais, 153 na lista e 444 oferecem.
- **Testes:**
  - Perl: `t/04-api/ranking_recorte.t` com escola extinta com IDEB, pública
    sem IDEB, privada, filtro de rede e o método; 199 arquivos e 1.760
    testes;
  - vitest: 1.365 testes;
  - CI do PR verde.

## Pendências

- A posição da escola no painel da escola (`_rank_from_ideb`) não filtra a
  situação no Censo.
