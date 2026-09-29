use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use Mojolicious;
use Minion::Job;
use Test::Mojo;
use Mojo::JSON qw(decode_json);
use EduMaps::Plugin::Sentry;
use EduMaps::Services::Sentry;

# Stub de UA: coleta envelopes sem tocar rede.
{
  package StubUA;
  use Mojo::Base -base;
  has posts => sub { [] };
  sub post {
    my ($self, $url, $headers, $body) = @_;
    push @{$self->posts}, { url => $url, headers => $headers, body => $body };
    return Mojo::Transaction::HTTP->new(res => Mojo::Message::Response->new(code => 200));
  }
  sub post_p {
    my ($self, $url, $headers, $body) = @_;
    push @{$self->posts}, { url => $url, headers => $headers, body => $body };
    return Mojo::Promise->new->resolve(
      Mojo::Transaction::HTTP->new(res => Mojo::Message::Response->new(code => 200)));
  }
}

# Backends falsos p/ o wrap de Minion::Job::fail sem banco.
{
  package FakeBackend;
  sub new { bless { failed => 0 }, shift }
  sub fail_job { $_[0]->{failed}++; 1 }
  sub list_jobs {
    my ($self) = @_;
    return { jobs => [{ task => 'query_osm', queue => 'analytics', args => [3304557, '12345678901'] }] };
  }
  package FakeMinion;
  sub new { bless { backend => $_[1] }, shift }
  sub backend { $_[0]{backend} }
}

my $DSN  = 'https://publickey123@o4500000000.ingest.sentry.io/4500000001';
my $ua   = StubUA->new;
my $app  = Mojolicious->new;

# Um único registro com serviço ativo (o wrap de Minion::Job::fail é global
# e fica com o primeiro serviço registrado — todos os subtests usam o mesmo).
$app->plugin('EduMaps::Plugin::Sentry', {
  service => EduMaps::Services::Sentry->new(dsn => $DSN, ua => $ua, environment => 'test', release => 'abc1234'),
});
$app->routes->get('/boom' => sub { die "explosão de teste\n" });
$app->routes->get('/busy' => sub { shift->render(status => 503, text => 'indisponível') });

my $t = Test::Mojo->new($app);

subtest '5xx de exceção capturado via after_dispatch' => sub {
  $t->get_ok('/boom')->status_is(500);

  is @{$ua->posts}, 1, 'um envelope após exceção';
  my $e = decode_json((split /\n/, $ua->posts->[0]{body}, 3)[2]);
  is $e->{exception}{values}[0]{value}, 'explosão de teste', 'exceção do controller';
  is $e->{tags}{status}, '500', 'tag status 500';
  is $e->{tags}{path}, '/boom', 'tag path';
  is $e->{tags}{method}, 'GET', 'tag method';
  is $e->{release}, 'abc1234', 'release';
};

subtest '5xx explícito vira mensagem genérica' => sub {
  $t->get_ok('/busy')->status_is(503);

  is @{$ua->posts}, 2, 'segundo envelope (5xx explícito sem exceção)';
  my $e = decode_json((split /\n/, $ua->posts->[1]{body}, 3)[2]);
  like $e->{message}, qr/HTTP 503/, 'mensagem genérica';
  is $e->{tags}{status}, '503', 'tag status 503';
  is $e->{tags}{path}, '/busy', 'tag path';
};

subtest 'Minion::Job::fail captura contexto do job' => sub {
  my $backend = FakeBackend->new;
  my $minion  = FakeMinion->new($backend);
  my $job     = Minion::Job->new(minion => $minion, id => 9, task => 'query_osm', args => [3304557, '12345678901']);

  ok $job->fail('estourou o OSM'), 'fail retorna verdadeiro';
  is $backend->{failed}, 1, 'comportamento original intacto (fail_job chamado)';

  is @{$ua->posts}, 3, 'terceiro envelope (fail de job)';
  my $e = decode_json((split /\n/, $ua->posts->[2]{body}, 3)[2]);
  is $e->{exception}{values}[0]{value}, 'estourou o OSM', 'erro do job';
  is $e->{tags}{task}, 'query_osm', 'tag task';
  is $e->{tags}{queue}, 'analytics', 'tag queue';
  is $e->{tags}{job_id}, '9', 'tag job_id';
  is $e->{extra}{args}, [{ index => 0, value => '3304557' }], 'args sanitizados (CPF descartado)';
};

subtest 'sem DSN: helper no-op e 500 continua funcionando' => sub {
  my $noop = Mojolicious->new;
  $noop->routes->get('/boom' => sub { die "sem dsn\n" });
  $noop->plugin('EduMaps::Plugin::Sentry');

  ok $noop->sentry->isa('EduMaps::Services::Sentry'), 'helper sentry existe';
  ok !$noop->sentry->is_active, 'inativo sem DSN';

  my $t2 = Test::Mojo->new($noop);
  $t2->get_ok('/boom')->status_is(500);
  is @{$ua->posts}, 3, 'nenhum envelope novo (no-op sem DSN)';
};

done_testing;