# Nota técnica 227: IDEB do perfil comparado na mesma etapa (#483)

Achados RN-01 e RN-02 da décima quinta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-perfil-ideb-etapa.md`).
Um PR: #484 (merge `02d0666`). Ciclo em modo autônomo (delegação do
developer até 7h de 18/11), com aviso pelo Telegram.

## O problema

- **RN-01 (atrapalha).** No perfil da escola e no perfil analítico da rede,
  `.profile_pop_body` (edumapsr) pega, de cada escola, a linha do IDEB da
  **etapa de maior nota** (`DISTINCT ON … ORDER BY nota_media DESC`). A
  escola entra com uma etapa, e o Brasil, o município, a rede e o grupo,
  com etapas misturadas.
  - "Brasil" do perfil: 5,33. Por etapa: 5,66 (anos iniciais), 4,74 (anos
    finais), 4,26 (ensino médio).
  - Uma escola de ensino médio na média nacional aparecia 1,07 abaixo; uma
    de anos iniciais, 0,33 acima. 59.445 perfis afetados.
- **RN-02 (detalhe).** 21.197 escolas têm nota em duas ou mais etapas, e o
  perfil mostrava só a de maior nota.

## Decisões (autônomas)

- **A etapa da escola continua a de maior nota** (o rótulo de sempre, #431),
  mas **todas as comparações** do IDEB e do SAEB passam a ser dessa etapa.
- **Consulta leve dedicada** (`.profile_ideb_etapa_stats`), em vez de
  recalcular a população inteira: só o IDEB e a lista de escolas do Censo,
  por escopo. Na referência pré-computada e no perfil de grupo persistido,
  que misturam etapas, as duas linhas do IDEB e do SAEB são trocadas.
- **Escola sem IDEB:** sem comparação nessas linhas (antes recebia a média
  misturada).
- **Perfil da rede:** seis linhas por etapa no lugar das duas, com o Brasil
  da mesma etapa; o mesmo nos grupos.
- **Chave de cache:** `PROFILE_REGRA_SINAIS` 4 (perfil da escola) e
  `versao => 3` (perfil da rede).
- **Sem change no banco.** A tabela `analytics.school_profile_reference`
  continua com o IDEB misturado, mas deixa de ser usada nessas linhas.

## O que foi construído

- `R/model-datasource-postgres-profile-ideb-etapa.R`: `IDEB_ETAPAS`,
  `IDEB_ETAPA_TEXTO`, `.ideb_etapa_valida` (whitelist; a etapa entra literal
  no SQL só depois dela), `.profile_ideb_etapa_stats` e
  `.school_profile_ideb_etapas`.
- Perfil da escola: `.profile_pop_body(…, ideb_etapa)`; a linha da escola, o
  frame do município (fallback de grupo e de escolas semelhantes) e os
  peers persistidos usam a etapa; override das linhas IDEB/SAEB do
  município, da rede, do Brasil e do grupo persistido; tabela
  `ideb_por_etapa`; metadata `ideb_comparacao = "mesma_etapa"` e
  `n_ideb_*`.
- Perfil da rede: `.network_ideb_por_etapa` troca as linhas e acrescenta as
  médias por etapa dos grupos (uma consulta agrupada).
- Rótulo: "IDEB observado 2023, anos finais".
- Frontend: seção "IDEB em cada etapa" no perfil da escola
  (`IdebPorEtapa.svelte`); rótulos e ajuda do perfil da rede; o
  `ideb_observado` de um cache antigo aparece como "etapas misturadas".
- Ajudas `perfil-da-escola.md` e `comparar-redes.md`; funcionalidades.

## Validação

- R: `testthat` inteiro; `test-profile-ideb-etapa.R` confere as médias por
  etapa contra a planilha no banco de fixtures. Perl: 197 arquivos, 1744
  testes. Frontend: 1344 testes. CI do PR verde.
- Local: colégio estadual de Salvador (29192013), anos finais: escola 4,5;
  Brasil 4,74 (antes 5,33); município 4,05; grupo 4,0. Ensino médio 3,6
  contra 4,26. Perfil da rede estadual de Salvador: anos finais 3,92 (101
  escolas) contra 4,74. Perfil da escola em 1,4 s. Conferido no navegador.

## Fecha

- Com a #481 e a #483, o produto inteiro compara o IDEB dentro da etapa:
  base, ranking, comparação de redes, agrupamento e os dois perfis.

## LXC

- `deploy_analytics_dev`, `deploy_backend_dev`, `deploy_frontend_dev`. Sem
  change; o cache dos perfis troca de chave sozinho.
