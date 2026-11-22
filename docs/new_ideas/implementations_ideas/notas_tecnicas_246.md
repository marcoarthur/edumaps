# Nota técnica 246: "sem especialização" é sem formação continuada (#522)

Achados QU-01 e QU-02 da trigésima quarta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-22-p4-perfil-docente-regioes.md`).
Um PR: #523 (merge `9feaa4d`).

## O problema

- **QU-01 (atrapalha).** A coluna `prop_sem_especializacao` (base, perfil
  da escola e da rede, sinais de atenção e agrupamento) vem de
  `qt_doc_bas_espec_nenhum`. O dicionário do INEP descreve essa variável
  como "Outros cursos, Formação Continuada com no mínimo 80 horas,
  Nenhum". No Brasil, especialização é a pós-graduação lato sensu.
  - Em 56% das escolas, pós-graduação + "sem especialização" passava de 1.
  - A coluna acompanha a formação continuada (correlação de postos de
    0,93), e não a pós (0,38).
  - Na rede estadual de SP: 32% com pós e 91% "sem especialização".
  - O mesmo erro estava nos comentários do banco das outras 18 colunas
    `qt_doc_bas_espec_*` ("Docentes com especialização em creche"…), que
    chegam ao agrupamento e ao dicionário do Assistente do Censo.
- **QU-02 (detalhe).** `prop_formacao_continuada` soma cursos (limite 1).
  A proporção de professores com ao menos um curso é
  `1 − prop_sem_especializacao`. Na rede estadual de SP: 15,5% contra 9,5%,
  e o dicionário não dizia a diferença.

## Decisões

- **Na base, o nome muda (opção A, do developer):**
  - a coluna passou a `prop_sem_formacao_continuada`, na mesma posição,
    sem manter a antiga: um script com o nome antigo dá erro, em vez de
    seguir lendo "especialização";
  - o dicionário e a ajuda dizem o nome antigo.
- **Dentro da plataforma, o id `prop_sem_especializacao` fica.** Ele está:
  - na tabela `clean.school_indicators` (preenchida pelo agrupamento);
  - nos presets, nas direções e nos ids dos sinais;
  - no sentido do indicador no frontend;
  - nos perfis em cache.

  Renomear não mudaria nada na tela e tocaria em tudo isso. Mudam só os
  textos: o rótulo do motor R, a mensagem do sinal, a instrução do
  Assistente, a descrição do preset e as dicas do frontend.
- **Cache:** a versão do perfil da escola (`PROFILE_REGRA_SINAIS` /
  `$PERFIL_REGRA_SINAIS`) foi de 6 para 7, e a do perfil da rede (`versao`
  na chave do cache) de 4 para 5. Os perfis guardados com o rótulo antigo
  deixam de ser servidos. É o mesmo mecanismo da #431, quando também mudou
  um rótulo.
- **Comentários do banco por change nova** (`docentes_formacao_continuada_rotulos`).
  A `censo_docentes`, que já está aplicada, não foi editada. A change
  corrige os comentários de:
  - as 19 colunas `qt_doc_bas_espec_*`;
  - `school_indicators.prop_sem_especializacao`, dizendo que o nome é
    histórico (o `TRUNCATE` + `INSERT` do agrupamento mantém o comentário);
  - `mv_escolas_scores.score_capacitacao_docente`.

  O verify falha se algum comentário de `qt_doc_bas_espec_*` ainda disser
  "especializa".
- **Sem versão nova dos índices nem do IVET.** A fórmula não mudou: em
  `ivet.md` e na documentação da MV, só "especializações" virou "formações
  continuadas".

## Validação

- **Docker local:**
  - os contêineres sqitch, backend, os dois minions, analytic e frontend
    foram refeitos, e a change foi aplicada no `edumaps_dev`;
  - perfil da rede de Franca: "Docentes sem formação continuada" (61,7%);
  - perfil da escola 35010310: o rótulo na tabela, o sinal "(80h ou mais)"
    e a dica da regra;
  - o CSV de SP sai com `prop_sem_formacao_continuada`.
- **Testes:**
  - Perl: 203 arquivos e 1.817 testes. O `docentes_formacao_continuada.t`
    é novo (comentários do banco); o `base_analise.t` confere o nome novo,
    a ausência do antigo e cursos contra pessoas; o `analytics.t` confere
    as versões do cache;
  - vitest: 1.377 testes (o `AttentionFlags.test.js` é novo);
  - R: teste do rótulo, da mensagem do sinal e da versão 7;
  - Sqitch: deploy, revert `--to` e redeploy no banco de CI local;
  - CI do PR verde (Perl, R, vitest, build).

## Pendências

- No LXC:
  - `deploy_db_dev` (change `docentes_formacao_continuada_rotulos`);
  - `deploy_backend_dev`, `deploy_minion_dev`, `deploy_analytics_dev` e
    `deploy_frontend_dev`.
- O banco de CI local acusa `rede_escolas_ativas` no verify (190 contra
  176 escolas). São resíduos de testes nesse banco, e o CI, que parte de
  um banco novo, não acusa.
