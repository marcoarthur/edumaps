# t/04-api/rede/indicadores.t
# #397 (visão da rede, #375; P2-PG-03): metas comparáveis por indicador.
#
#   * só metas OFICIAIS do plano vigente mais recente de cada escola da rede;
#   * por indicador: escolas com meta, quantas mediram, andamento médio das
#     medidas (sem medida = null, nunca 0), base ajustada marcada (P2-PG-05);
#   * metas manuais contadas à parte; rascunho e outra rede ficam fora.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.rede_vinculos')")
  && $dbh->selectrow_array("SELECT to_regclass('analytics.indicadores_meta_catalogo')");
skip_all('rede ou catálogo de indicadores ausente (migration nao aplicada)') unless $has;

my $P    = sprintf '%04d', $$ % 10000;
my $M    = 9990021;
my %E    = (A => 77779001, B => 77779002, C => 77779003, D => 77779004);
my $REDE = "ind.rede.$P\@edumaps.test";

sub limpa {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ANY(?)', {}, [ values %E ]);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ANY(?)', {}, [ values %E ]);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $REDE);
}
limpa();
END { limpa() if $has }

my $censo = $dbh->prepare(q{INSERT INTO clean.censo_escolas
  (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, tp_situacao_funcionamento)
  VALUES (2025, ?, ?, ?, ?, 'Vila Ind', 'ZZ', 1)});
$censo->execute($E{A}, 'A Escola', 3, $M);
$censo->execute($E{B}, 'B Escola', 3, $M);
$censo->execute($E{C}, 'C Escola', 3, $M);
$censo->execute($E{D}, 'D Estadual', 2, $M);

my $plano = sub ($inep, $situacao) {
  my ($id) = $dbh->selectrow_array(q{INSERT INTO clean.planos_gestao (cod_inep, tipo, titulo, situacao)
    VALUES (?, 'acao', ?, ?) RETURNING id}, {}, $inep, "Plano $inep $situacao", $situacao);
  my ($obj) = $dbh->selectrow_array(q{INSERT INTO clean.planos_objetivos (plano_id, titulo, ordem)
    VALUES (?, 'Obj', 1) RETURNING id}, {}, $id);
  return ($id, $obj);
};
my $meta = sub ($obj, $desc, $ind, $base, $oficial, $alvo, $medicao = undef) {
  my ($id) = $dbh->selectrow_array(q{INSERT INTO clean.planos_metas
    (objetivo_id, descricao, sentido, indicador_codigo, linha_base, linha_base_oficial, alvo)
    VALUES (?, ?, 'aumentar', ?, ?, ?, ?) RETURNING id}, {}, $obj, $desc, $ind, $base, $oficial, $alvo);
  $dbh->do(q{INSERT INTO clean.planos_metas_medicoes (meta_id, data_ref, ano_ref, valor, origem)
    VALUES (?, '2025-12-31', ?, ?, ?)}, {}, $id, ($ind ? 2025 : undef), $medicao, $ind ? 'oficial' : 'manual')
    if defined $medicao;
  return $id;
};
my (undef, $oa) = $plano->($E{A}, 'vigente');
$meta->($oa, 'IDEB A', 'ideb_ai', 5, 5, 6, 5.5);
$meta->($oa, 'Matrículas A', 'matriculas_total', 300, 320, 350, 320);
$meta->($oa, 'Frequência', undef, 80, undef, 90, 85);
my (undef, $ob) = $plano->($E{B}, 'vigente');
$meta->($ob, 'IDEB B', 'ideb_ai', 4, 4, 5);
my (undef, $obr) = $plano->($E{B}, 'rascunho');
$meta->($obr, 'IDEB rascunho', 'ideb_ai', 1, 1, 9, 2);
my (undef, $oc) = $plano->($E{C}, 'rascunho');
$meta->($oc, 'Matrículas C', 'matriculas_total', 10, 10, 20, 15);
my (undef, $od) = $plano->($E{D}, 'vigente');
$meta->($od, 'IDEB D', 'ideb_ai', 3, 3, 4, 3.5);

my $pm = $t->app->model('Pesquisa');
my $c = $pm->rede_conta_criar(undef, { nome => 'Rede Ind', email => $REDE, cargo => undef });
$pm->rede_convite_aceitar($c->{convite}{token}, 'senha123');
$pm->rede_vinculo_conceder(undef, $c->{conta}{id}, 3, $M);
my $tok = $t->post_ok('/api/gestor/login', json => { email => $REDE, senha => 'senha123' })->status_is(200)->tx->res->json->{token};

$t->get_ok('/api/rede/indicadores')->status_is(401);
my $r = $t->get_ok('/api/rede/indicadores', { Authorization => "Bearer $tok" })->status_is(200)->tx->res->json;

is [ map { $_->{codigo} } @{ $r->{indicadores} } ], [ 'ideb_ai', 'matriculas_total' ], 'por número de escolas; rascunho e outra rede fora';
is [ @{$r}{qw(n_escolas n_com_plano_vigente)} ], [ 3, 2 ], 'escolas e com plano vigente';
is $r->{manuais}, { n_metas => 1, n_escolas => 1 }, 'meta manual à parte';

my ($ideb, $mat) = @{ $r->{indicadores} };
is [ @{$ideb}{qw(n_escolas n_metas n_medidas andamento_medio n_base_ajustada)} ], [ 2, 2, 1, 0.5, 0 ], 'IDEB: 2 escolas, 1 medida, média 50%';
is $ideb->{fonte}, 'INEP — IDEB', 'fonte do catálogo';
is [ map { $_->{nome} } @{ $ideb->{escolas} } ], [ 'A Escola', 'B Escola' ], 'escolas em ordem de nome';
my $b = $ideb->{escolas}[1]{meta};
is [ $b->{progresso}, $b->{estado}, $b->{atual} ], [ undef, 'sem_dado', undef ], 'B sem valor: sem dado, nunca 0';
is $ideb->{escolas}[0]{meta}{atual}, { valor => 5.5, ano_ref => 2025, data_ref => '2025-12-31' }, 'A: valor e ano';

is [ @{$mat}{qw(n_escolas n_medidas andamento_medio n_base_ajustada)} ], [ 1, 1, 0.4, 1 ], 'matrículas: base ajustada contada';
my $ma = $mat->{escolas}[0]{meta};
is [ $ma->{base_ajustada}, $ma->{linha_base}, $ma->{linha_base_oficial} ], [ Mojo::JSON::true, 300, 320 ], 'base ajustada marcada, com o oficial';
is $mat->{escolas}[0]{plano_titulo}, "Plano $E{A} vigente", 'plano da escola';

done_testing;
