use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::School';

my $schema = EduMaps::Schema->go;
my $model = EduMaps::Model::School->new(schema => $schema);

my $tag = q/[school model] profile:/;

subtest qq/
$tag <Busca por notas das escolas>
  - conjunto de anos -> [2005, 2007,..., 2023]
  - conjunto de escolas -> [33064164,33069395]
/ => sub {
  my $escolas = [33064164,33069395];
  my $anos = [grep { $_ % 2 == 1 } (2005..2025)];

  my $notas = $model->info_grades({ id_escola => $escolas, ano => $anos });
  isa_ok $notas, 'Mojo::Collection';
  ok($notas->size >= 2, 'Pelo menos 1 resultado para cada escola');

  # NOTAS SAEB: matematica e portugues 0-500
  my $f = $notas->first;
  like(
    $f,
    hash {
      field ano => L();
      field ideb_observado => number_gt(0) && number_lt(10);
      field ideb_projecao => E();
      field nota_portugues => number_gt(0) && number_lt(500);
      field nota_matematica => number_gt(0) && number_lt(500);
      field rede => qr/municipal | estadual | privada/xi;
      field etapa => qr/fundamental_(i|ii)|ensino_medio/xi;
      etc();
    },
    'Estrutura esperada para as notas'
  );
};

subtest qq/
$tag <escolas e anos inexistentes>
  - conjunto de anos -> [5555, 6666]
  - conjunto inexistente de escolas -> [211, 2112]
/ => sub {
  my $escolas = [qw/211 2112/];
  my $anos = [5555, 6666];

  my $notas = $model->info_grades({ id_escola => $escolas, ano => $anos });
  isa_ok $notas, 'Mojo::Collection';
  ok($notas->size == 0, 'nenhum resultado para cada escola');
};

done_testing;
