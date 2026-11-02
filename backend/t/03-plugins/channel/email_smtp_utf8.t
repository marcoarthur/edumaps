# t/03-plugins/channel/email_smtp_utf8.t
# O caminho Net::SMTP real manda o envelope em BYTES UTF-8 (#336): texto com
# acento chegava como caracteres e o Net::SMTP morria com "Wide character in
# syswrite". Net::SMTP é substituído por um falso que só registra o datasend.
use lib qw(t/lib lib);
use Imports;
use EduMaps::Channel::Email;

my @datasend;
{
  package FakeSMTP;
  sub new      { bless {}, shift }
  sub datasend { my ($s, $d) = @_; push @datasend, $d; die "Wide character in syswrite\n" if utf8::is_utf8($d) && $d =~ /[^\x00-\xFF]/; 1 }
  sub AUTOLOAD { 1 }
  sub DESTROY  { }
}
require Net::SMTP;
no warnings 'redefine';
local *Net::SMTP::new = sub { FakeSMTP->new };

my $mail = EduMaps::Channel::Email->new(
  config  => { smtp_host => 'smtp.teste', smtp_port => 1025, from => 'nao-responda@teste.example' },
  enabled => 1,
  schema  => undef,
);

my $r = $mail->send_message({
  to => 'gestora@teste.example', operacao => 'alerta',
  assunto => 'Redefinição de senha', corpo => "Olá, Conceição — senha nova: ação ✓",
});
ok $r->{ok}, 'envio com acento e símbolo não morre' or diag $r->{error};
is scalar(@datasend), 1, 'um datasend';
ok !utf8::is_utf8($datasend[0]), 'envelope vai em bytes';
like $datasend[0], qr/Ol\xC3\xA1, Concei\xC3\xA7\xC3\xA3o/, 'acentos em UTF-8';
like $datasend[0], qr/Subject: =\?UTF-8\?/, 'assunto com acento em MIME';

done_testing();
