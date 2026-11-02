# t/01-app/client_ip.t — IP do cliente para os limites de tentativa (#335)
use lib qw(t/lib lib);
use Imports;
use EduMaps::Util::ClientIP qw(client_ip ip_em_redes);

my @padrao = @EduMaps::Util::ClientIP::REDES_CONFIAVEIS;

subtest 'ip_em_redes' => sub {
  ok ip_em_redes('127.0.0.1', \@padrao),        'loopback';
  ok ip_em_redes('172.19.0.5', \@padrao),       'rede do Docker (172.16/12)';
  ok ip_em_redes('192.168.10.2', \@padrao),     '192.168/16';
  ok ip_em_redes('10.1.2.3', \@padrao),         '10/8';
  ok ip_em_redes('::1', \@padrao),              'loopback IPv6';
  ok ip_em_redes('::ffff:127.0.0.1', \@padrao), 'IPv4 mapeado em IPv6';
  ok !ip_em_redes('172.32.0.1', \@padrao),      '172.32 fica fora de 172.16/12';
  ok !ip_em_redes('200.10.20.30', \@padrao),    'IP público';
  ok !ip_em_redes('2001:db8::1', \@padrao),     'IPv6 público';
  ok !ip_em_redes('999.1.1.1', \@padrao),       'IPv4 inválido';
  ok !ip_em_redes(undef, \@padrao),             'sem IP';
};

# Controller falso: só o que client_ip usa.
{
  package FakeC;
  sub new { my ($c, %a) = @_; bless {%a}, $c }
  sub tx  { my $s = shift; bless { ip => $s->{par} }, 'FakeTx' }
  sub req { my $s = shift; bless { h => $s->{hdr} }, 'FakeReq' }
  package FakeTx;  sub remote_address { $_[0]{ip} }
  package FakeReq; sub headers { bless { h => $_[0]{h} }, 'FakeH' }
  package FakeH;   sub header  { $_[0]{h} }
}

subtest 'client_ip' => sub {
  is client_ip(FakeC->new(par => '127.0.0.1', hdr => '200.1.2.3')), '200.1.2.3',
    'atrás do nginx (loopback): vale o X-Real-IP';
  is client_ip(FakeC->new(par => '172.19.0.4', hdr => '200.1.2.3')), '200.1.2.3',
    'nginx em contêiner (rede privada): vale o X-Real-IP';
  is client_ip(FakeC->new(par => '200.9.9.9', hdr => '1.2.3.4')), '200.9.9.9',
    'conexão direta de fora: cabeçalho forjado é ignorado';
  is client_ip(FakeC->new(par => '127.0.0.1', hdr => 'lixo<script>')), '127.0.0.1',
    'cabeçalho malformado é ignorado';
  is client_ip(FakeC->new(par => '127.0.0.1', hdr => undef)), '127.0.0.1',
    'sem cabeçalho: IP da conexão';
};

done_testing();
