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

  # Cascata de seleção de geotag (região → UF → município)
  $api->get('/regions')->to('cluster#regions')->name('cluster_regions');
  $api->get('/ufs')->to('cluster#ufs')->name('cluster_ufs');
  $api->get('/municipalities')->to('cluster#municipalities')->name('cluster_municipalities');
}

1;