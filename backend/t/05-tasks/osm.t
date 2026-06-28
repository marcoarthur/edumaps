use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Mojo::JSON qw(decode_json);

my $t = Test::Mojo->new('EduMaps');
my $minion = $t->app->minion;
my $cod = 3555406;
my $not_exist = 110001; #código de município inexistente (antigo falta 1 digito)

sub _delete_previous {
  my $rs = $t->app->schema->resultset('OsmQuery')->search_rs( { city_fid => $cod } );
  $rs->search_related('osm_landuses')->delete;
  $rs->delete;
}

subtest qq{executando task query_osm com codigo_municipio = $cod} => sub {
  _delete_previous;
  my $id = $t->app->get_osm($cod);
  my $job = $minion->job($id);

  $minion->perform_jobs;

  # Verifica se o job foi concluído com sucesso
  ok $job->info->{state} eq 'finished', 'job finalizado com sucesso';

  # Obtém o resultado (GeoJSON)
  my $json = $job->info->{result};

  if ($json) {
    # Verifica estrutura básica do GeoJSON
    is $json->{type}, 'FeatureCollection', 'tipo é FeatureCollection';
    ok exists $json->{features}, 'possui campo features';
    ok ref($json->{features}) eq 'ARRAY', 'features é um array';
  }

  # Verifica se a task foi registrada com o nome correto
  is $job->task, 'query_osm', 'task executada é query_osm';
};

done_testing;
