# Nota técnica 226: agrupamento por desempenho numa etapa (#481)

Achados RO-01 e RO-02 da décima quarta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-17-p4-agrupamento-desempenho.md`).
Um PR: #482 (merge `9a35991`). Ciclo em modo autônomo (delegação do
developer até 7h de 18/11), com aviso pelo Telegram.

## O problema

- **RO-01 (atrapalha).** `Task::Clustering::_indicators_build_sql` gravava
  em `clean.school_indicators` a **média entre as etapas** de cada escola.
  - A escala do SAEB cresce com a série e o IDEB cai (Brasil, 2023:
    matemática 217, 250 e 268; IDEB 5,66, 4,74 e 4,26).
  - Misturadas, a correlação matemática × IDEB é 0,40; dentro de cada etapa,
    de 0,89 a 0,96.
  - Na execução guardada do ES, o grupo "Alto desempenho" tinha IDEB 5,15 e o
    "Baixo", 5,50. Nenhuma das 407 escolas só de anos iniciais estava no
    "Alto", e 67 das 71 só de ensino médio estavam. O agrupamento separava a
    etapa oferecida.
- **RO-02 (detalhe).** O conjunto "Infraestrutura escolar" usava
  `in_esgoto_rede_publica` e `in_energia_rede_publica`. 70.538 escolas têm
  esgoto fora da rede (fossa) e só 4.636 não têm esgoto.

## Decisões (autônomas)

- **A etapa é obrigatória** sempre que as features usam uma coluna do
  IDEB/SAEB, com ou sem o conjunto pronto. Sem ela, 400. Não há "todas as
  etapas": a média entre etapas é o defeito.
- **Só as escolas com nota na etapa** entram (as outras ficam sem valor e o
  universo as conta como "sem dado").
- **Execução antiga** continua abrindo, marcada como "etapas misturadas" na
  tela e no CSV.
- **Infraestrutura:** os itens "inexistente" com direção −1, como a
  infraestrutura básica do ranking (#457). Água potável continua (0 é água
  não potável, uma falta de qualidade).
- **Sem change no banco:** `clean.school_indicators` já tem as colunas
  `*_inexistente` (`e.*`).

## O que foi construído

- `EduMaps::Presets`: `etapa_filter` e `etapas` no `desempenho`; helpers
  `etapas`, `etapa`, `ideb_features` e `usa_ideb`; infraestrutura com os
  inexistentes.
- `Controller::Task::request_cluster`: valida `etapa`, exige-a com IDEB e
  põe a etapa no conceito do rótulo ("desempenho dos alunos nos anos
  iniciais"). O preset não é alterado (cópia).
- `Task::Clustering`: `etapa` nos parâmetros guardados; o SQL filtra
  `etapa = ?` (com `undef`, a média, que só acontece quando o IDEB não é
  agrupado).
- `Controller::Cluster::execucao_csv`: coluna `etapa_ideb`.
- Frontend: seletor de etapa (também para a lista própria com colunas do
  IDEB), a etapa na caixa Universo e a restauração pela URL da execução.
- Ajuda `agrupamentos-de-escolas.md` e funcionalidade `clusters.md`.

## Validação

- Perl: 197 arquivos, 1744 testes; `t/05-tasks/clustering_etapa.t` roda o
  SQL do job numa tabela temporária com uma escola de duas etapas. R:
  `testthat` inteiro. Frontend: 1342 testes. CI do PR verde.
- Local, ES, IDEB 2023, K-Means com 4 grupos, anos iniciais: IDEB por grupo
  5,25, 5,63, 6,13 e 7,02, em ordem; 823 escolas agrupadas de 3.046.
  Infraestrutura do ES roda com os itens novos.

## O que fica

- O perfil analítico da rede ainda usa, de cada escola, a etapa de maior
  nota (#479, rotulado). O IDEB por etapa no perfil é a melhoria que falta
  para o produto inteiro seguir a mesma regra.

## LXC

- `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`. Sem
  change e sem recálculo.
