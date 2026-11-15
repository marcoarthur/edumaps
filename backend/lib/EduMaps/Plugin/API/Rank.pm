package EduMaps::Plugin::API::Rank;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has school_path => '/api/school';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->school_path);
  my $check = [cod_inep => qr/\d{8}/];

  $api->get('/:cod_inep/indicators' => $check)
  ->to('rank#indicators')->name('school_rank_indicators');

  $api->get('/:cod_inep/ranking' => $check)
  ->to('rank#ranking')->name('school_rank_ranking');

  # Ranking por recorte (#430): escolas de um município e redes municipais
  # de uma UF (ou do Brasil).
  my $rec = $r->under('/api/ranking');
  $rec->get('/escolas')->to('rank#escolas_recorte')->name('ranking_escolas_recorte');
  $rec->get('/redes')->to('rank#redes_municipais')->name('ranking_redes_municipais');
}

1;
