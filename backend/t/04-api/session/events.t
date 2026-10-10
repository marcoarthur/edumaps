use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(decode_json);
use open ':std', ':encoding(UTF-8)';
use utf8;

# Testes do endpoint público POST /api/session/events:
#   - lote válido -> 204 + persistência (allowlist de tipos E de chaves);
#   - tipo fora da allowlist é ignorado;
#   - texto digitado no payload é descartado no servidor;
#   - lote malformado -> 400.

my $t   = Test::Mojo->new('EduMaps');
my $app = $t->app;

unless ($app->pg) {
  plan skip_all => 'Mojo::Pg não disponível para testes de integração';
}

my $db = $app->pg->db;

eval { $db->delete('event_store'); $db->delete('session_tracking') };
if ($@) {
  plan skip_all => 'Tabelas event_store/session_tracking ausentes. Execute as migrations do Sqitch.';
}

sub flush_logger {
  $app->event_bus->request('event_logger.flush');
}

my $sid;

subtest 'Lote válido -> 204 + persistência com allowlist' => sub {
  $t->post_ok(
    '/api/session/events',
    json => [
      { type => 'navigate', ts => 1720000000000, payload => { route => '/escola/search' } },
      { type => 'schools:search', ts => 1720000001000, payload => { q_len => 5, result_count => 3, texto_secreto => 'minha-busca' } },
      { type => 'evil:type', ts => 1, payload => { x => 1 } },
    ],
  )->status_is(204);

  # Primeiro contato: o Middleware::Session cria o cookie
  my @cookies = @{ $t->tx->res->cookies };
  my $sc = $cookies[0] // Mojo::Cookie::Response->new;
  $sid = $sc->value if $sc->name eq 'edumaps_sid';
  ok defined $sid && $sid =~ /^[0-9a-f]{32}$/, 'cookie edumaps_sid criado no primeiro contato';

  flush_logger();

  my $nav = $db->select('event_store', '*', { event_type => 'session.navigate' })->hash;
  ok $nav, 'evento navigate persistido';
  is $nav->{session_id}, $sid, 'session_id atribuído ao evento';
  my $pn = decode_json($nav->{payload});
  is $pn->{route}, '/escola/search', 'route gravada';
  is $pn->{ts}, 1720000000000, 'ts gravado';

  my $sch = $db->select('event_store', '*', { event_type => 'session.search' })->hash;
  ok $sch, 'evento search persistido';
  my $ps = decode_json($sch->{payload});
  is $ps->{q_len}, 5, 'q_len gravado';
  is $ps->{result_count}, 3, 'result_count gravado';
  ok !exists $ps->{texto_secreto}, 'texto digitado descartado (allowlist de chaves)';

  my $evil = $db->select('event_store', '*', { event_type => 'evil:type' })->hash;
  ok !$evil, 'tipo fora da allowlist ignorado';

  my $sess = $db->select('session_tracking', '*', { session_id => $sid })->hash;
  ok $sess, 'sessão upsertada em session_tracking';
  is $sess->{seen_count}, 2, '2 interações contadas na sessão';
};

subtest 'Lote malformado -> 400' => sub {
  $t->post_ok('/api/session/events', json => { not => 'array' })->status_is(400);

  my @big = map { { type => 'navigate', payload => { route => "/r$_" } } } 1 .. 201;
  $t->post_ok('/api/session/events', json => \@big)->status_is(400);
};

END {
  if ($app->pg) {
    eval {
      $app->pg->db->delete('event_store');
      $app->pg->db->delete('session_tracking');
    };
  }
}

done_testing();