package EduMaps::Util::ClientIP;
use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(client_ip client_ip_app ip_em_redes);

# IP de quem fez a requisição, para limites por IP (#335).
#
# Atrás do nginx, `tx->remote_address` é o IP do próprio nginx; o IP real vem
# no cabeçalho X-Real-IP, que o nginx preenche. Mas a API também escuta
# direto (0.0.0.0:3000 no LXC, 3010 no Docker local), e aí qualquer cliente
# pode forjar o cabeçalho. Por isso ele só vale quando quem conecta é um
# proxy confiável (por padrão: loopback e redes privadas, onde o nginx vive).

our @REDES_CONFIAVEIS = qw(127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 ::1);

my $IPV4 = qr/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;

sub _ipv4_num {
  my ($ip) = @_;
  $ip =~ s/^::ffff://i;                # IPv4 mapeado em IPv6
  my @o = $ip =~ $IPV4 or return;
  return if grep { $_ > 255 } @o;
  return ($o[0] << 24) | ($o[1] << 16) | ($o[2] << 8) | $o[3];
}

# Verdadeiro se $ip está em alguma das redes (IPv4 em CIDR; IPv6 só exato).
sub ip_em_redes {
  my ($ip, $redes) = @_;
  return 0 unless defined $ip && length $ip;
  my $n = _ipv4_num($ip);
  for my $rede (@$redes) {
    if ($rede =~ m{^([\d.]+)/(\d{1,2})$}) {
      next unless defined $n;
      my ($base, $bits) = (_ipv4_num($1), $2);
      next unless defined $base && $bits <= 32;
      my $mask = $bits == 0 ? 0 : (0xFFFFFFFF << (32 - $bits)) & 0xFFFFFFFF;
      return 1 if ($n & $mask) == ($base & $mask);
    }
    elsif (lc $rede eq lc $ip) {
      return 1;
    }
  }
  return 0;
}

# IP do cliente para o controller $c. $redes opcional (default acima).
sub client_ip {
  my ($c, $redes) = @_;
  my $par = $c->tx->remote_address;
  my $hdr = $c->req->headers->header('X-Real-IP');
  if (defined $hdr && $hdr =~ /^[A-Fa-f0-9:.]{2,45}$/
      && ip_em_redes($par, $redes // \@REDES_CONFIAVEIS)) {
    return $hdr;
  }
  return $par;
}

# IP do cliente com a lista de proxies do config da aplicação
# (`auth_limite => { proxies_confiaveis => [...] }`); sem ela, o padrão acima.
# É o que os controllers usam (#335 login; inscrições por QR).
sub client_ip_app {
  my ($c) = @_;
  my $redes = (($c->app->config // {})->{auth_limite} // {})->{proxies_confiaveis};
  return client_ip($c, ref $redes eq 'ARRAY' ? $redes : undef) // '';
}

1;
