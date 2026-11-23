# t/02-models/remuneracao_nomes.t
# #536 (QO-02 da P5): nenhum nome da folha do SIOPE codificado duas vezes
# (change remuneracao_nomes_utf8 e a correção na carga).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;

my $t = Test::Mojo->new('EduMaps');
my $dbh = $t->app->schema->storage->dbh;

my ($n) = $dbh->selectrow_array(q{
  SELECT count(*) FROM clean.remuneracao_municipal
   WHERE nome_profissional ~ E'[\\u00C2\\u00C3][\\u0080-\\u00BF]' OR nome_profissional LIKE '%ÿ%'});
is $n, 0, 'nenhum nome com "Ã" seguido de byte de continuação, nem "ÿ"';

done_testing;
