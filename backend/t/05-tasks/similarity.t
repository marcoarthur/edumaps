use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Utils qw(run_similarity_job cleanup_job expected_similarity_contract);

my $t   = Test::Mojo->new('EduMaps');
my $sch = $t->app->schema;
my $tag = '[task] similarity';

# --------------------------------------------------------------------------
# Fixture: mesma cidade usada em clustering.t (Rio de Janeiro), mas com um
# nome de tabela proprio para nao colidir. IMPORTANTE: de proposito NAO
# selecionamos a coluna 'escola' (nome da escola) aqui - e uma coluna
# character praticamente unica por linha, e select_mixed_features() em
# gower.R inclui QUALQUER coluna character/factor/logical como feature
# categorica. Incluir uma coluna de texto livre faria o Gower tratar quase
# toda escola como maximamente dissimilar nessa dimensao, distorcendo a
# similaridade calculada sobre as colunas numericas que realmente importam.
# --------------------------------------------------------------------------
my $table_name = 'test_similarity';
my $params     = { no_municipio => 'Rio de Janeiro' };

my $cols = [
  'co_entidade',
  {
    capacidade_atendimento => "score.score_capacidade_atendimento",
    infraestrutura =>"score.score_infraestrutura",
    capacitacao_docente => "score.score_capacitacao_docente",
    diversidade_discente => "score.score_diversidade_discente",
    capacidade_gestora => "score.score_capacidade_gestora",
    sustentabilidade => "score.score_sustentabilidade",
  }
];

my $source_rs = $sch->resultset('CensoEscolas')
->filter_by(no_municipio => 'Ubatuba', tp_situacao_funcionamento => 1)
->join('score')
->columns($cols);

my $expected_schools_count = $source_rs->count;

$source_rs->save_in_table(
  tbl_name  => $table_name,
  schema    => 'staging',
  temporary => 0,
);

# --------------------------------------------------------------------------
# Caso feliz: gower (unica metrica com script R implementado ate agora)
# --------------------------------------------------------------------------
subtest qq/
$tag <construindo uma similaridade com gower>
  - aplicando similaridade gower sobre a tabela de staging
  - teste do happy day
/ => sub {
  my $job = run_similarity_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
    metric     => 'gower',
  });

  is $job->info->{state}, 'finished', 'job finalizado com sucesso'
    or diag "resultado: " . ($job->info->{result} // '');

  like
    $job->info->{result},
    expected_similarity_contract('gower', $job->id, $table_name, features => D()),
    "Estrutura do contrato correta (gower)";

  my $r_meta = $job->info->{result}{similarity_info}{r_meta};

  # n_pairs deve ser exatamente C(n,2) = n*(n-1)/2, ja que gower.R usa
  # apenas o triangulo superior da matriz de distancia (entity_1 < entity_2)
  my $expected_pairs = $expected_schools_count * ($expected_schools_count - 1) / 2;
  is $r_meta->{n_pairs}, $expected_pairs,
    "numero de pares bate com C($expected_schools_count, 2) = $expected_pairs";

  is $r_meta->{n_entities}, $expected_schools_count,
    'numero de entidades bate com o total de escolas da fixture';

  ok $r_meta->{avg_similarity} > 0 && $r_meta->{avg_similarity} <= 1,
    'avg_similarity esta no intervalo (0, 1]';

  # ------------------------------------------------------------------
  # Confere diretamente na tabela compartilhada analytics.similarity_pairs
  # que os pares foram de fato persistidos, batendo com o resumo do job
  # ------------------------------------------------------------------
  my $run_id = $r_meta->{run_id};
  my ($count) = $sch->storage->dbh->selectrow_array(
    'SELECT COUNT(*) FROM analytics.similarity_pairs WHERE target_table = ? AND metric = ? AND run_id = ?',
    undef, "staging.$table_name", 'gower', $run_id
  );
  is $count, $expected_pairs,
    'quantidade de linhas gravadas em analytics.similarity_pairs bate com n_pairs';

  my ($self_pairs) = $sch->storage->dbh->selectrow_array(
    'SELECT COUNT(*) FROM analytics.similarity_pairs WHERE target_table = ? AND run_id = ? AND entity_1 = entity_2',
    undef, "staging.$table_name", $run_id
  );
  is $self_pairs, 0, 'nenhum par e auto-comparacao (entity_1 = entity_2)';

  cleanup_job($t, $job);
};

