package EduMaps::Plugin::API::Cluster;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has cluster_path => '/api/cluster';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->cluster_path);

  $api->get('/schools')->to('cluster#schools')->name('cluster_schools');

  # Catálogo de indicadores (presets, colunas e anos disponíveis)
  $api->get('/presets')->to('cluster#presets')->name('cluster_presets');
  $api->get('/columns')->to('cluster#columns')->name('cluster_columns');
  $api->get('/years')->to('cluster#years')->name('cluster_years');

  # Resumo semântico dos clusters (rótulo em linguagem natural + indicadores)
  $api->get('/summary')->to('cluster#summary')->name('cluster_summary');

  # Execuções guardadas (#427): resumo + universo, mapa e exportação CSV.
  $api->get('/execucoes/:run_id')->to('cluster#execucao')->name('cluster_execucao');
  $api->get('/execucoes/:run_id/escolas')->to('cluster#execucao_escolas')->name('cluster_execucao_escolas');
  $api->get('/execucoes/:run_id/csv')->to('cluster#execucao_csv')->name('cluster_execucao_csv');

  # Cascata de seleção de geotag (região → UF → município)
  $api->get('/regions')->to('cluster#regions')->name('cluster_regions');
  $api->get('/ufs')->to('cluster#ufs')->name('cluster_ufs');
  $api->get('/municipalities')->to('cluster#municipalities')->name('cluster_municipalities');
}

1;