package EduMaps::Task::Siope;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::Siope::Scrap::SpreadSheet::Gastos;
use Mojo::Collection qw(c);
use Syntax::Keyword::Try;
use Time::Piece;
use Minion::Task::Generator qw/task/;

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
      my @chunk   = splice(@$rows, 0, $chunk_size);
      $processed += scalar(@chunk);
      $rs->populate([$col_order, @chunk]);
      $job->progress(($processed / $total)*100, "$processed records saved");
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

sub _enqueue_siope_task($app, $cod_ibge, $year = DEFAULT_YEAR) {
  return $app->minion->enqueue(
    query_siope => [$cod_ibge, $year] => { attempts => 3 }
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
