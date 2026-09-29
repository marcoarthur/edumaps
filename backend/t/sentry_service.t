use Mojo::Base -strict, -signatures;
use Test2::V0;
use utf8;
use lib qw(./lib);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Exception;
use EduMaps::Services::Sentry;

# Stub de UA: coleta os envelopes sem tocar rede (suporta os dois caminhos
# do `_send`: `post` síncrono e `post_p` fire-and-forget).
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

my $DSN = 'https://publickey123@o4500000000.ingest.sentry.io/4500000001';

sub make_service {
  my %opt = @_;
  my $ua  = StubUA->new;
  my $svc = EduMaps::Services::Sentry->new(
    dsn         => $DSN,
    environment => 'test',
    release     => 'abc1234',
    ua          => $ua,
    %opt,
  );
  return ($svc, $ua);
}

subtest 'ingest url a partir do DSN' => sub {
  my ($svc) = make_service();
  is $svc->_ingest_url, 'https://o4500000000.ingest.sentry.io/api/4500000001/envelope/',
    'monta url de envelope no formato cloud';
  ok $svc->is_active, 'com DSN o serviço está ativo';
};

subtest 'sem DSN é no-op' => sub {
  my $ua  = StubUA->new;
  my $svc = EduMaps::Services::Sentry->new(ua => $ua);
  ok !$svc->is_active, 'inativo sem DSN';
  $svc->capture_exception('boom');
  $svc->capture_message('hi');
  is @{$ua->posts}, 0, 'nenhum envelope enviado (nem via _send)';
};

subtest 'capture_exception monta envelope com exception' => sub {
  my ($svc, $ua) = make_service();
  $svc->capture_exception('estourou aqui', task => 'siope', job_id => 42);

  is @{$ua->posts}, 1, 'um post';
  my $post = $ua->posts->[0];
  is $post->{url}, 'https://o4500000000.ingest.sentry.io/api/4500000001/envelope/', 'url de ingestão';
  is $post->{headers}{'content-type'}, 'application/x-sentry-envelope', 'content-type de envelope';

  my ($line1, $line2, $line3) = split /\n/, $post->{body}, 3;
  my $header = decode_json($line1);
  is length($header->{event_id}), 32, 'event_id com 32 hex';
  like $header->{sent_at}, qr/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, 'sent_at ISO8601 UTC';
  is $header->{dsn}, $svc->dsn, 'dsn no header do envelope';

  my $item = decode_json($line2);
  is $item->{type}, 'event', 'item do envelope é evento';
  is $item->{content_type}, 'application/json', 'content-type do item';
  is $item->{length}, length($line3), 'length em bytes do payload';

  my $event = decode_json($line3);
  is $event->{platform}, 'perl', 'platform perl';
  is $event->{environment}, 'test', 'environment';
  is $event->{release}, 'abc1234', 'release';
  is $event->{level}, 'error', 'level error padrão';
  is $event->{exception}{values}[0]{value}, 'estourou aqui', 'mensagem do erro';
  is $event->{tags}{task}, 'siope', 'tag task';
  is $event->{tags}{job_id}, '42', 'tag job_id (stringificada)';
};

subtest 'utf-8 preservado e length em bytes' => sub {
  my ($svc, $ua) = make_service();
  my $msg = 'erro com acentuação: çãõ';
  $svc->capture_exception($msg);

  my ($line1, $line2, $line3) = split /\n/, $ua->posts->[0]{body}, 3;
  my $event = decode_json($line3);
  is $event->{exception}{values}[0]{value}, $msg, 'mensagem utf-8 intacta';
  is decode_json($line2)->{length}, length($line3), 'length do envelope igual ao bytes do payload';
};

subtest 'Mojo::Exception carrega stacktrace' => sub {
  my ($svc, $ua) = make_service();
  my $e = Mojo::Exception->new('falha interna')->trace;
  $svc->capture_exception($e);

  my $event = decode_json((split /\n/, $ua->posts->[0]{body}, 3)[2]);
  ok $event->{exception}{values}[0]{stacktrace}{frames}[0]{filename}, 'tem pelo menos um frame';
};

subtest 'capture_message com level e tags' => sub {
  my ($svc, $ua) = make_service();
  $svc->capture_message('HTTP 503 em /api/x', status => 503, level => 'warning');

  my $event = decode_json((split /\n/, $ua->posts->[0]{body}, 3)[2]);
  is $event->{message}, 'HTTP 503 em /api/x', 'campo message';
  is $event->{level}, 'warning', 'level custom';
  is $event->{tags}{status}, '503', 'tag status';
};

subtest '_sanitize_args redige dados sensíveis' => sub {
  my ($svc) = make_service();
  my $safe = $svc->_sanitize_args([
    3304557,               # codigo_ibge (7 dígitos) — mantido
    '12345678901',         # CPF (11 dígitos) — descartado
    { raio => 800 },       # hash não sensível — mantido
    { salario => 8000 },   # chave sensível — descartado
    'x' x 300,             # longo demais — descartado
  ]);
  is @$safe, 2, 'só os 2 argumentos permitidos';
  is $safe->[0]{value}, '3304557', 'mantém escalar curto';
  is $safe->[1]{value}, encode_json({ raio => 800 }), 'mantém hash não sensível';
  is [ map { $_->{index} } @$safe ], [0, 2], 'índices originais preservados';
};

done_testing;