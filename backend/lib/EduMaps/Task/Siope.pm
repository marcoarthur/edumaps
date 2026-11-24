package EduMaps::Task::Siope;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos;
use Mojo::Collection qw(c);
use Syntax::Keyword::Try;
use Time::Piece;
use Minion::Task::Generator qw/task/;
use EduMaps::Util::MinionFila qw(minion_fila);

use constant {
  CHUNK_SIZE => 2000,
  CAPTCHA => $ENV{CAPTCHA_SIOPE} || '',
  DEFAULT_YEAR => 2025,
};

sub register ($self, $app, $config){
  $app->minion->add_task(
    query_siope => task { 
      sub   => \&_query_siope,
      roles => {'+Progress' => {log => $app->log}}
    }
  );

  $app->helper(get_siope => \&_enqueue_siope_task);
  $app->helper(monitor_siope => \&_monitor_siope_task);
}

sub _query_siope($job, $city_id, $year) {
  my $start = localtime;
  my $driver = EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos->new(
    cod_mun => $city_id,
    captcha => CAPTCHA,
    ano     => $year,
  );

  my $chunk_size  = CHUNK_SIZE;
  my $rs          = $job->app->schema->resultset('RemuneracaoMunicipal');
  my $processed   = 0;
  my $col_order   = $rs->siope_column_order;
  my ($rows,$total);

  my $arquivo;
  try {
    # #564: planilha de uma carga anterior no /tmp não serve: sempre baixar.
    $driver->cleanup;
    $rows        = c($driver->get_and_process->@*);
    $arquivo     = $driver->arquivo;
    $total       = $rows->size;
    $rows->each(
      sub { push @$_, $city_id, 'Municipal'; }
    );

    # #536: recarregar o mesmo município e ano troca a folha, sem duplicar
    # linhas; apagar e inserir numa transação só.
    $job->app->schema->txn_do(sub {
      $rs->search({ cod_municipio => "$city_id", ano => $year })->delete;
      while(@$rows) {
        my @chunk   = splice(@$rows, 0, $chunk_size);
        $processed += scalar(@chunk);
        $rs->populate([$col_order, @chunk]);
        $job->progress(($processed / $total)*100, "$processed records saved");
      }
      # #564 (QQ-02 da P6): a carga registrada, na mesma transação.
      _registrar_carga($job->app->schema->storage->dbh, $city_id, $year, $total, $arquivo);
    });
    $driver->cleanup;
  } catch($err) {
    $job->app->log->error("Error during $city_id payroll for year $year");
    return $job->fail({ error => $err });
  }
  my $end = localtime;
  my $meta = {
    job_info => { cidade => $city_id, ano => $year },
    created_at => $end,
    took => $end - $start,
    records => $total,
  };

  $job->app->log->info("Sucessuful downloaded data for $city_id, total records: $total");
  $job->finish($meta);
}

# #564 (QQ-02 da P6): cada carga da folha fica em clean.import_metadata, na
# linha da tabela, com uma entrada por município e ano na lista de arquivos
# (raw_manifest): recarregar o mesmo município e ano troca a entrada. As
# cargas de antes deste registro ficam sem entrada ("carga não registrada").
sub _registrar_carga ($dbh, $cod, $ano, $linhas, $arquivo) {
  $arquivo //= {};
  $dbh->do(q{
    WITH nova AS (
      SELECT jsonb_build_object(
               'cod_municipio', ?::text, 'ano', ?::int, 'linhas', ?::int,
               'url', ?::text, 'sha256', ?::text, 'bytes', ?::bigint,
               'baixado_em', to_char(now() AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD"T"HH24:MI:SS')
             ) AS e
    )
    INSERT INTO clean.import_metadata AS im
      (table_name, source_file, source_url, retrieved_at, row_count_loaded, notes,
       ultimo_status, ultimo_motivo, ultima_tentativa_em, raw_manifest)
    SELECT 'clean.remuneracao_municipal', 'SIOPE (remuneração municipal, por município e ano)',
           'https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do', now(), NULL,
           'Uma entrada por município e ano em raw_manifest (#564)', 'ok', NULL, now(), jsonb_build_array(e)
      FROM nova
    ON CONFLICT (table_name) DO UPDATE SET
      retrieved_at = now(),
      ultimo_status = 'ok', ultimo_motivo = NULL, ultima_tentativa_em = now(),
      notes = EXCLUDED.notes,
      raw_manifest = COALESCE((
        SELECT jsonb_agg(x) FROM jsonb_array_elements(COALESCE(im.raw_manifest, '[]'::jsonb)) x
         WHERE NOT (x->>'cod_municipio' = (SELECT e->>'cod_municipio' FROM nova)
                AND x->>'ano' = (SELECT e->>'ano' FROM nova))
      ), '[]'::jsonb) || (SELECT jsonb_build_array(e) FROM nova)
  }, undef, "$cod", 0 + $ano, 0 + ($linhas // 0), $arquivo->{url}, $arquivo->{sha256}, $arquivo->{bytes});
}

# Fila: `minion_filas.query_siope` no config (testes usam uma fila própria
# para o minion local não pegar o job); sem entrada, `default`.
sub _enqueue_siope_task($app, $cod_ibge, $year = DEFAULT_YEAR) {
  return $app->minion->enqueue(
    query_siope => [$cod_ibge, $year] => {
      attempts => 3,
      queue    => minion_fila($app, 'query_siope'),
    }
  );
}

sub _monitor_siope_task($c, $job_id) {
  $c->monitor_job(
    {
      job_id    => $job_id,
      poll_time => 1,
      on_finish => sub {$c->log->info("job $job_id sucessfull ended")},
    }
  );
}

1;
