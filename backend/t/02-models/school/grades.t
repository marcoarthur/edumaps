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
  - conjunto de escolas -> duas com todas as notas na forma esperada
/ => sub {
  # Escolas escolhidas por terem TODAS as linhas de IDEB da faixa de anos na
  # forma que a asserção abaixo exige, e não códigos INEP fixos.
  #
  # Não basta sortear no IDEB: `info_grades` não tem ORDER BY, então
  # `$notas->first` é uma linha qualquer, e existem linhas com rede 'Federal'
  # (fora do regex) e com notas nulas (fora do number_gt). Com o sorteio simples
  # o teste passava ou falhava por acaso. O NOT EXISTS pega a escola inteira,
  # não só a linha.
  my $anos = [grep { $_ % 2 == 1 } (2005..2025)];
  my @escolas = _escolas_notas_na_forma($schema, $anos);
  ok(scalar @escolas == 2, 'Achou 2 escolas cujas notas batem com a forma esperada');

  my $notas = $model->info_grades({ id_escola => \@escolas, ano => $anos });
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

# Escolhe duas escolas cujas linhas de IDEB na faixa de anos informada estão
# todas na forma que a subteste acima valida: rede municipal/estadual/privada,
# etapa reconhecida, IDEB observado e notas de português/matemática dentro dos
# intervalos. O NOT EXISTS olha a escola inteira — filtrar linha a linha não
# impede que `info_grades`, que não tem ORDER BY, devolva primeiro uma linha
# fora da forma.
sub _escolas_notas_na_forma ($schema, $anos) {
  my $sql = q{
    SELECT DISTINCT a.id_escola
    FROM clean.ideb_notas_escolas a
    WHERE a.ano = ANY(?) AND a.id_escola IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM clean.ideb_notas_escolas b
        WHERE b.id_escola = a.id_escola AND b.ano = ANY(?)
          AND ( b.rede IS NULL OR b.rede NOT IN ('Municipal','Estadual','Privada')
             OR b.etapa IS NULL
             OR b.etapa NOT IN ('fundamental_i','fundamental_ii','ensino_medio')
             OR b.ideb_observado IS NULL OR b.ideb_observado <= 0 OR b.ideb_observado >= 10
             OR b.nota_portugues IS NULL OR b.nota_portugues <= 0 OR b.nota_portugues >= 500
             OR b.nota_matematica IS NULL OR b.nota_matematica <= 0 OR b.nota_matematica >= 500 ) )
    ORDER BY a.id_escola
    LIMIT 2
  };
  my $sth = $schema->storage->dbh->prepare($sql);
  $sth->execute($anos, $anos);
  my @ids;
  while (my ($id) = $sth->fetchrow_array) { push @ids, $id }
  return @ids;
}

done_testing;
