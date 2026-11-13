# t/04-api/rede/custos.t
# #398 (visão da rede, #375; RF-109): custo por fonte de recurso na rede.
#
#   * por escola: o plano vigente do painel, com os MESMOS números do
#     relatório dele (canceladas fora; sem valor não é R$ 0, conta à parte);
#   * consolidado: só os planos vigentes; encerrados numa linha à parte;
#   * rascunho e escola de outra rede ficam fora.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.rede_vinculos')")
  && $dbh->selectrow_array(q{SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'clean' AND table_name = 'planos_acoes' AND column_name = 'custo_executado'});
skip_all('rede ou custo executado ausente (migration nao aplicada)') unless $has;

my $P    = sprintf '%04d', $$ % 10000;
my $M    = 9990031;
my %E    = (A => 77779101, B => 77779102, C => 77779103, D => 77779104);
my $REDE = "custos.rede.$P\@edumaps.test";

sub limpa {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ANY(?)', {}, [ values %E ]);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ANY(?)', {}, [ values %E ]);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $REDE);
}
limpa();
END { limpa() if $has }

my $censo = $dbh->prepare(q{INSERT INTO clean.censo_escolas
  (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, tp_situacao_funcionamento)
  VALUES (2025, ?, ?, ?, ?, 'Vila Custo', 'ZZ', 1)});
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
my $acao = sub ($obj, $previsto, $fonte, $executado = undef, $situacao = 'nao_iniciada') {
  $dbh->do(q{INSERT INTO clean.planos_acoes (objetivo_id, descricao, situacao, custo_previsto, fonte_recurso, custo_executado)
    VALUES (?, 'Ação', ?, ?, ?, ?)}, {}, $obj, $situacao, $previsto, $fonte, $executado);
};

my ($pa, $oa) = $plano->($E{A}, 'vigente');
$acao->($oa, 1000, 'pdde', 400);
$acao->($oa, 500.5, 'fundeb');
$acao->($oa, undef, 'proprio');
$acao->($oa, 9999, 'pdde', 9999, 'cancelada');
my (undef, $oae) = $plano->($E{A}, 'encerrado');
$acao->($oae, 200, 'pdde', 200);
my (undef, $ob) = $plano->($E{B}, 'vigente');
$acao->($ob, undef, undef);
my (undef, $obr) = $plano->($E{B}, 'rascunho');
$acao->($obr, 777, 'pdde', 777);
my (undef, $od) = $plano->($E{D}, 'vigente');
$acao->($od, 5000, 'pdde', 5000);

my $pm = $t->app->model('Pesquisa');
my $c = $pm->rede_conta_criar(undef, { nome => 'Rede Custo', email => $REDE, cargo => 'Técnica' });
$pm->rede_convite_aceitar($c->{convite}{token}, 'senha123');
$pm->rede_vinculo_conceder(undef, $c->{conta}{id}, 3, $M);
my $tok = $t->post_ok('/api/gestor/login', json => { email => $REDE, senha => 'senha123' })->status_is(200)->tx->res->json->{token};
my $H = { Authorization => "Bearer $tok" };

$t->get_ok('/api/rede/custos')->status_is(401);
my $r = $t->get_ok('/api/rede/custos', $H)->status_is(200)->tx->res->json;

is [ @{$r}{qw(n_escolas n_com_plano_vigente)} ], [ 3, 2 ], 'escolas da rede e com plano vigente';
is [ map { $_->{nome} } @{ $r->{escolas} } ], [ 'A Escola', 'B Escola' ], 'só escolas com plano vigente, por nome';

my ($a, $b) = @{ $r->{escolas} };
is $a->{plano_id}, $pa, 'A: o plano vigente';
is $a->{custos}, {
  por_fonte => [
    { fonte => 'pdde',   total => 1000,  n_acoes => 1, executado => 400,   n_executadas => 1 },
    { fonte => 'fundeb', total => 500.5, n_acoes => 1, executado => undef, n_executadas => 0 },
  ],
  total => 1500.5, total_executado => 400, n_acoes_sem_custo => 1, n_acoes_sem_executado => 2,
  exercicio => undef, exercicios => [],
}, 'A: previsto × executado por fonte; cancelada fora; executado sem valor é null';

my $rel = $t->get_ok("/api/rede/escolas/$E{A}/planos/$pa/relatorio", $H)->status_is(200)->tx->res->json;
is $a->{custos}, $rel->{custos}, 'A: os mesmos números do relatório da escola';

is $b->{custos}, { por_fonte => [], total => 0, total_executado => undef,
  n_acoes_sem_custo => 1, n_acoes_sem_executado => 1, exercicio => undef, exercicios => [] }, 'B: sem custo informado, nenhuma fonte (não R$ 0 por fonte)';

my $k = $r->{consolidado};
is [ map { [ $_->{fonte}, $_->{total}, $_->{executado} ] } @{ $k->{por_fonte} } ],
   [ [ 'pdde', 1000, 400 ], [ 'fundeb', 500.5, undef ] ], 'consolidado: rascunho, encerrado e outra rede fora';
is [ @{$k}{qw(total total_executado n_acoes_sem_custo n_acoes_sem_executado n_escolas_com_custo)} ],
   [ 1500.5, 400, 2, 3, 1 ], 'consolidado: totais e ações sem valor';

my $enc = $r->{encerrados};
is [ @{$enc}{qw(total total_executado n_planos n_escolas)} ], [ 200, 200, 1, 1 ], 'encerrados à parte';

# exercício (#404): previsto pelo ano do prazo, executado pelo da execução
$dbh->do(q{UPDATE clean.planos_acoes SET prazo = '2026-05-01', executado_em = '2026-06-01'
            WHERE objetivo_id = ? AND fonte_recurso = 'pdde' AND situacao <> 'cancelada'}, {}, $oa);
$dbh->do(q{UPDATE clean.planos_acoes SET prazo = '2025-03-01' WHERE objetivo_id = ? AND fonte_recurso = 'fundeb'}, {}, $oa);
my $r26 = $t->get_ok('/api/rede/custos?exercicio=2026', $H)->status_is(200)->tx->res->json;
is [ @{$r26}{qw(exercicio exercicios)} ], [ 2026, [ 2025, 2026 ] ], 'exercício pedido e anos disponíveis';
my $k26 = $r26->{consolidado};
is [ map { [ $_->{fonte}, $_->{total}, $_->{executado} ] } @{ $k26->{por_fonte} } ], [ [ 'pdde', 1000, 400 ] ],
   '2026: o Fundeb com prazo em 2025 fica fora';
is [ @{$k26}{qw(total total_executado n_acoes_sem_custo n_acoes_sem_prazo n_executado_sem_data)} ],
   [ 1000, 400, 0, 2, 0 ], '2026: ações sem prazo à parte';
is [ @{ $r26->{encerrados} }{qw(n_acoes_sem_prazo n_executado_sem_data total_executado)} ], [ 1, 1, undef ],
   'encerrado: executado sem data não entra no exercício';
my $rel26 = $t->get_ok("/api/rede/escolas/$E{A}/planos/$pa/relatorio?exercicio=2026", $H)->status_is(200)->tx->res->json;
is $r26->{escolas}[0]{custos}, $rel26->{custos}, '2026: os mesmos números do relatório da escola';
$t->get_ok('/api/rede/custos?exercicio=dois', $H)->status_is(400);

done_testing;
