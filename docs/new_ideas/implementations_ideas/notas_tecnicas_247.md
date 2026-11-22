# Nota técnica 247: concursados vazios nas privadas (indices-v7) e o agrupamento com o nome da base (#524)

Achados QT-01 e QT-02 da trigésima quinta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-22-p4-agrupamento-docencia.md`).
Um PR: #525 (merge `06fba4f`).

## O problema

- **QT-01 (atrapalha).** O dicionário do INEP diz que o vínculo do docente
  (concursado, contrato, terceirizado, CLT) é "apenas para docente de
  escola pública". Mesmo assim, `prop_efetivos` saía 0 em toda privada, e
  esse 0 contava contra ela:
  - **agrupamento:** o conjunto "Qualidade de docência" usa concursados
    como "maior é melhor", e 92,7% das privadas de SP caíam em "Baixa" ou
    "Muito baixa";
  - **índice de capacitação docente:** os concursados valem 20%, e a
    privada ficava com teto de 8. Média no Brasil: 3,88 nas privadas
    contra 6,40 nas públicas;
  - **ranking que mistura as redes:** em Franca, 116 das 136 privadas
    ficavam na metade de baixo;
  - **base, perfil e relatório por rede:** o 0 aparecia como dado.
- **QT-02 (detalhe).**
  - O CSV do agrupamento ainda trazia `prop_sem_especializacao`, enquanto a
    base usa `prop_sem_formacao_continuada`.
  - A tela do agrupamento faz o rótulo a partir do comentário da coluna, e
    o comentário escrito na #523 virava "…80 horas . O nome da coluna é
    histórico: não é a pós-graduação".
  - A #523 também tirou "NULL sem docente (#467)" do comentário de
    `score_capacitacao_docente`.

## Decisões

- **Vazio, não 0, e o peso redistribuído no índice.** A change
  `escolas_scores_vinculo` recria `clean.mv_escolas_scores`.
  - Na privada, a capacitação docente é
    `(0,3·superior + 0,3·pós + 0,2·formação continuada)/0,8`, o mesmo
    padrão do acesso ao cargo na capacidade gestora (#475). Nas públicas,
    nada muda.
  - Versões: `indices-v7` e `ivet-v1.9`, porque o índice é insumo do bloco
    A do IVET.
- **No agrupamento, a privada sai do conjunto docência (opção A do
  developer).** `prop_efetivos` fica vazio na tabela do agrupamento, e a
  regra de sempre (escola sem dado sai) as tira. A caixa Universo conta
  quantas saíram, e a ajuda explica e sugere uma lista sem concursados para
  comparar privadas.
- **O nome da base só no CSV (opção A do developer).** O controller troca
  `prop_sem_especializacao` por `prop_sem_formacao_continuada` no
  cabeçalho. A tabela, os conjuntos prontos e as execuções guardadas seguem
  com o nome interno, e os links de 90 dias continuam abrindo.
- **Comentários curtos.** O texto que importa para a tela vem antes do
  parêntese, porque o rótulo tira o que está entre parênteses: "Docentes
  sem formação continuada (…)" e "Proporção de docentes concursados (…;
  vazia nas privadas…)".
- **Perfil e relatório:**
  - concursados "–" na privada; a versão do cache do perfil da escola foi
    a 8 e a do perfil da rede a 6;
  - a referência pré-computada passa a ter a rede 4 vazia, e a do Brasil
    fica só com as públicas;
  - no relatório por rede, o KPI é "Concursados (redes públicas)", e a
    linha da privada fica vazia.
- **Amostra da base do teste R refeita** na `indices-v7`, com as mesmas
  176 escolas: só a capacitação docente das privadas mudou (até 1,71
  ponto). O bloco R da ajuda trata a parte vazia como o índice.

## Validação

- **Docker local:**
  - O deploy da change estourou o `/dev/shm` (64 MB) do contêiner do
    Postgres na consulta paralela que recria a MV. Funcionou com
    `PGOPTIONS="-c max_parallel_workers_per_gather=0"` num
    `docker compose run` do sqitch. O registro está no roteiro do LXC, cujo
    Postgres não roda em Docker.
  - Rodados: `ranking.pl`, escolas semelhantes (178.467 vetores),
    `refresh_ivet` (`ivet-v1.9`, 180.540 escolas) e a referência do
    perfil.
  - Capacitação docente: média de 4,85 nas privadas (máximo 10) e 6,41 nas
    públicas.
  - Ranking de Franca: 108 das 136 privadas na metade de baixo (eram 116),
    e 5 entre as 30 primeiras (era 1).
  - Perfil da privada 35004827: concursados "–", sem sinal, grupo com
    N = 0.
  - Agrupamento de SP pela docência: Universo com 12.065 sem dado de
    concursados (11.543 privadas e 522 sem docentes), e o CSV com
    `prop_sem_formacao_continuada`.
- **Testes:**
  - Perl: 203 arquivos e 1.819 testes;
  - vitest: 1.378 testes;
  - R (perfil, relatório, IVET e a ajuda da base contra a amostra nova);
  - Sqitch: deploy, revert `--to` e redeploy;
  - CI do PR verde (Perl, R, vitest, build).

## Pendências

- No LXC:
  - `deploy_db_dev` (a change recria a MV);
  - `deploy_backend_dev`, `deploy_minion_dev`, `deploy_analytics_dev` e
    `deploy_frontend_dev`;
  - depois, `ranking.pl`, as escolas semelhantes, `refresh_ivet` e
    `school_profile_refresh.sh`.
- Na tela do agrupamento, os indicadores escolhidos aparecem com o
  comentário inteiro, com a fórmula entre parênteses. Isso já acontecia com
  todos os indicadores antes deste ciclo.
- No perfil da privada, a coluna Brasil de concursados mostra a média das
  públicas.