# --------------------------------------------------------------------------
# Defaults: metric omitido cai no default (gower)
# --------------------------------------------------------------------------
subtest qq/
$tag <defaults>
  - metric omitido usa o default (gower)
/ => sub {
  my $job = run_similarity_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
  });

  is $job->info->{state}, 'finished', 'job finalizado com sucesso usando metric default';
  is $job->info->{result}{meta}{metric}, 'gower', "default de metric e 'gower'";

  cleanup_job($t, $job);
};

# --------------------------------------------------------------------------
# Metricas ainda sem script R implementado: devem falhar de forma limpa
# (nao travar o worker), assim como em clustering.t para gmm/spectral.
# Passamos argumentos VALIDOS de cada metrica para garantir que a falha
# aconteca no estagio de execucao do R, nao antes na validacao do Perl -
# ou seja, para confirmar que o dispatch (metric -> source_file/funcao R)
# esta correto mesmo quando o script ainda nao existe.
# --------------------------------------------------------------------------
subtest qq/
$tag <metricas ainda nao implementadas>
  - euclidean_zscore, mahalanobis, aitchison e dtw sao aceitas pela
    validacao, mas falham de forma controlada por falta do script .R
/ => sub {
  my @CASES = (
    { metric => 'euclidean_zscore', extra => {} },
    { metric => 'mahalanobis',      extra => {} },
    { metric => 'aitchison',        extra => { composition_columns => [qw/total_docentes_basico total_docentes_medio/] } },
    { metric => 'dtw',              extra => { time_column => 'ano', value_column => 'nota_ideb' } },
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

    is $job->info->{state}, 'failed', "job de $metric falha (script nao implementado)";
    like $job->info->{result},
      qr/\Q$metric.R\E|Error running R \($metric\)/,
      "mensagem de erro menciona o script/metrica ausente ($metric)";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Validacao de argumentos
# --------------------------------------------------------------------------
subtest qq/
$tag <validacao de argumentos>
  - argumentos obrigatorios ausentes ou invalidos sao rejeitados antes de
    tentar executar o script R
/ => sub {
  my @INVALID_CASES = (
    {
      name => 'id_column ausente',
      args => { table_name => $table_name, schema => 'staging' },
    },
    {
      name => 'table_name ausente',
      args => { id_column => 'co_entidade', schema => 'staging' },
    },
    {
      name => 'metric fora do enum permitido',
      args => { id_column => 'co_entidade', table_name => $table_name, metric => 'kmeans' },
    },
    {
      name => 'aitchison sem composition_columns',
      args => { id_column => 'co_entidade', table_name => $table_name, metric => 'aitchison' },
    },
    {
      name => 'aitchison com composition_columns com menos de 2 colunas',
      args => {
        id_column  => 'co_entidade', table_name => $table_name, metric => 'aitchison',
        composition_columns => ['total_docentes_basico'],
      },
    },
    {
      name => 'dtw sem time_column/value_column',
      args => { id_column => 'co_entidade', table_name => $table_name, metric => 'dtw' },
    },
  );

  for my $case (@INVALID_CASES) {
    my $job = run_similarity_job($t, $case->{args});

    is $job->info->{state}, 'failed', "rejeitado: $case->{name}";
    like $job->info->{result}, qr/Invalid (arguments|metric)/,
      "mensagem de erro adequada: $case->{name}";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Limpeza: tabela de staging da fixture + linhas geradas nesta execucao em
# analytics.similarity_pairs (NAO dropamos a tabela inteira, e compartilhada
# com outras metricas/tabelas)
# --------------------------------------------------------------------------
$sch->storage->dbh->do(
  'DELETE FROM analytics.similarity_pairs WHERE target_table = ?',
  undef, "staging.$table_name"
);
$sch->storage->dbh->do("DROP TABLE IF EXISTS staging.$table_name");

done_testing;
