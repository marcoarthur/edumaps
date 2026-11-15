# t/04-api/ranking_recorte.t
# #430 (AN-11): ranking por recorte — escolas de um município e redes
# municipais de uma UF, com o mínimo de escolas, a variação entre edições e o
# INSE como contexto. Municípios e escolas fictícios (UF "XX").
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

# A (6000301): 4 escolas em 2023 e em 2021; B (6000302): 3 escolas só em
# 2023; C (6000303): 2 escolas (fica de fora pelo mínimo).
my @ESC = (
  # inep,        mun,      2023, 2021,  inse
  ['60003001', 6000301, 6.0, 5.0, 5.0],
  ['60003002', 6000301, 5.0, 4.0, 5.0],
  ['60003003', 6000301, 7.0, 6.0, 5.0],
  ['60003004', 6000301, 6.0, 5.0, 5.0],
  ['60003005', 6000302, 7.0, undef, 4.0],
  ['60003006', 6000302, 7.0, undef, 4.0],
  ['60003007', 6000302, 7.0, undef, 4.0],
  ['60003008', 6000303, 9.0, undef, 6.0],
  ['60003009', 6000303, 9.0, undef, 6.0],
);
my %NOME = (6000301 => 'Alfa do Teste', 6000302 => 'Beta do Teste', 6000303 => 'Gama do Teste');
my @INEPS = map { $_->[0] } @ESC;
my $ph = join ',', ('?') x @INEPS;

my $limpa = sub {
  $dbh->do("DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN ($ph)", {}, @INEPS);
  $dbh->do("DELETE FROM clean.inse WHERE id_escola IN ($ph)", {}, @INEPS);
};
$limpa->();
END { $limpa->() }

my $ins = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas
  (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa, ideb_observado)
  VALUES (?, 'XX', ?, ?, ?, 'Municipal', ?, 'fundamental_i', ?)});
my $inse = $dbh->prepare(q{INSERT INTO clean.inse (nu_ano_saeb, id_escola, media_inse) VALUES (2023, ?, ?)});
for my $e (@ESC) {
  my ($inep, $mun, $v23, $v21, $nse) = @$e;
  $ins->execute($inep, $mun, $NOME{$mun}, "Escola $inep", 2023, $v23);
  $ins->execute($inep, $mun, $NOME{$mun}, "Escola $inep", 2021, $v21) if defined $v21;
  $inse->execute($inep, $nse);
}

subtest 'redes municipais da UF' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX')->status_is(200)->tx->res->json;
  is $r->{ano}, 2023, 'edição atual';
  is $r->{ano_anterior}, 2021, 'edição anterior';
  is $r->{minimo_escolas}, 3, 'mínimo de escolas';
  is $r->{fora_por_poucas_escolas}, 1, 'Gama (2 escolas) fora';
  is [map { $_->{municipio} } @{ $r->{redes} }], ['Beta do Teste', 'Alfa do Teste'], 'ordem pela média';

  my %rede = map { $_->{municipio} => $_ } @{ $r->{redes} };
  is $rede{'Beta do Teste'}{media}, 7, 'média simples das escolas';
  is $rede{'Alfa do Teste'}{media}, 6, 'média de Alfa';
  is $rede{'Alfa do Teste'}{variacao}, 1, 'variação 2021→2023';
  is $rede{'Beta do Teste'}{variacao}, undef, 'sem edição anterior: sem variação';
  is $rede{'Alfa do Teste'}{escolas}, 4, 'escolas contadas';
  is $rede{'Alfa do Teste'}{inse}, 5, 'INSE médio das escolas da rede';
  ok defined $rede{'Alfa do Teste'}{quinto_inse}, 'quinto de INSE';
  is $rede{'Alfa do Teste'}{posicao}, 2, 'posição';
};

subtest 'validações das redes' => sub {
  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais')->status_is(400);
  $t->get_ok('/api/ranking/redes?indicador=infraestrutura&uf=XX')->status_is(400)
    ->json_like('/error' => qr/IDEB\/SAEB/);
  $t->get_ok('/api/ranking/redes?indicador=ideb_ensino_medio&uf=XX')->status_is(404);
};

subtest 'escolas de um município' => sub {
  my $r = $t->get_ok('/api/ranking/escolas?codigo_ibge=6000301&indicador=ideb_anos_iniciais')
    ->status_is(200)->tx->res->json;
  is $r->{ano}, 2023, 'edição mais recente';
  is $r->{total}, 4, 'quatro escolas';
  is $r->{escolas}[0]{co_entidade}, '60003003', 'maior IDEB primeiro';
  is [map { $_->{posicao} } @{ $r->{escolas} }], [1, 2, 2, 4], 'empate divide a posição';
  is $r->{escolas}[0]{inse}, 5, 'INSE ao lado';

  $t->get_ok('/api/ranking/escolas?codigo_ibge=6000399&indicador=ideb_anos_iniciais')->status_is(404);
  $t->get_ok('/api/ranking/escolas?codigo_ibge=123&indicador=ideb_anos_iniciais')->status_is(400);
  $t->get_ok('/api/ranking/escolas?codigo_ibge=6000301&indicador=nao_existe')->status_is(400);
};

done_testing;
