# Nota técnica 229: escolas semelhantes pela distância entre as notas (#487)

Achados RL-01 e RL-02 da décima sétima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-18-p4-escolas-semelhantes.md`).
Um PR: #488 (merge `23bdc87`).

## O problema

- **RL-01 (atrapalha).** As escolas semelhantes do painel da escola vinham
  da distância de **cosseno** (pgvector `<=>`) sobre as seis notas de
  `clean.mv_escolas_scores`. O cosseno mede o ângulo entre os vetores e
  ignora o nível: (2,…,2) e (8,…,8) ficam idênticos.
  - Caso: o CEIFAR (29445906, Salvador) tinha como "mais parecida" uma
    escola 2 a 3 pontos abaixo em todas as notas (cosseno 0,0034;
    euclidiana 6,3).
  - Amostra de 2.000 escolas: 133 primeiras vizinhas com 1 ponto ou mais de
    diferença na média das notas, contra 10 com a euclidiana.
  - O cosseno quase não separa as escolas (mediana 0,0088 na 3ª vizinha),
    e por isso a #421 tinha tirado o número do cartão.
- **RL-02 (detalhe).** O cartão não dizia o quanto a vizinha se parecia, e
  a ajuda falava de porcentagem e de "contexto, não resultado".

## Decisões

- **Distância euclidiana** (`<->`) nas seis notas, na escala de 0 a 10. Não
  normalizar: as seis notas já estão na mesma escala, e a distância em
  pontos se lê.
- **Change nova `school_embedding_l2`** (a `school_embedding` está
  deployada): troca o índice HNSW para `vector_l2_ops`. Os vetores não
  mudam; a task diária `refresh_school_embeddings` segue igual.
- **Sem `similarity = 1 − distância`**, que só valia no cosseno.
- **Notas da vizinha ao lado das da escola**, além da distância: a
  pesquisadora vê em qual nota está a diferença.
- **O caminho de reserva** (método em memória, quando o banco falha) não
  manda a distância, porque é outra métrica; o cartão fica sem número.
- **Versão na chave do `Cache::SchoolSearch`** (`v2`): o `panel/info` fica
  uma semana em cache e serviria a resposta do cosseno depois do deploy.
  Esvazia de uma vez o cache das buscas.

## O que foi construído

- `ResultSet::SchoolEmbedding::similar_to`: ordena por `<->`; devolve
  `distance`, `notas` e `notas_alvo` (`real[]`, na ordem de
  `Task::SchoolEmbedding::@NOTAS`).
- `Profile::panel_info`: cada vizinha com `distancia` (2 casas) e `notas`
  (`{id, rotulo, valor, escola}`).
- `SimilarSchools.svelte`: "a 1,6 ponto" e a tabela "ela / esta"; rodapé
  com o critério.
- Ajuda `escolas-semelhantes.md`: tabela do critério e da medida dos três
  lugares (perfil: Gower, %; painel: euclidiana, pontos; painel do gestor:
  porte, localização, INSE e etapas, %). Ficha `busca/similaridade.md`.

## Validação

- Perl: caso novo em `t/02-models/school/embedding.t` (notas 5 → a de 5,5
  antes da de 8; distâncias 0,5·√6 e 3·√6) e a API do painel em
  `t/05-tasks/school_embedding.t`. Suíte: 197 arquivos, 1.748 testes.
- vitest: cartão e `transformPanelData`. CI do PR verde.
- Sqitch no banco do CI: deploy, revert `--to rede_escolas_ativas`,
  deploy e `verify` global.
- Local: o CEIFAR tem a 29398037 em primeiro (1,56 ponto), depois a
  29464340 (1,81) e a 29435358 (1,93). O plano da consulta filtra o
  município e ordena (busca exata); o índice HNSW não entra, e por isso
  não há vizinha perdida pela busca aproximada.

## O que fica

- O painel do gestor usa o cosseno sobre porte, localização, INSE e etapas
  (vetor de 10 dimensões). Lá as dimensões são de 0 a 1 e quase todas
  binárias, e o efeito é outro; não entrou na issue.

## LXC

- `deploy_db_dev` (change `school_embedding_l2`), `deploy_backend_dev`,
  `deploy_minion_dev` e `deploy_frontend_dev`.
