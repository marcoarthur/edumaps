package EduMaps::Plugin::API::Cluster;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has cluster_path => '/api/cluster';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->cluster_path);

  $api->get('/schools')->to('cluster#schools')->name('cluster_schools');

  # Cascata de seleção de geotag (região → UF → município)
  $api->get('/regions')->to('cluster#regions')->name('cluster_regions');
  $api->get('/ufs')->to('cluster#ufs')->name('cluster_ufs');
  $api->get('/municipalities')->to('cluster#municipalities')->name('cluster_municipalities');
}

1;