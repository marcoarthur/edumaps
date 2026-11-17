# t/02-models/indices_versao.t
# #462 (RX-01): a versão citável dos seis índices do Censo. O registro em
# EduMaps::Model::Rank::School e o COMMENT de clean.mv_escolas_scores têm de
# dizer a mesma versão: mudança de fórmula na MV sobe as duas.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::Model::Rank::School;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $versao = $EduMaps::Model::Rank::School::INDICES_VERSAO;
my @hist   = @EduMaps::Model::Rank::School::INDICES_HISTORICO;

subtest 'registro' => sub {
  like $versao, qr/^indices-v\d+$/, 'formato indices-vN';
  is $hist[0]{versao}, $versao, 'a primeira linha do histórico é a versão atual';
  my @n = map { /(\d+)$/ ? $1 : -1 } map { $_->{versao} } @hist;
  is \@n, [reverse 1 .. scalar @n], 'histórico do mais novo ao mais antigo, sem buraco';
  for my $h (@hist) {
    like $h->{data}, qr/^\d{4}-\d{2}-\d{2}$/, "$h->{versao}: data";
    ok length($h->{mudou}) > 10, "$h->{versao}: o que mudou";
  }
};

subtest 'COMMENT da MV com a mesma versão' => sub {
  my ($c) = $dbh->selectrow_array(
    q{SELECT obj_description('clean.mv_escolas_scores'::regclass, 'pg_class')});
  my ($no_banco) = ($c // '') =~ /VERSÃO (indices-v\d+) /;
  is $no_banco, $versao,
    'o COMMENT de clean.mv_escolas_scores diz a versão do registro (mudou a fórmula? suba as duas)';
};

done_testing;
