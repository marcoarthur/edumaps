use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

# ------------------------------------------------------------
# POST /api/chat/ask
# ------------------------------------------------------------
subtest 'chat ask: enfileira e retorna 202 + Location' => sub {
  my $tx = $t->post_ok('/api/chat/ask' => json => {
    pergunta => 'Quantas escolas ativas existem no meu município?',
    contexto => {
      cod_municipio  => '3550308',
      nome_municipio => 'São Paulo',
    },
  })->status_is(202)->tx;

  my $json = $tx->res->json;
  is $json->{task}, 'chat', 'task = chat';
  ok $json->{job_id} =~ /^\d+$/, 'job_id numérico';
  like $tx->res->headers->header('Location'), qr{^/api/chat/progress\?job_id=\d+$},
    'Location p/ polling';
  is $t->app->minion->job($json->{job_id})->info->{queue}, 'analytics',
    'job na fila dedicada analytics';

  # O contexto aninhado precisa chegar ao job (não vazio).
  my $args = $t->app->minion->job($json->{job_id})->info->{args}[0];
  is $args->{contexto}{cod_municipio}, '3550308', 'contexto.cod_municipio no job';
  is $args->{contexto}{nome_municipio}, 'São Paulo', 'contexto.nome_municipio no job';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'chat ask: sem pergunta -> 400' => sub {
  $t->post_ok('/api/chat/ask' => json => { cod_municipio => '3550308' })
    ->status_is(400);
};

subtest 'chat ask: pergunta acima de 500 chars -> 400' => sub {
  $t->post_ok('/api/chat/ask' => json => { pergunta => 'a' x 501 })
    ->status_is(400);
};

subtest 'chat ask: cod_municipio inválido -> 400' => sub {
  $t->post_ok('/api/chat/ask' => json => {
    pergunta => 'Quantas escolas?',
    contexto => { cod_municipio => '123' },
  })->status_is(400);
};

# ------------------------------------------------------------
# GET /api/chat/progress
# ------------------------------------------------------------
subtest 'chat progress: job inexistente -> 404' => sub {
  $t->get_ok('/api/chat/progress?job_id=999999999')
    ->status_is(404)
    ->json_is('/error', 'job_not_found');
};

subtest 'chat progress: snapshot REST do job' => sub {
  my $job_id = $t->app->minion->enqueue(
    chat_ask => [{ pergunta => 'x', contexto => {} }] => { queue => 'analytics' }
  );

  $t->get_ok("/api/chat/progress?job_id=$job_id")
    ->status_is(200)
    ->json_is('/state', 'inactive');

  $t->app->minion->backend->remove_job($job_id);
};

done_testing();
