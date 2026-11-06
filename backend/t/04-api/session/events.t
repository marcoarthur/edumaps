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

# Sem apagar a telemetria do banco: as consultas filtram pela sessão do
# teste ($sid), e só ela é removida no fim.
eval { $db->query('SELECT 1 FROM event_store LIMIT 0'); $db->query('SELECT 1 FROM session_tracking LIMIT 0') };
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

  my $nav = $db->select('event_store', '*', { event_type => 'session.navigate', session_id => $sid })->hash;
  ok $nav, 'evento navigate persistido';
  is $nav->{session_id}, $sid, 'session_id atribuído ao evento';
  my $pn = decode_json($nav->{payload});
  is $pn->{route}, '/escola/search', 'route gravada';
  is $pn->{ts}, 1720000000000, 'ts gravado';

  my $sch = $db->select('event_store', '*', { event_type => 'session.search', session_id => $sid })->hash;
  ok $sch, 'evento search persistido';
  my $ps = decode_json($sch->{payload});
  is $ps->{q_len}, 5, 'q_len gravado';
  is $ps->{result_count}, 3, 'result_count gravado';
  ok !exists $ps->{texto_secreto}, 'texto digitado descartado (allowlist de chaves)';

  my $evil = $db->select('event_store', '*', { event_type => 'evil:type', session_id => $sid })->hash;
  ok !$evil, 'tipo fora da allowlist ignorado';

  my $sess = $db->select('session_tracking', '*', { session_id => $sid })->hash;
  ok $sess, 'sessão upsertada em session_tracking';
  is $sess->{seen_count}, 2, '2 interações contadas na sessão';
};

subtest 'tour: allowlist de chaves E de valores' => sub {
  $db->delete('event_store', { event_type => 'session.tour', session_id => $sid });

  $t->post_ok(
    '/api/session/events',
    json => [
      # válido: só as chaves da allowlist sobrevivem; step volta número
      { type => 'tour', payload => { tour_id => 'busca-escola', action => 'dismiss', step => 3, total => 7, texto => 'segredo' } },
      { type => 'tour', payload => { tour_id => 'busca-escola', action => 'start', trigger => 'auto', total => 7 } },
      # inválidos: descartados inteiros
      { type => 'tour', payload => { tour_id => 'Texto Livre Qualquer', action => 'start' } },
      { type => 'tour', payload => { tour_id => 'busca-escola', action => 'hackear' } },
      { type => 'tour', payload => { tour_id => 'busca-escola', action => 'start', trigger => 'resume' } },
      { type => 'tour', payload => { tour_id => 'busca-escola', action => 'dismiss', step => 'três' } },
      { type => 'tour', payload => { tour_id => 'busca-escola', action => 'dismiss', step => { x => 1 } } },
      { type => 'tour', payload => { action => 'start' } },
    ],
  )->status_is(204);
  flush_logger();

  my @ev = map { decode_json($_->{payload}) }
    @{ $db->select('event_store', ['payload'], { event_type => 'session.tour', session_id => $sid }, { -asc => 'id' })->hashes };
  is scalar @ev, 2, 'só os 2 eventos válidos persistidos';

  my ($dismiss) = grep { $_->{action} eq 'dismiss' } @ev;
  is $dismiss->{tour_id}, 'busca-escola', 'tour_id gravado';
  is $dismiss->{step}, 3, 'step gravado';
  like Mojo::JSON::encode_json($dismiss), qr/"step":3[,}]/, 'step gravado como número, não string';
  ok !exists $dismiss->{texto}, 'chave fora da allowlist descartada';

  my ($start) = grep { $_->{action} eq 'start' } @ev;
  is $start->{trigger}, 'auto', 'trigger gravado';
  ok !exists $start->{step}, 'step ausente não vira chave vazia';
};

subtest 'Lote malformado -> 400' => sub {
  $t->post_ok('/api/session/events', json => { not => 'array' })->status_is(400);

  my @big = map { { type => 'navigate', payload => { route => "/r$_" } } } 1 .. 201;
  $t->post_ok('/api/session/events', json => \@big)->status_is(400);
};

END {
  if ($app->pg && defined $sid) {
    eval {
      $app->pg->db->delete('event_store',      { session_id => $sid });
      $app->pg->db->delete('session_tracking', { session_id => $sid });
    };
  }
}

done_testing();