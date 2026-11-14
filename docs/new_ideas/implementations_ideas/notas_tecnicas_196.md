# Nota técnica 196: embedding das escolas diário, sem 0 para ausência (#413)

A issue #413 nasceu como achado da reavaliação da #138 (spec
`docs/specs/2026-11-13-similaridade-territorial.md`). Foi entregue no PR #414
(merge `fddd9fe`).

## O problema

O painel da escola mostra as 3 escolas mais parecidas do município. Elas saem
de um cosseno no `pgvector`, sobre `analytics.school_embedding`: as 6 notas de
`clean.mv_escolas_scores`.

1. **O embedding nunca era atualizado.** A task `refresh_school_embeddings`
   existia, mas nada a enfileirava. O embedding era o backfill da migration
   (2026-09-16). Um Censo novo deixaria o painel comparando notas velhas, sem
   aviso. A escola nova não teria vizinhas e cairia, calada, no método antigo
   em memória.
2. **Nota ausente virava 0.** Isso valia para o backfill e para o refresh
   (`COALESCE(score, 0)`). No cosseno, o 0 muda a direção do vetor e aproxima
   a escola das que vão mal naquela nota. Contraria a #154.

**Medido em 2026-11-13:** o banco local estava em dia (0 divergências) e não
tinha nenhuma escola com nota nula. Nenhum dos dois problemas tinha efeito
ainda; os dois estavam sem proteção.

## Decisões

1. **Agenda diária às 05:00 BRT**, no padrão autorreagendável da
   `planos_oficiais` (#406): lock Minion, início no boot do worker e modo
   manual.
   - **Por que não um gatilho:** o refresh da matview das notas e o do
     ranking são manuais (`bin/ranking.pl`). Não existe um job onde
     pendurar o embedding.
   - **Por que diário basta:** a rodada é barata (0,86 s para 180.540
     escolas) e só grava o que mudou.
2. **O refresh é uma sincronização.**
   - **DELETE:** sai a escola que não está nas notas com as 6 presentes.
   - **INSERT … ON CONFLICT DO UPDATE … WHERE … IS DISTINCT FROM:** a escola
     igual não é regravada, o que poupa o índice HNSW.
   - **Transação:** as duas instruções rodam juntas (`txn_do`).
3. **A escola com nota nula fica fora** do embedding: sem vizinhas, em vez de
   vizinhas erradas.
   - **O que o painel mostra:** `similar_schools_motivo: "sem_dado"`, e a
     tela diz "Sem dado para comparar".
   - **O método antigo** (indicadores do sistema C, em memória) continua só
     para erro de banco e para a escola completa que ainda não entrou no
     embedding (entre o Censo e a rodada das 05:00).
4. **A migration não foi editada.** O backfill deployado mantém o
   `COALESCE`; a primeira rodada diária corrige o conteúdo. Sem change nova,
   porque não há mudança de estrutura.
5. **Um teste sem matview de mentira.** `atualizar($dbh, $fonte)` aceita uma
   tabela de origem, validada por padrão de nome. O teste usa uma tabela
   temporária numa transação desfeita no fim, porque o DELETE da sincronização
   apagaria o embedding das fixtures.

## Testes

- **`t/05-tasks/school_embedding.t`:**
  - agenda;
  - sincronização: insere, atualiza, mantém, remove e deixa fora a nota nula;
  - task manual sobre as notas reais;
  - `notas_completas`;
  - painel com e sem notas.
- **Vitest:** `SimilarSchools.test.js` e o motivo em
  `transformPanelData.test.js`.
- **CI do PR verde** (Perl, vitest, build).

## Deploy

- **Local:** imagens reconstruídas a partir do `main`. O md5 da task
  (`f70a603ea804`) bate no backend e no minion, a mensagem está no bundle, e a
  rodada diária fica agendada às 05:00.
- **LXC (2026-11-16):** `deploy_backend_dev` e `deploy_minion_dev`, com a
  master key. Sem `deploy_db_dev` para esta issue. A primeira rodada no LXC
  troca os 0 do backfill, se houver nota nula lá.
