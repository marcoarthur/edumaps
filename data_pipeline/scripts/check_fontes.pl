#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json decode_json);
use Net::DNS;
use LWP::UserAgent;
use IO::Socket::SSL;
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use YAML::XS qw(LoadFile);

# Script para verificar conectividade das 11 fontes listadas
# Taxonomia: ok, http_4xx, http_5xx, dns_morto, tls_invalido, sem_api, auth_requerida, e_sic_pendente

my $ua = LWP::UserAgent->new(
  timeout => 15,
  agent   => 'EduMaps-conncheck/1.0',
  ssl_opts => { verify_hostname => 1, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER },
);

my $dns_res = Net::DNS::Resolver->new(
  nameservers => ['8.8.8.8'],
  recurse     => 1,
  timeout     => 5,
  udp_timeout => 5,
);

# Lista das 11 fontes (estado verificado por máquina)
my @FONTES = (
  { nome => 'IBGE_SIDRA', host => 'servicodados.ibge.gov.br', url => 'https://servicodados.ibge.gov.br/api/v1/pesquisas', expected => 'ok' },
  { nome => 'IBGE_MALHA', host => 'geoftp.ibge.gov.br', url => 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2020/UFs/', expected => 'ok' },
  { nome => 'SICONFI', host => 'apidatalake.tesouro.gov.br', url => 'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/rreo', expected => 'ok' },
  { nome => 'CGU', host => 'portaldatransparencia.gov.br', url => 'https://portaldatransparencia.gov.br/api-de-dados/despesas', expected => 'ok' },
  { nome => 'INEP', host => 'download.inep.gov.br', url => 'https://download.inep.gov.br/', expected => 'ok' },
  { nome => 'CENSO', host => 'download.inep.gov.br', url => 'https://download.inep.gov.br/', expected => 'ok' },
  { nome => 'ANAC', host => 'www.gov.br', url => 'https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aeronaves', expected => 'ok' },
  { nome => 'DADOSGOV', host => 'dados.gov.br', url => 'https://dados.gov.br/', expected => 'ok' },
  { nome => 'INMET', host => 'portal.inmet.gov.br', url => 'https://portal.inmet.gov.br/', expected => 'sem_api' }, # historicamente sem API prática; medir
  { nome => 'MAPBIOMAS', host => 'storage.googleapis.com', url => 'https://storage.googleapis.com/mapbiomas-public/', expected => 'ok' },
  { nome => 'OPENSTREETMAP', host => 'overpass-api.de', url => 'https://overpass-api.de/api/interpreter', expected => 'ok' },
);

# E-SIC é outro caso, mas está listado no issue como pendente; não está nas 11 principais? 
# O issue fala "4 jobs com e-SIC pendente" - verificar se conta. Mas foco é 11 fontes.

sub dns_ok {
  my ($host) = @_;
  my $query = $dns_res->search($host);
  return 0 unless $query;
  my @answers = $query->answer;
  foreach my $rr (@answers) {
    if ($rr->type eq 'A' || $rr->type eq 'AAAA') {
      return 1;
    }
  }
  return 0;
}

sub check_host {
  my ($fonte) = @_;
  my $host = $fonte->{host};
  my $url  = $fonte->{url};
  
  # Verifica DNS via 8.8.8.8
  unless (dns_ok($host)) {
    return { nome => $fonte->{nome}, host => $host, estado => 'dns_morto', msg => 'sem resposta A/AAAA via 8.8.8.8' };
  }
  
  # Faz GET HEAD/GET limitado
  my $req = HTTP::Request->new('GET', $url, ['User-Agent' => $ua->agent]);
  $req->header('Accept' => '*/*');
  
  my $res;
  eval { $res = $ua->request($req); };
  if ($@) {
    my $err = $@;
    if ($err =~ /certificate|SSL|TLS|ssl/i) {
      return { nome => $fonte->{nome}, host => $host, estado => 'tls_invalido', msg => substr($err, 0, 100) };
    }
    if ($err =~ /timeout|timed out/i) {
      return { nome => $fonte->{nome}, host => $host, estado => 'http_5xx', msg => 'timeout' };
    }
    return { nome => $fonte->{nome}, host => $host, estado => 'http_5xx', msg => substr($err, 0, 100) };
  }
  
  my $code = $res->code;
  my $content = $res->decoded_content // $res->content // '';
  
  # Classificações por código
  if ($code >= 200 && $code < 300) {
    return { nome => $fonte->{nome}, host => $host, estado => 'ok', msg => "HTTP $code" };
  }
  if ($code == 401 || $code == 403) {
    return { nome => $fonte->{nome}, host => $host, estado => 'auth_requerida', msg => "HTTP $code" };
  }
  if ($code >= 400 && $code < 500) {
    # 404 pode indicar sem_api dependendo do contexto
    if ($code == 404) {
      return { nome => $fonte->{nome}, host => $host, estado => 'sem_api', msg => "HTTP $code" };
    }
    return { nome => $fonte->{nome}, host => $host, estado => 'http_4xx', msg => "HTTP $code" };
  }
  if ($code >= 500) {
    return { nome => $fonte->{nome}, host => $host, estado => 'http_5xx', msg => "HTTP $code" };
  }
  
  return { nome => $fonte->{nome}, host => $host, estado => 'http_5xx', msg => "HTTP $code" };
}

sub main {
  my %opts;
  GetOptions(\%opts, 'json', 'allowlist=s', 'check-diverg');
  
  my $repo_root = dirname(dirname(dirname(__FILE__)));
  my $allowlist_file = $opts{allowlist} // catfile($repo_root, 'data_pipeline', 'allowlist.yaml');
  
  my $allowlist = {};
  if (-f $allowlist_file) {
    eval { $allowlist = LoadFile($allowlist_file) // {}; };
    if (ref $allowlist eq 'HASH' && exists $allowlist->{sources} && ref $allowlist->{sources} eq 'ARRAY') {
      $allowlist = $allowlist->{sources}; # tratar como lista
    }
  }
  
  my @results;
  foreach my $fonte (@FONTES) {
    my $r = check_host($fonte);
    push @results, $r;
  }
  
  # Verifica divergências código vs allowlist (por host)
  my @divs;
  if ($opts{'check-diverg'}) {
    my $al_list = [];
    if (ref $allowlist eq 'ARRAY') {
      $al_list = $allowlist;
    }
    foreach my $fonte (@FONTES) {
      my $host = $fonte->{host};
      foreach my $s (@$al_list) {
        if (ref $s eq 'HASH') {
          my $id = $s->{id} // '';
          if ($id =~ /ibge|siconfi|cgu|inep|censo|anac|dadosgov|inmet|mapbioma|osm|overpass/i) {
            if (defined $s->{host} && $s->{host} ne $host) {
              push @divs, { nome => $fonte->{nome}, cod_host => $host, al_host => $s->{host} };
            }
          }
        }
      }
    }
  }
  
  my $dt = POSIX::strftime('%Y-%m-%dT%H:%M:%SZ', gmtime());
  my $out = {
    dt => $dt,
    resultados => \@results,
    divergencias_codigo_allowlist => \@divs,
  };
  
  if ($opts{json}) {
    print encode_json($out);
  } else {
    print "=== Contrato de conectividade ($dt) ===\n";
    printf "%-20s %-40s %-15s %s\n", "FONTE", "HOST", "ESTADO", "MSG";
    print "=" x 90, "\n";
    my $res_list = $out->{resultados} || [];
    foreach my $r (@$res_list) {
      printf "%-20s %-40s %-15s %s\n", $r->{nome}, $r->{host}, $r->{estado}, $r->{msg} // '';
    }
    my @dlist = @divs; if (@dlist) {
      print "\nDIVERGÊNCIAS CÓDIGO vs ALLOWLIST:\n";
      foreach my $d (@divs) {
        print "  $d->{nome}: código=$d->{cod_host} allowlist=$d->{al_host}\n";
      }
    }
  }
}

main();
