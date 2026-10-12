# t/03-plugins/channel/email.t
# Canal de e-mail: validação/normalização do endereço, guarda de SMTP ausente e
# envelope montado (sem abrir socket — `_smtp_transaction` é sobrescrito).
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::Email';

my $ch = EduMaps::Channel::Email->new(config => {}, schema => undef);
is $ch->name, 'email', 'nome';
is $ch->address_kind, 'email', 'tipo de endereço';
ok $ch->supports_confirm, 'e-mail suporta confirmação';

subtest 'validação e normalização' => sub {
  my $v = $ch->validate_address(' Foo.Bar@Exemplo.COM ');
  ok $v->{ok}, 'válido';
  is $v->{normalized}, 'foo.bar@exemplo.com', 'trim + minúsculas';

  ok !$ch->validate_address('sem-arroba')->{ok},  'sem @ inválido';
  ok !$ch->validate_address('a@b')->{ok},         'sem TLD inválido';
  ok !$ch->validate_address('a b@c.com')->{ok},   'com espaço inválido';
  ok !$ch->validate_address('')->{ok},            'vazio inválido';
};

subtest 'SMTP ausente falha de forma explícita' => sub {
  my $res = $ch->send_message({ to => 'a@b.com', operacao => 'aviso', corpo => 'x' });
  ok !$res->{ok}, 'falha';
  is $res->{error}, 'SMTP não configurado', 'erro explícito';
};

subtest 'envelope montado a partir da config' => sub {
  {
    package EmailTest::Capture;
    use Mojo::Base 'EduMaps::Channel::Email', -signatures;
    our $CAPTURED;
    sub _smtp_transaction ($self, $cfg, $to, $from, $envelope) {
      $CAPTURED = { cfg => $cfg, to => $to, from => $from, envelope => $envelope };
      return { ok => 1, provider_message_id => 'smtp-1' };
    }
  }

  my $cap = EmailTest::Capture->new(
    config => { smtp_host => 'smtp.exemplo.org', from => 'nao-responda@exemplo.org', from_name => 'Rede' },
    schema => undef,
  );
  my $res = $cap->send_message({
    to => 'Dest@Exemplo.com', operacao => 'pedido', assunto => 'Reunião', corpo => 'Olá',
  });

  ok $res->{ok}, 'envio ok';
  is $res->{provider_message_id}, 'smtp-1', 'id do provedor';

  my $c = $EmailTest::Capture::CAPTURED;
  is $c->{to}, 'dest@exemplo.com', 'destino normalizado no envelope';
  is $c->{from}, 'nao-responda@exemplo.org', 'remetente do envelope';
  like $c->{envelope}, qr/^From: "Rede" <nao-responda\@exemplo\.org>/m, 'header From com nome';
  like $c->{envelope}, qr/^To: dest\@exemplo\.com/m, 'header To';
  like $c->{envelope}, qr/^Subject: =\?UTF-8\?B\?/m, 'assunto com acento é MIME codificado';
  like $c->{envelope}, qr/charset=UTF-8/, 'corpo UTF-8';
  unlike $c->{envelope}, qr/^List-Unsubscribe/m, 'sem headers: nenhum cabeçalho extra';
};

subtest 'cabeçalhos extras (#216)' => sub {
  my $cap = EmailTest::Capture->new(
    config => { smtp_host => 'smtp.exemplo.org', from => 'nao-responda@exemplo.org' },
    schema => undef,
  );
  my $res = $cap->send_message({
    to => 'dest@exemplo.com', operacao => 'aviso', assunto => 'A', corpo => 'B',
    headers => [
      [ 'List-Unsubscribe'      => '<https://e.org/privacidade/sair/abc>' ],
      [ 'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click' ],
      [ 'Precedence'            => 'bulk' ],
      [ 'X-Injecao'             => "a\r\nBcc: alguem\@x.org" ],
      [ 'Subject'               => 'sobrescrito' ],
      [ 'Nome Ruim'             => 'x' ],
    ],
  });
  ok $res->{ok}, 'envio ok';
  ok exists $res->{mensagem_id}, 'resultado traz mensagem_id';
  my $e = $EmailTest::Capture::CAPTURED->{envelope};
  like $e, qr{^List-Unsubscribe: <https://e\.org/privacidade/sair/abc>\r$}m, 'List-Unsubscribe';
  like $e, qr{^List-Unsubscribe-Post: List-Unsubscribe=One-Click\r$}m, 'List-Unsubscribe-Post';
  like $e, qr{^Precedence: bulk\r$}m, 'Precedence';
  unlike $e, qr/^Bcc:/m, 'quebra de linha no valor não injeta cabeçalho';
  is scalar(() = $e =~ /^Subject:/mg), 1, 'cabeçalho fixo não é sobrescrito';
  unlike $e, qr/^Nome Ruim/m, 'nome inválido descartado';
  my ($hdr) = split /\r\n\r\n/, $e, 2;
  like $hdr, qr/Precedence: bulk/, 'extras ficam no bloco de cabeçalhos';
};

done_testing;
