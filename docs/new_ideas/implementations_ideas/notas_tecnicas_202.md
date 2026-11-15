# Nota técnica 202: agrupamento guardado, com universo, link e CSV (#427)

Dois PRs, a partir dos achados AN-05 e AN-09 da curadoria P3–P6:

| PR | Merge | Entrega |
|---|---|---|
| #433 | `81eaddd` | execução guardada, universo, link `?execucao=` e CSV |
| #434 | `a809061` | grupo pequeno sem gradação e "o que mais distingue" cada grupo |

## O problema

O agrupamento da página de Análises funcionava assim:

1. o job apagava e refazia `clean.school_indicators` (TRUNCATE + INSERT para
   o ano IDEB);
2. o motor R gravava `cluster_id` nessa mesma tabela e os metadados em
   `analytics.clustering_metadata`;
3. o mapa lia `school_indicators` pelo recorte, e o resumo lia "o run_id mais
   recente", qualquer que fosse o recorte.

O resultado durava até a próxima execução de qualquer pessoa. Dois usuários
ao mesmo tempo viam o resultado um do outro, e o cache do cliente HTTP ainda
podia devolver um resultado sem regravar a tabela. Não havia link nem
exportação. Os números também não fechavam: em Vitória, 226 escolas no Censo,
180 agrupadas e 167 no mapa. O R descartava as incompletas só com um
`warning`, e o mapa escondia as escolas sem coordenada.

## Execução guardada (#433)

- **Change `analytics_cluster_execucoes`:**
  - `cluster_execucoes`: `run_id`, `job_id`, `estado`, `recorte`,
    `parametros`, `universo` (jsonb) e `expira_em` (90 dias);
  - `cluster_atribuicoes`: `(run_id, co_entidade)` com grupo, rótulo, rank e
    `valores` (jsonb com os indicadores na unidade original), saindo junto
    pela FK `ON DELETE CASCADE`;
  - sem dado pessoal, no schema `analytics`, legível pelo `edumaps_leitor`.
- **Divisão do trabalho:**
  - o **backend** cria a execução antes de chamar o R. O `run_id` é
    `run_<epoch>_<8 hex>`, que ordena como os antigos e não colide no mesmo
    segundo. Ele conta `n_total` e `n_inativas` no recorte e põe
    `tp_situacao_funcionamento = 1` no filtro: as escolas que não funcionam
    mais saem antes de agrupar (decisão do developer);
  - o **R** recebe o `run_id`, grava as atribuições por uma tabela temporária
    (`jsonb_build_object` dos `v_<indicador>`) e mescla ao universo
    `n_recorte`, `n_incompletas`, `sem_dado` por indicador, `n_agrupadas` e os
    indicadores sem variância. Sem `run_id`, o comportamento é o antigo;
  - o cliente chama o R **sem cache** quando há `run_id`.
- **Rotas:**
  - `/api/cluster/execucoes/:run_id` devolve parâmetros, universo,
    `n_atribuicoes`, `n_no_mapa` e o resumo daquele `run_id`;
  - `/escolas` traz o GeoJSON, com nome e coordenada do Censo mais recente;
  - `/csv` exporta com `;`, decimal com vírgula e BOM, para o Excel em PT-BR.
  - Vencida ou inexistente dá 404.
- **Tela:**
  - o fim do polling traz o `run_id` (no snapshot de `/api/task/progress`), e
    a tela carrega a execução e põe `?execucao=` na URL;
  - abrir o link remonta o formulário, com o valor de cada `<select>` vindo
    da própria opção (número), e mostra o resultado gravado, sem recalcular
    (decisão do developer: o link cita o resultado, não os parâmetros);
  - a caixa **Universo** traz os totais, os motivos, as escolas sem
    coordenada, **Copiar link**, **Baixar CSV** e a validade.
- **Validade:** as vencidas saem a cada execução nova, e não por uma tarefa
  diária como no plano. A leitura já ignora as vencidas, e sem execução nova
  nada cresce.

**Pegadinha:** `co_entidade` é bigint e o RPostgres o devolve como
`integer64`. Casar os valores com as atribuições por `rownames` perdia o id,
e o `valores` saía `{}`. O teste de ponta a ponta pegou o erro; agora os dois
lados usam o mesmo vetor de ids.

## Rótulos e destaques (#434)

- **Grupo pequeno:** menos de 5 escolas ou menos de 2% das agrupadas vira
  "Grupo pequeno (N escolas)" no resumo, no mapa e no CSV (decisão do
  developer), e os demais grupos mantêm a gradação. O rótulo genérico passou
  de "Cluster N" a "Grupo N".
- **O que mais distingue:**
  - o R grava em `extra_metrics.destaques` os 3 indicadores de maior |z|, com
    z = (média do grupo − média geral) / desvio padrão, mais as duas médias;
  - a tela mostra o nome legível (do comentário da coluna, sem a pergunta e
    sem a fórmula), o valor do grupo × a média geral e ▲/▼, em % para
    indicadores de sim/não e proporções.
  - Antes, eram os 3 maiores valores brutos do centroide, misturando
    escalas, e com o nome da variável.

## Validação

- R: 2246 testes, 0 falhas. Perl `-j4`: 190 arquivos, 1692 testes. vitest:
  147 arquivos, 1283 testes. Os testes com o R (`clustering*.t`,
  `clustering_execucao.t`, `t/dbic/`) passam contra a stack local.
- Navegador, Vitória e Infraestrutura:
  - K-Means 3: 226 no recorte, 180 agrupadas e 46 que não funcionam mais;
    13 escolas sem coordenada ficam fora do mapa (33 + 63 + 71 = 167);
  - o link reabre o resultado com o formulário preenchido, e o CSV tem 180
    linhas;
  - K-Means 5: "Grupo pequeno (1 escola)" e destaques legíveis, por exemplo
    "Possui laboratório de ciências: 81% × 44%".
- Depois do merge, as imagens e o `sqitch` foram reconstruídos do `main`, e a
  imagem de cada contêiner foi conferida pelo ID.

## Deploy

No roteiro do LXC de 16/11:
- `deploy_db_dev`: a change nova passa a ser a última do registry;
- backend, minion, motor R e frontend;
- conferir com um agrupamento de teste: a caixa **Universo** e o **Baixar CSV**.
