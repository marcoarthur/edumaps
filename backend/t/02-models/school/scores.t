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

my $tag = '[school model] scores';

subtest qq/
$tag <busca scores> happy-path score de escolas
 - busca escolas randômicas e verificação básica do scores
/ => sub {
  skip_all 'unimplemented';
  my $schools = random_schools_ids->map('co_entidade');
  my $params = { 'id' => { -in => $schools->to_array } };
  my $results = $model->scores($params);
  $results->each(
    sub {
      like(
        $_,
        hash {
          field escola => hash { etc(); };
        },
        'estrutura de retorno'
      );
    }
  );
  pass('happy test');
};

done_testing;
