use Mojo::Base -strict, -signatures;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use CI;

# A task SIOPE baixa microdados do INEP e emite progresso por SSE via Minion.
CI->skip_network ('task siope: baixa microdados do INEP e precisa do Minion');

my $t = Test::Mojo->new('EduMaps');
my $minion = $t->app->minion;
my $cod = 110001;
my $ano = 2024;
my $tag = '[task] siope:';

# Jobs criados pelo teste: removidos no fim (os que não estiverem rodando).
my @JOBS;
my $FILA = "teste_$$";
END {
  for my $id (@JOBS) {
    my $job = $minion->job($id) or next;
    $job->remove unless $job->info->{state} eq 'active';
  }
}

sub _delete_previous ($code, $year){
  $t->app->schema->resultset('RemuneracaoMunicipal')->search_rs(
    {ano => $year, cod_municipio => $code}
  )->delete;
}

subtest qq/
$tag <executando task diretamente query_siope>
  - deleta dados anteriore
  - download com codigo_municipio = $cod e ano = $ano
  - salva no banco
/ => sub {
  _delete_previous($cod, $ano);
  # Fila própria: só o perform_jobs deste teste executa o job (o minion local
  # consome a `default`).
  local $t->app->config->{minion_filas}{query_siope} = $FILA;
  my $job_id = $t->app->get_siope($cod, $ano);
  push @JOBS, $job_id;
  my $job = $minion->job($job_id);
  $minion->perform_jobs({ queues => [$FILA] });

  my $result = $job->info->{result};
  my $note = $job->note;

  is $job->task, 'query_siope', qq<Fila certa da task>;
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

subtest qq/
$tag <executando task via app>
  - deleta dados anteriore
  - enfileira e executa a task
/ => sub {
  _delete_previous($cod, $ano);

  my $tx = $t->post_ok("/api/task/siope?codigo_ibge=$cod&ano=$ano")
  ->status_is(202)
  ->header_like( Location => qr/progress\?job_id=\d+/ )
  ->json_has('/job_id')
  ->json_has('/task')
  ->tx
  ;

  # Minion::Backend::Pg
  # Minion
  my $json = $tx->res->json;
  push @JOBS, $json->{job_id};
  my $location = $tx->res->headers->location;
  $t->get_sse_ok("$location")
  ->status_is(200)
  ->sse_ok
  ->sse_type_is('progress')
  ->sse_text_like(qr/percent/)
  ;
  # cleanup
  ok ($minion->backend->remove_job($json->{job_id}), "job $json->{job_id} removido");
};

done_testing;
