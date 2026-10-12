package FakeUA;
use Mojo::Base -base, -signatures;
use utf8;

# UA HTTP falso (sem rede) para os testes dos canais públicos (#212): Telegram
# Bot API e WhatsApp Cloud API. Registra cada POST (url, método da Bot API,
# headers, payload JSON) e responde pelo `responder`:
#
#   responder => sub ($url, $json, $call) { return ($code, $body_hashref) }
#
# Código undef simula falha de conexão. Padrão: 200 {ok:true, result:{message_id:1}}.

use Mojo::JSON qw(encode_json decode_json true);
use Mojo::Promise;
use Mojo::Transaction::HTTP;

has calls     => sub { [] };
has responder => sub {
  sub ($url, $json, $call) { return (200, { ok => true, result => { message_id => 1 } }) };
};

sub post ($self, $url, @args) {
  my ($headers, $payload) = ({}, undef);
  $headers = shift @args if ref $args[0] eq 'HASH';
  if (@args >= 2 && !ref $args[0] && $args[0] eq 'json') { $payload = $args[1] }
  # ida e volta pelo JSON: compara exatamente o que iria para a rede
  my $json = decode_json(encode_json($payload // {}));
  my ($method) = $url =~ m{/([A-Za-z]+)\z};
  my $call = { url => $url, method => $method, headers => $headers, json => $json };
  push @{ $self->calls }, $call;

  my ($code, $body) = $self->responder->($url, $json, $call);
  my $tx = Mojo::Transaction::HTTP->new;
  $tx->req->method('POST');
  $tx->req->url->parse($url);
  unless (defined $code) {
    $tx->res->error({ message => 'Connection refused' });
    return $tx;
  }
  $tx->res->code($code);
  $tx->res->headers->content_type('application/json');
  $tx->res->body(encode_json($body // {}));
  return $tx;
}

sub post_p ($self, @args) { return Mojo::Promise->resolve($self->post(@args)) }

sub calls_to ($self, $method) { return [ grep { ($_->{method} // '') eq $method } @{ $self->calls } ] }
sub last_call ($self) { return $self->calls->[-1] }
sub clear ($self) { $self->calls([]); return $self }

1;
