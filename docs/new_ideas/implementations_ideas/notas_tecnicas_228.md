# Nota técnica 228: evolução da escola com o SAEB por etapa (#485)

Achados RM-01 e RM-02 da décima sexta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-evolucao-saeb.md`).
Um PR: #486 (merge `3d58db2`). Ciclo em modo autônomo (delegação do
developer até 7h de 18/11), com aviso pelo Telegram.

## O problema

- **RM-01 (atrapalha).** A seção "Evolução" do perfil da escola lia o SAEB
  de `clean.inep_notas_desagregadas`: uma linha por escola e ano, sem a
  etapa. Em 2023, as 41.301 linhas batem uma a uma com os **anos
  iniciais** da planilha do IDEB.
  - 18.533 escolas só de anos finais ou de ensino médio ficavam sem série
    do SAEB, embora `ideb_notas_escolas` traga as notas delas por etapa.
  - 32.544 escolas com anos iniciais e outra etapa viam a série dos anos
    iniciais rotulada só "Nota média (SAEB)".
- **RM-02 (detalhe).** A variação é a última edição menos a primeira. Com
  uma edição só, 0, e a tela mostrava "▲ 0.0" (17.217 séries do IDEB).

## Decisões (autônomas)

- **O SAEB da mesma consulta do IDEB**, por etapa. A tabela
  `inep_notas_desagregadas` deixa de ser lida pela evolução (fica no banco;
  não há change).
- **Sem variação** com uma edição só (`NA`), e a tela já esconde o ▲/▼
  quando a variação é nula.
- **Chave de cache** da evolução com `versao => 2`.

## O que foi construído

- `load_school_evolution`: a consulta do IDEB traz `nota_media`,
  `nota_matematica` e `nota_portugues`; o SAEB sai dela, com a etapa.
- `.school_evolution_bind`: a etapa do SAEB quando existe; aceita os nomes
  antigos (`nota_mat`, `nota_por`) para os testes e fixtures antigas.
- `analyze_school_evolution`: `variacao` `NA` com `n_anos == 1`.
- Ajuda `perfil-da-escola.md` e o texto de ajuda da seção.

## Validação

- R: `testthat` inteiro, com testes novos (SAEB por etapa, série de uma
  edição). Perl: 197 arquivos, 1744 testes. Frontend: 1345 testes. CI do PR
  verde.
- Local: o colégio estadual de Salvador (29192013), antes sem série do
  SAEB, tem matemática dos anos finais de 2005 a 2023 (+14,6) e o ensino
  médio de 2023 sem variação.

## O que fica

- `clean.inep_notas_desagregadas` não tem mais leitor conhecido na evolução.
  Vale conferir os outros usos antes de propor a remoção.

## LXC

- `deploy_analytics_dev`, `deploy_backend_dev` e `deploy_frontend_dev`.
  Sem change.
