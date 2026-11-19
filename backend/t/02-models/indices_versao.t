# t/02-models/indices_versao.t
# #462 (RX-01): a versão citável dos seis índices do Censo. O registro em
# EduMaps::Model::Rank::School e o COMMENT de clean.mv_escolas_scores têm de
# dizer a mesma versão: mudança de fórmula na MV sobe as duas. #501 (RE-01):
# os textos que dizem qual é a versão atual (ajudas e fórmula completa)
# também, para quem cita não citar uma versão velha.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::Model::Rank::School;
use Mojo::File qw(path);

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

subtest 'textos com a versão atual (#501)' => sub {
  my $raiz = path('..');
  my $le = sub ($rel) { $raiz->child($rel)->slurp('UTF-8') };

  my $rankings = $le->('docs/ajuda/comunidade/rankings.md');
  my ($atual) = $rankings =~ /A atual é a \*\*`(indices-v\d+)`\*\*/;
  is $atual, $versao, 'rankings.md: "A atual é a …" (mudou a fórmula? atualize os textos)';
  my ($arquivo) = $rankings =~ /ranking-escolas-[\w-]+?-(indices-v\d+)\.csv/;
  is $arquivo, $versao, 'rankings.md: exemplo do nome do arquivo';

  my $formula = $le->('docs/analises/ivet.md');
  my ($citavel) = $formula =~ /Versão citável dos seis scores\*\* \(#462\): \*\*`(indices-v\d+)`\*\*/;
  is $citavel, $versao, 'ivet.md §2.2 ("Fórmula completa" de /fontes)';

  for my $rel ('docs/ajuda/comunidade/fontes-e-metodologia.md', 'docs/ajuda/comunidade/base-de-analise.md') {
    my ($ex) = $le->($rel) =~ /ex\.: `(indices-v\d+)`/;
    is $ex, $versao, "$rel: exemplo da versão";
  }
};

done_testing;
