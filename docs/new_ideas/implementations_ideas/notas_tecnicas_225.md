# Nota técnica 225: comparação de redes só com escolas em funcionamento (#479)

Achados RP-01 a RP-04 da décima terceira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-comparar-redes.md`).
Um PR: #480 (merge `74a9dda`).

## O problema

- **RP-01 (atrapalha).** `analytics.mv_rede_escolas`, que alimenta a
  comparação de redes (`/municipio/compare`), não filtrava a situação da
  escola.
  - Brasil: 214.192 escolas contra 180.540 em funcionamento. As 33.652 a
    mais (+16%) são paralisadas ou extintas, sem matrícula.
  - 3.012 dos 5.571 municípios tinham 10% ou mais a mais.
  - Formoso (MG), rede municipal: 56 escolas, 4 em funcionamento.
  - Erravam "Escolas", "Alunos por escola" e "Escolas por rede". O perfil, o
    ranking e a base já usavam só as em funcionamento.
- **RP-02 (atrapalha).** O perfil analítico da rede mostrava "1.432
  escolas" e a média do IDEB sem dizer que ela se apoiava em menos de 400.
  Ao abrir o código, o IDEB do perfil não era uma "média entre etapas": de
  cada escola, a consulta pega a linha da etapa de maior nota SAEB
  (`DISTINCT ON … ORDER BY nota_media DESC`).
- **RP-03 (detalhe).** O `numero_escolas` da linha do IDEB contava as
  linhas da planilha do INEP, inclusive as sem nota (ensino médio estadual de
  Salvador, 2023: 131 contra 69 com IDEB). O gráfico não mostrava esse número.
- **RP-04 (detalhe).** A ajuda "Comparar redes" era de outubro de 2025 e
  genérica.

## Decisões (developer, 2026-11-17)

- **Change nova** para a MV, só com escolas em funcionamento. O IDEB fica
  como estava: é o da edição, inclusive de escolas que fecharam depois.
- **Rótulo honesto e o número de escolas** no perfil, sem mudar o cálculo do
  IDEB agora. O IDEB por etapa no perfil, com a referência do Brasil por
  etapa, fica para uma issue própria (mexe no perfil da escola e na
  referência pré-calculada).
- **O número de escolas por ponto** no tooltip da linha do IDEB.

## O que foi construído

- **Change `rede_escolas_ativas`:** recria a MV com a definição da
  `censo_labels_consumers` e `tp_situacao_funcionamento = 1` na lista de
  redes do município e nos agregados. A rede só com escolas fechadas sai da
  lista. COMMENTs dizem "em funcionamento". O verify compara a soma de
  `total_escolas` com o número de escolas em funcionamento. Só o resumo da
  comparação lê essa MV.
- **Backend:** `numero_escolas` conta `ideb_observado`. A chave de cache do
  `network_profile` ganha `versao => 2`, para o formato novo não ser
  mascarado pelo cache.
- **edumapsr (perfil da rede):** `count(p.<indicador>) AS n_<indicador>` na
  rede e por grupo; `n_com_valor` nas tabelas `indicadores` e `clusters`;
  `ano_ideb` e `ano_inse` em metadata.
- **Frontend:** coluna "Escolas com dado" e o rótulo "IDEB 2023 (etapa de
  maior nota de cada escola)" no perfil; o número entre parênteses nos
  grupos quando nem todas as escolas têm o dado; tooltip da linha do IDEB
  com as escolas; nota da média simples abaixo do gráfico.
- **Ajuda:** `comparar-redes.md` reescrita (o que conta como escola, médias
  simples, o ano de cada número, o IDEB do perfil, o caminho até a tela).

## Validação

- Perl: 196 arquivos, 1734 testes. Em `summary.t`, um município fictício só
  com uma escola paralisada (INEP 60479001) não pode aparecer na MV: o
  teste falha com a definição antiga. R: `testthat` inteiro. Frontend: 1339
  testes. CI do PR verde.
- Sqitch no banco de fixtures: deploy, `revert --to escolas_scores_gestora`,
  `deploy --verify` e o verify global.
- Local: Brasil 180.540; Salvador estadual 200 e municipal 414; Formoso
  municipal 4; linha do IDEB com 69 escolas no ensino médio estadual de
  2023; perfil de Salvador com IDEB em 379 escolas, INSE em 465 e docentes em
  1.410 de 1.432, conferido no navegador.

## LXC

- `deploy_db_dev` (change `rede_escolas_ativas`), `deploy_backend_dev`,
  `deploy_analytics_dev` e `deploy_frontend_dev`. Conferência no roteiro
  `docs/admin/deploy-lxc-2026-11-16.md`.
