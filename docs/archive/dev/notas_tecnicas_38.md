
Sim. Para esse teste eu manteria a mesma ideia do teste antigo, mas mudaria o foco: o teste Perl deve validar o **contrato da fronteira Perl → camada analítica → persistência**, enquanto os detalhes do algoritmo Gower ficam cobertos pelos testes R.

Como a nova implementação tem `school_similarity_model → analyze_gower_similarity() → analysis_result → repository`, o teste Perl não precisa conhecer a implementação interna do MVC.

Eu faria assim:

```perl
use strictures 2;
use lib qw(./lib t/lib);

use Test::Mojo;
use Imports;
use Utils qw(
  run_similarity_job
  cleanup_job
  expected_similarity_contract
);

my $t   = Test::Mojo->new('EduMaps');
my $sch = $t->app->schema;
my $tag = '[task] similarity';

# --------------------------------------------------------------------------
# Fixture
#
# Usamos a mesma fonte de dados do teste anterior. A tabela de staging
# representa o dataset que chega à camada analítica.
#
# Não selecionamos `escola`: como é uma coluna character praticamente
# única por entidade, ela seria interpretada como feature categórica pelo
# Gower e distorceria a similaridade.
# --------------------------------------------------------------------------

my $table_name = 'test_similarity';

my $cols = [
  'co_entidade',
  {
    capacidade_atendimento =>
      "score.score_capacidade_atendimento",
    infraestrutura =>
      "score.score_infraestrutura",
    capacitacao_docente =>
      "score.score_capacitacao_docente",
    diversidade_discente =>
      "score.score_diversidade_discente",
    capacidade_gestora =>
      "score.score_capacidade_gestora",
    sustentabilidade =>
      "score.score_sustentabilidade",
  }
];

my $source_rs = $sch->resultset('CensoEscolas')
  ->filter_by(
    no_municipio             => 'Ubatuba',
    tp_situacao_funcionamento => 1,
  )
  ->join('score')
  ->columns($cols);

my $expected_schools_count = $source_rs->count;

$source_rs->save_in_table(
  tbl_name  => $table_name,
  schema    => 'staging',
  temporary => 0,
);

# --------------------------------------------------------------------------
# Gower
#
# O teste Perl não verifica como Gower foi calculado. Isso é responsabilidade
# dos testes da camada R. Aqui verificamos:
#
#   Perl -> job -> R/MVC -> AnalysisResult -> Repository
#
# e o contrato que volta para o consumidor.
# --------------------------------------------------------------------------

subtest qq/
$tag <similaridade gower>
  - executando a análise através do job
  - validando o contrato externo
  - validando a persistência dos pares
/ => sub {

  my $job = run_similarity_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
    metric     => 'gower',
  });

  is $job->info->{state}, 'finished',
    'job de similaridade finalizado com sucesso'
    or diag "resultado: " . ($job->info->{result} // '');

  # O contrato HTTP/job continua sendo responsabilidade da camada Perl.
  like
    $job->info->{result},
    expected_similarity_contract(
      'gower',
      $job->id,
      $table_name,
      features => D(),
    ),
    'estrutura do contrato de similaridade correta';

  my $result = $job->info->{result};

  # ------------------------------------------------------------------------
  # Metadados produzidos pela análise.
  #
  # Estes valores são particularmente úteis porque comprovam que o
  # AnalysisResult atravessou corretamente a fronteira R -> Perl.
  # ------------------------------------------------------------------------

  my $similarity_info = $result->{similarity_info};

  ok $similarity_info,
    'resultado contém similarity_info';

  my $metrics = $similarity_info->{metrics};

  ok $metrics,
    'similarity_info contém metrics';

  # Gower gera somente o triângulo superior da matriz:
  #
  #   C(n, 2) = n * (n - 1) / 2
  #
  # Não esperamos pares (A,A) nem duplicatas (B,A).
  my $expected_pairs =
    $expected_schools_count * ($expected_schools_count - 1) / 2;

  is $metrics->{n_pairs},
    $expected_pairs,
    "n_pairs bate com C($expected_schools_count, 2) = $expected_pairs";

  is $metrics->{n_entities},
    $expected_schools_count,
    'n_entities bate com o número de escolas da fixture';

  ok defined $metrics->{avg_similarity},
    'avg_similarity foi calculada';

  ok $metrics->{avg_similarity} > 0
    && $metrics->{avg_similarity} <= 1,
    'avg_similarity está no intervalo (0, 1]';

  # ------------------------------------------------------------------------
  # Persistência
  #
  # O Repository da nova arquitetura é responsável por persistir o
  # AnalysisResult. O teste Perl verifica apenas o contrato persistido,
  # não a implementação do repository.
  # ------------------------------------------------------------------------

  my $run_id = $similarity_info->{run_id};

  ok $run_id,
    'resultado contém run_id';

  my ($count) = $sch->storage->dbh->selectrow_array(
    q{
      SELECT COUNT(*)
      FROM analytics.similarity_pairs
      WHERE target_table = ?
        AND metric = ?
        AND run_id = ?
    },
    undef,
    "staging.$table_name",
    'gower',
    $run_id,
  );

  is $count,
    $expected_pairs,
    'número de pares persistidos bate com n_pairs';

  # Nenhuma escola pode ser comparada consigo mesma.
  my ($self_pairs) = $sch->storage->dbh->selectrow_array(
    q{
      SELECT COUNT(*)
      FROM analytics.similarity_pairs
      WHERE target_table = ?
        AND run_id = ?
        AND entity_1 = entity_2
    },
    undef,
    "staging.$table_name",
    $run_id,
  );

  is $self_pairs,
    0,
    'não existem auto-comparações (entity_1 = entity_2)';

  # A representação deve conter somente um sentido de cada par.
  my ($reverse_pairs) = $sch->storage->dbh->selectrow_array(
    q{
      SELECT COUNT(*)
      FROM analytics.similarity_pairs a
      JOIN analytics.similarity_pairs b
        ON b.target_table = a.target_table
       AND b.run_id       = a.run_id
       AND b.entity_1     = a.entity_2
       AND b.entity_2     = a.entity_1
      WHERE a.target_table = ?
        AND a.run_id = ?
    },
    undef,
    "staging.$table_name",
    $run_id,
  );

  is $reverse_pairs,
    0,
    'não existem pares duplicados em sentido inverso';

  cleanup_job($t, $job);
};

# --------------------------------------------------------------------------
# Default
#
# O contrato Perl continua aceitando a omissão de metric e usando Gower.
# Isso pertence à camada de entrada/orquestração, portanto continua sendo
# um teste importante aqui.
# --------------------------------------------------------------------------

subtest qq/
$tag <defaults>
  - metric omitido usa gower
/ => sub {

  my $job = run_similarity_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
  });

  is $job->info->{state},
    'finished',
    'job finalizado com sucesso usando metric default';

  is $job->info->{result}{meta}{metric},
    'gower',
    "default de metric é 'gower'";

  cleanup_job($t, $job);
};

# --------------------------------------------------------------------------
# Métricas ainda não implementadas
#
# A validação Perl deve continuar aceitando as métricas previstas pelo
# contrato. A ausência da implementação analítica deve produzir falha
# controlada do job, e não derrubar o worker.
# --------------------------------------------------------------------------

subtest qq/
$tag <métricas ainda não implementadas>
  - métricas válidas mas sem implementação analítica falham de forma
    controlada
/ => sub {

  my @CASES = (
    { metric => 'euclidean_zscore', extra => {} },
    { metric => 'mahalanobis',      extra => {} },
    {
      metric => 'aitchison',
      extra  => {
        composition_columns => [
          qw/total_docentes_basico total_docentes_medio/
        ],
      },
    },
    {
      metric => 'dtw',
      extra  => {
        time_column  => 'ano',
        value_column => 'nota_ideb',
      },
    },
  );

  for my $case (@CASES) {
    my $metric = $case->{metric};

    my $job = run_similarity_job($t, {
      id_column  => 'co_entidade',
      table_name => $table_name,
      schema     => 'staging',
      metric     => $metric,
      %{ $case->{extra} },
    });

    is $job->info->{state},
      'failed',
      "job de $metric falha de forma controlada";

    like
      $job->info->{result},
      qr/\Q$metric\E|not implemented|não implementada/i,
      "erro de $metric identifica a implementação ausente";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Validação de argumentos
#
# Estes casos devem falhar antes de chegar à análise R. Portanto este
# bloco continua sendo responsabilidade do teste Perl.
# --------------------------------------------------------------------------

subtest qq/
$tag <validação de argumentos>
  - argumentos obrigatórios ausentes ou inválidos são rejeitados antes
    da execução da análise
/ => sub {

  my @INVALID_CASES = (
    {
      name => 'id_column ausente',
      args => {
        table_name => $table_name,
        schema     => 'staging',
      },
    },
    {
      name => 'table_name ausente',
      args => {
        id_column => 'co_entidade',
        schema    => 'staging',
      },
    },
    {
      name => 'metric fora do enum permitido',
      args => {
        id_column  => 'co_entidade',
        table_name => $table_name,
        metric     => 'kmeans',
      },
    },
    {
      name => 'aitchison sem composition_columns',
      args => {
        id_column  => 'co_entidade',
        table_name => $table_name,
        metric     => 'aitchison',
      },
    },
    {
      name => 'aitchison com menos de duas composition_columns',
      args => {
        id_column           => 'co_entidade',
        table_name          => $table_name,
        metric              => 'aitchison',
        composition_columns => ['total_docentes_basico'],
      },
    },
    {
      name => 'dtw sem time_column/value_column',
      args => {
        id_column  => 'co_entidade',
        table_name => $table_name,
        metric     => 'dtw',
      },
    },
  );

  for my $case (@INVALID_CASES) {
    my $job = run_similarity_job($t, $case->{args});

    is $job->info->{state},
      'failed',
      "rejeitado: $case->{name}";

    like
      $job->info->{result},
      qr/Invalid (arguments|metric)/,
      "mensagem de erro adequada: $case->{name}";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Limpeza
#
# A tabela é específica desta fixture. As linhas de similarity_pairs,
# entretanto, são compartilhadas por outras execuções, portanto removemos
# somente as linhas pertencentes a esta target_table.
# --------------------------------------------------------------------------

$sch->storage->dbh->do(
  'DELETE FROM analytics.similarity_pairs WHERE target_table = ?',
  undef,
  "staging.$table_name",
);

$sch->storage->dbh->do(
  "DROP TABLE IF EXISTS staging.$table_name"
);

done_testing;
```

### Um ponto que eu mudaria em relação ao teste antigo

Há uma diferença arquitetural importante: **eu não faria o teste Perl depender demais da estrutura interna do `similarity_info` se ela não for parte do contrato público**.

O ideal é que o contrato Perl tenha algo conceitualmente assim:

```text
result
├── meta
│   ├── metric
│   └── ...
└── similarity_info
    ├── run_id
    ├── n_entities
    ├── n_pairs
    └── avg_similarity
```

E o `AnalysisResult` R fique livre para ser:

```text
analysis_result
├── analysis
├── parameters
├── data
├── metrics
├── tables
├── plots
└── metadata
```

Ou seja, o Perl **não deve saber** que `n_pairs` veio de `result$metrics$n_pairs`; essa é uma responsabilidade do adapter/Repository.

Também vale muito a pena manter estes três níveis de teste:

1. **R/unit:** `analyze_gower_similarity()` calcula corretamente.
2. **R/architecture:** `run_similarity()` → `AnalysisResult` → `persist_similarity()`.
3. **Perl/integration:** job termina, contrato externo está correto e `analytics.similarity_pairs` contém os pares esperados.

Isso evita transformar o teste Perl em uma cópia dos testes internos do R. Ele testa justamente a fronteira que interessa ao sistema.
