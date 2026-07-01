use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Utils qw(random_schools_ids);
use Test::Mojo;
use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::School';
use open ':std', ':encoding(UTF-8)';
use utf8;

my $schema = EduMaps::Schema->go;
my $model = EduMaps::Model::School->new(schema => $schema);

my $tag = '[school model] matricula:';

subtest qq/
$tag <listagem de matriculas>
 - escolas randômicas, verificação básica
/ => sub {
  my $schools = random_schools_ids->map('co_entidade');
  my $params = { 'me.co_entidade' => { -in => $schools->to_array } };
  my $results = $model->info_enrollment($params);
  ok(
    $results->size <= $schools->size,
    "Matrículas encontradas para: " . $results->size . " Escolas"
  );

  $results->each(
    sub {
      like(
        $_,
        hash {
          field total_basica => number_ge(0);
          field infantil => number_ge(0);
          field fundamental => number_ge(0);
          field sexo => hash {
            field feminino => number_gt(0);
            field masculino => number_gt(0);
          };
          field raca => hash {
            field branca => L();
            field preta => L();
            field parda => L();
            field amarela => L();
            field indigena => L();
          };
          field idade => hash {
            field "0-3"   => number_ge(0); 
            field "4-5"   => number_ge(0); 
            field "6-10"  => number_ge(0); 
            field "11-14" => number_ge(0); 
            field "15-17" => number_ge(0); 
            field "18+"   => number_ge(0); 
          };
          etc();
        },
        'Summario básico das matriculas',
      );
    }
  );
  pass 'ok should fail';
};

done_testing;
