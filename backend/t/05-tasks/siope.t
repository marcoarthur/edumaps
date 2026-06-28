use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;

my $t = Test::Mojo->new('EduMaps');
my $minion = $t->app->minion;
my $cod = 110001;
my $ano = 2024;

sub _delete_previous {
  $t->app->schema->resultset('RemuneracaoMunicipal')->search_rs(
    {ano => $ano, cod_municipio => $cod}
  )->delete;
}

subtest qq{executando task query_siope com codigo_municipio = $cod e ano = $ano} => sub {
  _delete_previous;
  my $job_id = $t->app->get_siope($cod, $ano);
  my $job = $minion->job($job_id);
  $minion->perform_jobs;

  my $result = $job->info->{result};
  my $note = $job->note;

  is $job->task, 'query_siope', qq<Rigth queue>;
  like(
    $result,
    hash {
      field job_info => hash {
        field cidade => $cod;
        field ano    => $ano;
        etc();
      };
      field records   => number_gt(0);   # verifica que inseriu registros
      field took      => number_ge(0);
      field created_at => match qr/^.../;
      etc();
    },
    'full result structure is valid'
  );
};

done_testing;
