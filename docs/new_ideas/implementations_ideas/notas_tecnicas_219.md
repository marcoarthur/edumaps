# Nota técnica 219: índice vazio, não 0, para escola sem registro (#467)

Achados RZ-01 e RZ-02 da sétima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-indices-na-base.md`).
Um PR: #468 (merge `a778553`).

## O problema

- **O 0 lia como nota baixa.** Na MV `clean.mv_escolas_scores`, a escola sem
  o registro de que um índice depende ficava com 0, pelo `COALESCE(…, 0)` da
  junção final e pelos `CASE … ELSE 0`. São sobretudo centros de atendimento
  especializado e escolas sem turma regular: 2.067 escolas sem docentes e
  1.774 sem matrículas no Censo 2025.
- **Contradizia a regra da própria base.** A ajuda da base diz "ausência é
  célula vazia, nunca zero" (#154); a dos rankings dizia "fica com 0".
- **Efeito medido:**
  - em Divino de São Lourenço (ES), a média da capacitação docente era 5,93
    com essas escolas e 7,91 sem elas;
  - num ranking das 495 redes municipais da BA e do ES pela média, 206 mudavam
    10 posições ou mais;
  - Salvador tinha 28 zeros no fim do ranking de escolas, e as últimas eram
    instituições de atendimento a crianças com deficiência.
- **RZ-02 (detalhe):** o dicionário de `indice_infraestrutura` mandava usar a
  coluna "Infraestrutura básica", que a base não tem, e a fonte aparecia como
  "Índices do EduMaps (EduMaps)".

## Decisões (developer, 2026-11-17)

- **Opção A:** `NULL` na própria MV, por uma change nova. A versão sobe para
  `indices-v3`. A opção B, só trocar o 0 por vazio na base e no ranking,
  deixaria a base diferente do número citado.
- **A capacidade de atendimento também fica vazia sem matrícula,** porque 60%
  dela dependem das matrículas.
- **O IVET sobe para `ivet-v1.5`,** pela mesma regra da #459: a agregação não
  muda, mas os resultados mudam.

## O que foi construído

- **Change `escolas_scores_sem_registro`** (apaga e recria a MV, com índices,
  comentários e GRANT):
  - um `WHERE` em cada CTE: `qt_mat_bas > 0` (atendimento e diversidade),
    `qt_doc_bas > 0` (docente) e `qt_gest_bas > 0` (gestora);
  - sai o `COALESCE(…, 0)` desses quatro na junção final. Infraestrutura e
    sustentabilidade vêm do cadastro da escola e continuam sempre presentes;
  - o COMMENT diz `VERSÃO indices-v3`;
  - o verify falha se houver valor onde falta o docente, se a definição
    ainda tiver o `COALESCE` ou se faltar a versão.
- **Registro e textos:**
  - `indices-v3` em `$INDICES_VERSAO` e `@INDICES_HISTORICO`;
  - o `%METODO` dos quatro índices diz "fica sem o índice (vazio, não 0)".
- **Base de análise:**
  - o "Vazio:" do dicionário diz qual registro falta;
  - RZ-02: a infraestrutura aponta as colunas `in_*_inexistente` e
    `in_banheiro` e a soma da ajuda;
  - a fonte própria aparece sem o órgão (`_fonte_nome`).
- **Consumidores:**
  - o ranking ao vivo e o `bin/ranking.pl` já filtravam `IS NOT NULL`;
  - as escolas semelhantes já exigiam as seis notas, e 2.073 escolas saem da
    lista;
  - o IVET já tirava o componente `NA` do denominador (#154);
  - o relatório R descarta o índice sem valor;
  - `View::ClusterEscola` não tem uso.

## Dois defeitos achados na validação

- **`bin/ranking.pl` nunca removia.** O upsert só grava quem está no
  ranking. Sem a correção, as 2.067 escolas ficariam em
  `analytics.ranking_escola` com o 0 antigo. Agora, depois de cada
  indicador e rede, o script apaga as linhas com `data_atualizacao < now()`.
  O script inteiro roda numa transação, e `now()` é o início dela. O teste
  `t/06-tools/ranking_pre_calculado.t` cobre isso.
- **Painel da escola com 500.** Quando a escola não tem vizinha com etapa em
  comum, o painel cai no método antigo de semelhantes, que pode trazer uma
  escola sem linha de matrículas. O `->first->{matriculas}` quebrava. O
  defeito já existia antes desta issue (o centro de atendimento de Divino de
  São Lourenço nunca teve matrícula) e foi corrigido no mesmo PR. O painel
  do próprio centro de atendimento segue com 404, porque `panel_info` exige
  a matrícula; isso ficou fora do escopo.

## O verify antigo

- O `verify/escolas_scores.sql` da change original exigia que nenhum score
  fosse nulo. Falhou no gate do CI (`sqitch verify` global).
- O verify não entra no `change_id`, então a check foi trocada: só
  infraestrutura e sustentabilidade continuam obrigatórias. O precedente é o
  `ea22561`.

## Validação

- Perl: suíte inteira, 196 arquivos, 1725 testes. R: `testthat` inteiro.
  CI do PR verde.
- Sqitch no banco de fixtures: deploy, `revert --to escolas_scores_versao`,
  `deploy --verify` e o verify global.
- Local (Censo 2025, 180.540 escolas):
  - escolas com o índice vazio: 2.067 na capacitação docente, 1.774 na
    diversidade e na capacidade de atendimento, nenhuma na capacidade
    gestora;
  - ranking pré-calculado com 178.473 escolas na capacitação docente;
  - 178.467 escolas com vetor de semelhantes;
  - IVET `ivet-v1.5` com 180.540 escolas;
  - Divino de São Lourenço com média 7,91; Salvador com 1.410 escolas no
    ranking de capacitação, em vez de 1.432;
  - a base da BA e do ES sai como `…-indices-v3.csv`, com 315 células vazias
    na capacitação.

## LXC

- `deploy_db_dev`, `deploy_backend_dev`, `bin/ranking.pl --source mv`,
  `refresh_school_embeddings`, `deploy_analytics_dev` e `refresh_ivet`.
- Passos e números esperados no roteiro `docs/admin/deploy-lxc-2026-11-16.md`.
