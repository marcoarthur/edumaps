package EduMaps::Controller::Task;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use DateTime;

has _current_year => sub { DateTime->now->year };
has _default_poll_time => 1;

sub request_siope($self) {
  my $v = $self->validation;
  $v->required('codigo_ibge', 'trim')->like(qr/^\d{6}\z/); #codigo ibge antigo 6 digitos
  $v->optional('ano', 'trim')->in(2015 .. $self->_current_year);

  return $self->bad_req if $self->any_error;

  my $job_id = $self->get_siope(
    $v->param('codigo_ibge'),
    $v->param('ano') || $self->_current_year
  );

  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");

  $self->render(
    status => 202,
    json => {task => 'query_siope', job_id => $job_id},
  );
}

sub job_progress($self) {
  my $v = $self->validation;
  $v->required('job_id', 'trim')->num;

  return $self->bad_req if $self->any_error;

  $self->render_later;
  $self->monitor_job(
    {
      job_id => $v->param('job_id'),
      poll_time => $self->_default_poll_time,
    }
  );
}

sub request_osm($self) {
  my $v = $self->validation;
  $v->required('codigo_ibge', 'trim')->is_ibge_code;

  return $self->bad_req if $self->any_error;

  my $job_id = $self->get_osm($v->param('codigo_ibge'));

  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");

  $self->render(
    status => 202,
    json => {task => 'query_osm', job_id => $job_id},
  );
}

# ---------------------------------------------------------------------------
# POST /api/task/cluster
#
# Enfileira uma clusterização (R::Pipe ou Plumber/edumapsr via
# analytics_engine) na fila dedicada 'analytics' (worker analítico separado do
# worker geral, que roda Siope/OSM). Retorna 202 + Location para polling.
# ---------------------------------------------------------------------------

sub request_cluster($self) {
  my $v = $self->validation;
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->required('id_column',  'trim')->like(qr/^\w+$/);
  $v->optional('schema',     'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('algorithm',  'trim')->in(qw(kmeans dbscan gmm spectral));
  $v->optional('clusters',   'trim')->num;
  $v->optional('eps',        'trim')->num;
  $v->optional('min_pts',    'trim')->num;
  $v->optional('features');

  return $self->bad_req if $self->any_error;

  my %args;
  $args{table_name} = $v->param('table_name');
  $args{id_column}  = $v->param('id_column');
  $args{schema}     = $v->param('schema') if $v->param('schema');
  $args{algorithm}  = $v->param('algorithm') if $v->param('algorithm');
  $args{clusters}   = $v->param('clusters')  if defined $v->param('clusters');
  $args{eps}        = $v->param('eps')       if defined $v->param('eps');
  $args{min_pts}    = $v->param('min_pts')   if defined $v->param('min_pts');
  $args{features}   = $v->param('features')  if $v->param('features');

  my $job_id = $self->app->minion->enqueue(
    clusterization => [\%args] => { queue => 'analytics' }
  );

  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");
  $self->render(status => 202, json => {task => 'cluster', job_id => $job_id});
}

# ---------------------------------------------------------------------------
# POST /api/task/summary
#
# Enfileira o resumo da cidade (city_analytics) na fila 'analytics'. Retorna
# 202 + Location. Não usa apply_city_analytics (que enfileira na fila
# 'speculative' com CHI cache) — enfileira diretamente, para o user intent.
# ---------------------------------------------------------------------------

sub request_summary($self) {
  my $v = $self->validation;
  $v->required('codigo_ibge', 'trim')->like(qr/^\d{7}$/);
  $v->optional('analysis', 'trim')->in(qw(full_summary score_distribution school_clusters));
  $v->optional('schema',   'trim')->like(qr/^[a-zA-Z]\w+$/);

  return $self->bad_req if $self->any_error;

  my %args;
  $args{codigo_ibge} = $v->param('codigo_ibge');
  $args{analysis}    = $v->param('analysis') if $v->param('analysis');
  $args{schema}      = $v->param('schema')   if $v->param('schema');

  my $job_id = $self->app->minion->enqueue(
    city_analytics => [\%args] => { queue => 'analytics' }
  );

  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");
  $self->render(status => 202, json => {task => 'summary', job_id => $job_id});
}

# ---------------------------------------------------------------------------
# POST /api/task/similarity
#
# Enfileira a similaridade (R::Pipe ou Plumber/edumapsr via analytics_engine)
# na fila dedicada 'analytics'. Retorna 202 + Location.
# ---------------------------------------------------------------------------

sub request_similarity($self) {
  my $v = $self->validation;
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->required('id_column',  'trim')->like(qr/^\w+$/);
  $v->optional('schema',     'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('metric',     'trim')->in(qw(gower euclidean_zscore mahalanobis aitchison dtw));

  return $self->bad_req if $self->any_error;

  my %args;
  $args{table_name} = $v->param('table_name');
  $args{id_column}  = $v->param('id_column');
  $args{schema}     = $v->param('schema') if $v->param('schema');
  $args{metric}     = $v->param('metric') if $v->param('metric');

  my $job_id = $self->app->minion->enqueue(
    similarity => [\%args] => { queue => 'analytics' }
  );

  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");
  $self->render(status => 202, json => {task => 'similarity', job_id => $job_id});
}

1;
