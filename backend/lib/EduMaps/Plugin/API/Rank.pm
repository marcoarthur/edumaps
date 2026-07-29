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
}

1;
