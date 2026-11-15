# t/04-api/school/search_municipio_ordem.t
# #431 (AN-06): a busca por município põe o nome igual ao digitado antes do
# parcial, ignora acento, filtra pelo código IBGE escolhido no autocompletar,
# e as sugestões de município trazem a sigla da UF.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::Util qw(url_escape);

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $INEP_EXATO   = '60001901';   # escola em "Xurupitá"
my $INEP_PORTO   = '60001902';   # escola em "Porto Xurupitá" (nome A..., viria antes)
my $INEP_PREFIXO = '60001903';   # escola em "Xurupitá do Norte"
my %MUN = (
  6000191 => ['Xurupitá',          'XA'],
  6000192 => ['Porto Xurupitá',    'XB'],
  6000193 => ['Xurupitá do Norte', 'XC'],
);

my $limpa = sub {
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?, ?)', {},
    $INEP_EXATO, $INEP_PORTO, $INEP_PREFIXO);
  $dbh->do('DELETE FROM clean.municipios_sp WHERE codigo_ibge IN (?, ?, ?)', {}, keys %MUN);
};
$limpa->();

my $esc = $dbh->prepare('INSERT INTO clean.censo_escolas
    (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio,
     tp_situacao_funcionamento) VALUES (2025, ?, ?, 3, ?, ?, 1)');
$esc->execute($INEP_EXATO,   'Zeta Escola Xurupitá', 6000191, $MUN{6000191}[0]);
$esc->execute($INEP_PORTO,   'Alfa Escola Porto',    6000192, $MUN{6000192}[0]);
$esc->execute($INEP_PREFIXO, 'Beta Escola Norte',    6000193, $MUN{6000193}[0]);

my $mun = $dbh->prepare('INSERT INTO clean.municipios_sp
    (codigo_ibge, nome, nome_municipio, sigla_estado, nome_estado) VALUES (?, ?, ?, ?, ?)');
$mun->execute($_, $MUN{$_}[0], $MUN{$_}[0], $MUN{$_}[1], "Estado $MUN{$_}[1]") for sort keys %MUN;

END { $limpa->() }

my $path = '/api/school/search/pageable';

subtest 'texto livre: nome igual primeiro, depois o prefixo, sem acento' => sub {
  my $r = $t->get_ok("$path?municipio=xurupita&per_page=50")->status_is(200)->tx->res->json;
  my @ineps = grep { /^600019/ } map { $_->{codigo_inep} } @{ $r->{data} // $r->{items} // [] };
  is \@ineps, [$INEP_EXATO, $INEP_PREFIXO, $INEP_PORTO],
    'Xurupitá, depois Xurupitá do Norte, depois Porto Xurupitá';
};

subtest 'código IBGE do autocompletar filtra só o município' => sub {
  my $r = $t->get_ok("$path?codigo_ibge=6000191")->status_is(200)->tx->res->json;
  my @ineps = map { $_->{codigo_inep} } @{ $r->{data} // $r->{items} // [] };
  is \@ineps, [$INEP_EXATO], 'só a escola de Xurupitá';

  $t->get_ok("$path?codigo_ibge=123")->status_is(400);
};

subtest 'sugestões de município: ordem e sigla da UF' => sub {
  my $r = $t->get_ok('/api/city/suggestions?q=' . url_escape('Xurupitá'))->status_is(200)->tx->res->json;
  my @nossos = grep { $_->{codigo_ibge} =~ /^600019/ } @$r;
  is [map { $_->{nome} } @nossos], ['Xurupitá', 'Xurupitá do Norte', 'Porto Xurupitá'], 'ordem';
  is $nossos[0]{uf}, 'XA', 'sigla da UF';
};

done_testing;
