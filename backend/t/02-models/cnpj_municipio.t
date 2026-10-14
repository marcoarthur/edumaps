use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;

# =================================================================
# EduMaps::Data::CnpjMunicipio (#240)
#
# Sem rede: UA e dbh são injetados. Verifica
#   1. resolução pela BrasilAPI (codigo_municipio_ibge -> IBGE 7);
#   2. fallback para a Minha Receita quando a primária não achou;
#   3. nao_encontrado quando nenhuma resolve;
#   4. retry de falha transitória antes de desistir;
#   5. cache: hit não chama a API; miss grava no cache;
#   6. host fora do allowlist morre alto.
# =================================================================

my $JOB = 'EduMaps::Data::CnpjMunicipio';
require_ok($JOB);

my $LOG = Mojo::Log->new(level => 'fatal');

# --- dublês de Mojo::UserAgent ---------------------------------------
{
  package MockRes;
  sub new { my ($c, %o) = @_; bless { %o }, $c }
  sub code { $_[0]{code} }
  sub body { $_[0]{body} }

  package MockTx;
  sub new { my ($c, %o) = @_; bless { %o }, $c }
  sub error { $_[0]{error} }
  sub res   { $_[0]{res} }

  package MockUA;
  sub new { my ($c, %o) = @_; bless { fila => $o{fila} // [], urls => [] }, $c }
  sub get {
    my ($self, $url) = @_;
    push @{ $self->{urls} }, $url;
    my $r = shift @{ $self->{fila} };
    return MockTx->new(res => MockRes->new(code => 404, body => '')) unless $r;
    if ($r->{transitorio}) {
      return MockTx->new(error => { code => undef, message => 'Connection refused' });
    }
    if (($r->{code} // 200) != 200) {
      return MockTx->new(error => { code => $r->{code}, message => 'HTTP erro' });
    }
    return MockTx->new(res => MockRes->new(code => 200, body => $r->{body}));
  }
}

sub provider {
  my %o = @_;
  return $JOB->new(log => $LOG, throttle => 0, jitter => 0, backoff_base => 0, %o);
}

my $CNPJ = '45545636000157';

subtest 'resolve pela BrasilAPI (IBGE 7, fonte)' => sub {
  my $ua = MockUA->new(fila => [
    { code => 200, body => '{"codigo_municipio_ibge":3550308,"uf":"SP","municipio":"SAO PAULO"}' },
  ]);
  my $p = provider(ua => $ua);
  my $m = $p->municipio_por_cnpj(['45.545.636/0001-57']);
  is($m->{$CNPJ}{codigo_ibge}, '3550308', 'IBGE normalizado em 7 dígitos');
  is($m->{$CNPJ}{uf}, 'SP', 'UF');
  is($m->{$CNPJ}{municipio}, 'SAO PAULO', 'nome do município');
  is($m->{$CNPJ}{fonte}, 'brasilapi', 'fonte da resolução');
  like($ua->{urls}[0], qr{^https://brasilapi\.com\.br/api/cnpj/v1/\Q$CNPJ\E$}, 'URL da primária');
};

subtest 'fallback para a Minha Receita quando a primária devolve 404' => sub {
  my $ua = MockUA->new(fila => [
    { code => 404 },
    { code => 200, body => '{"codigo_municipio_ibge":3304557,"uf":"RJ","municipio":"RIO DE JANEIRO"}' },
  ]);
  my $p = provider(ua => $ua);
  my $m = $p->municipio_por_cnpj([$CNPJ]);
  is($m->{$CNPJ}{codigo_ibge}, '3304557', 'resolvido pelo fallback');
  is($m->{$CNPJ}{fonte}, 'minhareceita', 'fonte é a Minha Receita');
  is(scalar @{ $ua->{urls} }, 2, 'duas tentativas (primária + fallback)');
};

subtest 'nao_encontrado quando nenhuma fonte resolve' => sub {
  my $ua = MockUA->new(fila => [ { code => 404 }, { code => 400 } ]);
  my $p = provider(ua => $ua);
  my $m = $p->municipio_por_cnpj([$CNPJ]);
  ok($m->{$CNPJ}{nao_encontrado}, 'marcado como não encontrado');
  ok(!exists $m->{$CNPJ}{codigo_ibge}, 'sem IBGE');
};

subtest 'retry de falha transitória antes de desistir' => sub {
  my $ua = MockUA->new(fila => [
    { transitorio => 1 },
    { code => 200, body => '{"codigo_municipio_ibge":3550308,"uf":"SP","municipio":"SAO PAULO"}' },
  ]);
  my $p = provider(ua => $ua);
  my $m = $p->municipio_por_cnpj([$CNPJ]);
  is($m->{$CNPJ}{codigo_ibge}, '3550308', 'resolvido após retry');
  is(scalar @{ $ua->{urls} }, 2, 'retentou a mesma URL');
};

subtest 'falha transitória persistente morre alto' => sub {
  my $ua = MockUA->new(fila => [ { transitorio => 1 }, { transitorio => 1 }, { transitorio => 1 } ]);
  my $p = provider(ua => $ua, max_retries => 2);
  eval { $p->municipio_por_cnpj([$CNPJ]) };
  like($@, qr/falha persistente/, 'morre em vez de orfanar em silêncio');
};

subtest 'CNPJ fora do formato é ignorado' => sub {
  my $ua = MockUA->new(fila => []);
  my $p = provider(ua => $ua);
  is_deeply($p->municipio_por_cnpj(['123', '']), {}, 'nada a resolver');
  is(scalar @{ $ua->{urls} }, 0, 'não chama a API');
};

# --- cache -----------------------------------------------------------
{
  package MockSTH;
  sub new { my ($c, %o) = @_; bless { %o }, $c }
  sub execute {
    my ($self, @p) = @_;
    if ($self->{sql} =~ /^\s*SELECT/i) {
      my $cache = $self->{dbh}{cache};
      $self->{rows} = [ map { [ $_, @{ $cache->{$_} } ] } grep { exists $cache->{$_} } @p ];
    }
    else {
      push @{ $self->{dbh}{inserts} }, [@p];
    }
    return 1;
  }
  sub fetchrow_array {
    my ($self) = @_;
    my $r = shift @{ $self->{rows} || [] };
    return $r ? @$r : ();
  }

  package MockDBH;
  sub new { my ($c, %o) = @_; bless { cache => $o{cache} // {}, inserts => [] }, $c }
  sub prepare { my ($self, $sql) = @_; MockSTH->new(dbh => $self, sql => $sql) }
}

subtest 'cache: hit não chama a API; miss grava' => sub {
  my $cache = { $CNPJ => [ '3550308', 'SP', 'SAO PAULO', 'brasilapi' ] };
  my $dbh_hit = MockDBH->new(cache => $cache);

  my $ua_hit = MockUA->new(fila => []);
  my $p_hit = provider(ua => $ua_hit, dbh => $dbh_hit);
  my $m = $p_hit->municipio_por_cnpj([$CNPJ]);
  is($m->{$CNPJ}{codigo_ibge}, '3550308', 'veio do cache');
  is(scalar @{ $ua_hit->{urls} }, 0, 'cache hit não chama a API');
  is(scalar @{ $dbh_hit->{inserts} }, 0, 'nada regravado no hit');

  my $dbh_miss = MockDBH->new;    # cache vazio
  my $ua_miss = MockUA->new(fila => [
    { code => 200, body => '{"codigo_municipio_ibge":3550308,"uf":"SP","municipio":"SAO PAULO"}' },
  ]);
  my $p_miss = provider(ua => $ua_miss, dbh => $dbh_miss);
  my $mm = $p_miss->municipio_por_cnpj([$CNPJ]);
  is($mm->{$CNPJ}{codigo_ibge}, '3550308', 'miss resolve pela API');
  is(scalar @{ $ua_miss->{urls} }, 1, 'miss chama a API');
  is(scalar @{ $dbh_miss->{inserts} }, 1, 'miss grava no cache');
  is_deeply($dbh_miss->{inserts}[0], [ $CNPJ, '3550308', 'SP', 'SAO PAULO', 'brasilapi' ], 'valores gravados');
};

subtest 'host fora do allowlist morre alto' => sub {
  my $p = provider(
    ua => MockUA->new(fila => []),
    fontes => [ { id => 'mau', url => sub { 'https://exemplo-fora-da-allowlist.example/x' } } ],
  );
  eval { $p->municipio_por_cnpj([$CNPJ]) };
  like($@, qr/ALLOWLIST/, 'morre com motivo de allowlist');
};

done_testing();
