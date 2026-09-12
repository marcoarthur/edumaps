use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Cpanel::JSON::XS qw(decode_json);   # ou JSON::MaybeXS
use Mojo::File qw(path);
use open ':std', ':encoding(UTF-8)';
use utf8;
use Encode qw(encode);

my $t   = Test::Mojo->new('EduMaps');
my $sch = $t->app->schema;
my $dbh = $sch->storage->dbh;
my $tag = '[task] city_analytics';

# Fixture
$dbh->do('CREATE SCHEMA IF NOT EXISTS analytics');
$dbh->do('
  CREATE TABLE IF NOT EXISTS analytics.city_school_analytics (
    codigo_ibge   VARCHAR(7) NOT NULL,
    analysis      VARCHAR(50) NOT NULL,
    summary_data  JSONB,
    plotly_charts JSONB,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (codigo_ibge, analysis)
  )
');

# Seleciona um município
my $sample_escola = $sch->resultset('CensoEscolas')->search(
  { co_municipio => { '!=', undef } },
  { rows => 1 }
)->first;   # use first em vez de single para evitar aviso

plan skip_all => 'Nenhum dado encontrado na tabela clean.censo_escolas'
  unless $sample_escola;

my $cod_ibge = sprintf('%07d', $sample_escola->co_municipio);
my $expected_schools_count = $sch->resultset('CensoEscolas')->search({
  co_municipio => $cod_ibge
})->count;

# Helpers
sub run_city_analytics_job {
  my ($t, $args) = @_;
  my $job_id = $t->app->apply_city_analytics($args);
  return undef unless $job_id;

  my $worker = $t->app->minion->worker->register;
  my $job    = $worker->dequeue(0 => { queues => ['speculative', 'default'] });
  $job->perform if $job;
  return $job;
}

sub cleanup_job {
  my ($t, $job) = @_;
  return unless $job;
  $job->remove;
}

# --------------------------------------------------------------------------
# Caso feliz: full_summary
# --------------------------------------------------------------------------
subtest qq/
$tag <computando sumario e visualizacoes de cidade>
  - aplicando full_summary sobre municipio IBGE $cod_ibge
  - teste do happy day
/ => sub {
  plan tests => 17;   # número total de asserções

  # Limpeza
  $sch->storage->dbh->do(
    'DELETE FROM analytics.city_school_analytics WHERE codigo_ibge = ? AND analysis = ?',
    undef, $cod_ibge, 'full_summary'
  );
  $t->app->chi->remove("edumaps:analytics:city:${cod_ibge}:full_summary") if $t->app->chi;

  my $job = run_city_analytics_job($t, {
    codigo_ibge => $cod_ibge,
    analysis    => 'full_summary',
    schema      => 'clean',
  });

  ok $job, 'job foi enfileirado e consumido com sucesso';
  is $job->info->{state}, 'finished', 'job finalizado com sucesso'
    or diag "resultado: " . ($job->info->{result} // '');

  my $result = $job->info->{result};
  is $result->{meta}{name}, 'city_analytics', 'nome do metadata correto';
  is $result->{meta}{codigo_ibge}, $cod_ibge, 'codigo_ibge bate com a fixture';
  is $result->{meta}{analysis}, 'full_summary', 'modalidade de analise correta';

  my $r_meta = $result->{analytics_info}{r_meta};
  if ($r_meta->{status} ne 'SUCCESS') {
      diag "R error: " . ($r_meta->{message} // 'unknown error');
  }
  is $r_meta->{status}, 'SUCCESS', 'script R reportou status SUCCESS';
  is $r_meta->{records_processed}, $expected_schools_count,
    "total de registros processados em R bate com CensoEscolas ($expected_schools_count)";

  # Consulta no banco
  my $row = $sch->storage->dbh->selectrow_hashref(
    'SELECT codigo_ibge, analysis, summary_data, plotly_charts, updated_at 
     FROM analytics.city_school_analytics 
     WHERE codigo_ibge = ? AND analysis = ?',
    undef, $cod_ibge, 'full_summary'
  );

  ok $row, 'registro gravado em analytics.city_school_analytics';
  is $row->{codigo_ibge}, $cod_ibge, 'codigo_ibge mantido no banco';
  is $row->{analysis}, 'full_summary', 'chave primarias (analysis) confere';

  # Decodifica summary_data (bytes crus)
  my $summary = ref $row->{summary_data} eq 'HASH' 
    ? $row->{summary_data} 
    : decode_json($row->{summary_data});

  is $summary->{total_escolas}, $expected_schools_count,
    'total_escolas no JSONB bate com a contagem real da fixture';
  ok exists $summary->{total_matriculas}, 'total_matriculas computado';
  ok exists $summary->{media_alunos_por_escola}, 'media_alunos_por_escola computada';

  # Decodifica plotly_charts (bytes crus)
  #
  my $raw = $row->{plotly_charts};
  my $bytes = encode('UTF-8', $raw, Encode::FB_CROAK | Encode::LEAVE_SRC);
  my $charts = decode_json($bytes);

  ok exists $charts->{enrollment_by_level}, 'grafico enrollment_by_level presente';
  ok exists $charts->{student_teacher_ratio}, 'grafico student_teacher_ratio presente';

  # Valida estrutura do primeiro gráfico
  is ref $charts->{enrollment_by_level}{data}, 'ARRAY', 'estrutura data do Plotly e um Array JSON valido';
  is ref $charts->{enrollment_by_level}{layout}, 'HASH', 'estrutura layout do Plotly e um Hash JSON valido';

  cleanup_job($t, $job);
};

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
subtest qq/
$tag <defaults>
  - analysis omitido usa o default (full_summary)
/ => sub {
  plan tests => 2;
  $sch->storage->dbh->do(
    'DELETE FROM analytics.city_school_analytics WHERE codigo_ibge = ? AND analysis = ?',
    undef, $cod_ibge, 'full_summary'
  );
  $t->app->chi->remove("edumaps:analytics:city:${cod_ibge}:full_summary") if $t->app->chi;

  my $job = run_city_analytics_job($t, {
    codigo_ibge => $cod_ibge,
  });

  is $job->info->{state}, 'finished', 'job finalizado usando analysis default';
  is $job->info->{result}{meta}{analysis}, 'full_summary', "default de analysis e 'full_summary'";
  cleanup_job($t, $job);
};

# --------------------------------------------------------------------------
# Modalidades stub
# --------------------------------------------------------------------------
subtest qq/
$tag <modalidades adicionais\/stubs>
  - score_distribution e school_clusters sao dispatcadas corretamente para o R
/ => sub {
  plan tests => 4;
  my @STUBS = qw(score_distribution school_clusters);

  for my $analysis (@STUBS) {
    my $job = run_city_analytics_job($t, {
      codigo_ibge => $cod_ibge,
      analysis    => $analysis,
    });

    is $job->info->{state}, 'finished', "job de $analysis executado com sucesso";
    is $job->info->{result}{analytics_info}{r_meta}{status}, 'SKIPPED',
      "script R retornou status SKIPPED esperado para $analysis";
    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Validação de argumentos
# --------------------------------------------------------------------------
subtest qq/
$tag <validacao de argumentos>
  - argumentos obrigatorios ausentes ou invalidos sao rejeitados antes de
    tentar executar o script R
/ => sub {
  my @INVALID_CASES = (
    {
      name => 'codigo_ibge ausente',
      args => { analysis => 'full_summary' },
      expect_job_undef => 1,
    },
    {
      name => 'codigo_ibge com tamanho/formato invalido',
      args => { codigo_ibge => '12345', analysis => 'full_summary' },
    },
    {
      name => 'analysis fora do enum permitido',
      args => { codigo_ibge => $cod_ibge, analysis => 'invalid_analysis_type' },
    },
    {
      name => 'schema com caracteres invalidos (SQL Injection)',
      args => { codigo_ibge => $cod_ibge, schema => 'clean; DROP TABLE test;' },
    },
  );

  for my $case (@INVALID_CASES) {
    my $job = run_city_analytics_job($t, $case->{args});

    if ($case->{expect_job_undef}) {
      ok !$job, "helper rejeitou (sem job): $case->{name}";
    } else {
      ok $job, "job enfileirado para $case->{name}";
      is $job->info->{state}, 'failed', "job falhou como esperado: $case->{name}";
      like $job->info->{result}, qr/Argumentos inválidos|Análise inválida/i,
        "mensagem de erro de validacao adequada: $case->{name}";
      cleanup_job($t, $job);
    }
  }

  done_testing;
};

# --------------------------------------------------------------------------
# Limpeza final
# --------------------------------------------------------------------------
$sch->storage->dbh->do(
  'DELETE FROM analytics.city_school_analytics WHERE codigo_ibge = ?',
  undef, $cod_ibge
);

done_testing;
