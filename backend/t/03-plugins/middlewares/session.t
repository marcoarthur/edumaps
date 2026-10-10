use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

# Testes do Middleware::Session (cookie edumaps_sid + session.request):
#   1. Primeiro request /api/* gera cookie HttpOnly/SameSite=Lax;
#   2. Request seguinte com o cookie é a MESMA sessão;
#   3. session_tracking/event_store refletem as interações em lote (flush).

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

subtest 'Primeiro request API cria cookie de sessão' => sub {
  $t->get_ok('/api/school/search?escola=teste')->status_is(200);

  my @cookies = @{ $t->tx->res->cookies };
  ok @cookies, 'Set-Cookie presente na resposta';
  my $sc = $cookies[0] // Mojo::Cookie::Response->new;
  like $sc->to_string, qr/edumaps_sid=/, 'cookie edumaps_sid definido';
  ok $sc->httponly,              'cookie HttpOnly';
  is $sc->samesite, 'Lax',       'cookie SameSite=Lax';

  $sid = $sc->value;
  ok defined $sid && $sid =~ /^[0-9a-f]{32}$/, 'sid extraído do cookie';
};

subtest 'Request seguinte com o cookie é a mesma sessão' => sub {
  $t->get_ok('/api/school/search?escola=teste', { Cookie => "edumaps_sid=$sid" })->status_is(200);

  flush_logger();

  my $s = $db->select('session_tracking', '*', { session_id => $sid })->hash;
  ok $s, 'sessão criada em session_tracking';
  is $s->{seen_count}, 2, '2 interações registradas (2 requests)';
  is $s->{ip}, '127.0.0.1', 'IP do cliente registrado';
  is $s->{is_logged}, 0, 'visitante anônimo';

  my $rows = $db->select('event_store', '*', { session_id => $sid, event_type => 'session.request' })->hashes;
  is scalar(@$rows), 2, '2 eventos session.request no event_store';
  is $rows->[0]{gestor_id}, undef, 'sem gestor logado';

  # Rota sempre resolvida: request normal -> nome do endpoint; cache HIT
  # (mesma query, sem dispatch) -> path em vez de "unknown".
  my @routes = map { $_->{payload} =~ /"route"\s*:\s*"([^"]+)"/ ? $1 : '' } @$rows;
  ok !grep { $_ eq 'unknown' } @routes, 'nenhum session.request com rota "unknown"';
  ok grep { $_ eq 'school_search' } @routes, 'request normal resolve o endpoint (school_search)';
  ok grep { $_ eq '/api/school/search' } @routes, 'cache HIT resolve o path como rota';
};

subtest 'Session.request não é emitido para o próprio endpoint de eventos' => sub {
  $t->post_ok('/api/session/events', json => [])->status_is(204);

  flush_logger();

  my $rows = $db->select('event_store', '*',
    { session_id => $sid, event_type => 'session.request' }
  )->hashes;
  my @self_logged = grep { ($_->{payload} // '') =~ /"route"\s*:\s*"session_events"/ } @$rows;
  is scalar(@self_logged), 0, 'endpoint de eventos não se loga a si mesmo';
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