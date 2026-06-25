package EduMaps::Task::Siope;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::Siope::Scrap::SpreadSheet::Gastos;
use Mojo::Collection qw(c);
use Syntax::Keyword::Try;
use Time::Piece;
use constant {
  CHUNK_SIZE => 5000,
  CAPTCHA => $ENV{CAPTCHA_SIOPE} || '',
};

sub register ($self, $app, $config){
  $app->minion->add_task(query_siope => \&_query_siope);
}

sub _query_siope($job, $city_id, $year) {
  my $start = localtime;
  my $driver = EduMaps::Siope::Scrap::SpreadSheet::Gastos->new(
    cod_mun => $city_id,
    captcha => CAPTCHA,
    ano     => $year,
  );

  my $chunk_size  = CHUNK_SIZE;
  my $rs          = $job->app->schema->resultset('RemuneracaoMunicipal');
  my $processed   = 0;
  my $col_order   = $rs->siope_column_order;
  my ($rows,$total);

  try {
    $rows        = c($driver->get_and_process->@*);
    $total       = $rows->size;
    $rows->each(
      sub { push @$_, $city_id, 'Municipal'; }
    );

    while(@$rows) {
      my @chunk    = splice(@$rows, 0, $chunk_size);
      my $progress = {
        phase => 'DB saving',
        total => $total,
        processed => ($processed += scalar @chunk)
      };
      $rs->populate([$col_order, @chunk]);
      $job->note(progress => $progress);
    }
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

1;
