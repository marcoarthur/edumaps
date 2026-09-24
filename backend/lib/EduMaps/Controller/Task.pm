package EduMaps::Controller::Task;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use EduMaps::Presets;
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

  my $job_id = $v->param('job_id');

  # Cliente REST (polling simples — ex.: frontend Svelte /cluster/geotag)
  # espera um JSON de estado a cada GET. O EventSource (SSE) envia o header
  # `Accept: text/event-stream`; sem ele, respondemos o snapshot do job.
  if (($self->req->headers->accept // '') !~ m{text/event-stream}i) {
    my $info = $self->minion->job($job_id);
    return $self->render(json => {error => 'job_not_found'}, status => 404) unless $info;

    my $job = $info->info;
    my %resp = (state => $job->{state});
    if ($job->{state} eq 'failed') {
      my $err = $job->{error} // $job->{result};
      $resp{error} = ref $err eq 'HASH' ? ($err->{error} // Mojo::JSON::encode_json($err)) : "$err";
    }
    return $self->render(json => \%resp);
  }

  $self->render_later;
  $self->monitor_job(
    {
      job_id => $job_id,
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
  # O frontend envia o payload como application/json (features é um array de
  # colunas), mas os testes/CLI usam form-urlencoded. O Mojolicious não mescla
  # corpo JSON nos params da validação automaticamente, então normalizamos a
  # entrada aqui: JSON ganha preferência, form entra como antes.
  my $is_json = ($self->req->headers->content_type // '') =~ m{^application/json};
  my $input = $is_json ? $self->req->json : $self->req->params->to_hash;
  $input ||= {};

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->required('id_column',  'trim')->like(qr/^\w+$/);
  $v->optional('schema',     'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('algorithm',  'trim')->in(qw(kmeans dbscan gmm spectral));
  $v->optional('clusters',   'trim')->num;
  $v->optional('eps',        'trim')->num;
  $v->optional('min_pts',    'trim')->num;
  $v->optional('features');
  $v->optional('preset',     'trim')->like(qr/^[a-zA-Z_]+$/);
  $v->optional('ano_ideb',   'trim')->like(qr/^\d{4}$/);

  # Filtro por geotag (opcional): região (1-5), UF (2 dígitos) e município
  # (7 dígitos). Convertidos em `filter` para o motor R.
  $v->optional('codigo_regiao', 'trim')->num(1, 5);
  $v->optional('codigo_uf',     'trim')->like(qr/^\d{2}$/);
  $v->optional('codigo_ibge',   'trim')->like(qr/^\d{7}$/);

  if ($v->has_error) {
    $self->app->log->debug(
      "Validation errors: " . join(', ', map { "$_: " . join(', ', @{$v->error($_)}) } $v->failed->@*)
    );
  }
  return $self->bad_req if $v->has_error;

  # Preset curado de indicadores: resolve as features/fonte automaticamente.
  # Presets com year_filter (ex.: desempenho) exigem o ano IDEB/SAEB.
  # A janela de features/ano é validada de novo no job (rebuild da tabela).
  my $preset_id = $v->param('preset');
  my $preset;
  if (defined $preset_id && length $preset_id) {
    $preset = EduMaps::Presets->get($preset_id);
    return $self->bad_req("preset '$preset_id' desconhecido") unless $preset;
    if ($preset->{year_filter} && !defined $v->param('ano_ideb')) {
      return $self->bad_req("preset '$preset_id' exige ano_ideb");
    }
  }

  my %args;
  if ($preset) {
    # A clusterização multi-tabela roda sempre sobre a tabela denormalizada
    # clean.school_indicators (preenchida pelo job para o ano escolhido).
    $args{schema}     = 'clean';
    $args{table_name} = EduMaps::Presets->INDICATORS_TABLE;
    $args{id_column}  = 'co_entidade';
    $args{preset_id}  = $preset->{id};
    # features: os do preset, salvo se o usuário passou a própria lista.
    $args{features} //= $preset->{features};
    # Metadados de rótulo semântico (conceito + polaridade das features),
    # consumidos pelo motor R para descrever os clusters em linguagem natural.
    $args{labeling} = {
      concept    => $preset->{concept},
      gender     => $preset->{gender},
      directions => $preset->{directions},
    } if $preset->{concept};
  } else {
    $args{table_name} = $v->param('table_name');
    $args{id_column}  = $v->param('id_column');
    $args{schema}     = $v->param('schema') if $v->param('schema');
  }
  $args{ano_ideb}  = 0 + $v->param('ano_ideb') if defined $v->param('ano_ideb');
  $args{algorithm} = $v->param('algorithm') if $v->param('algorithm');
  $args{clusters}  = $v->param('clusters')  if defined $v->param('clusters');
  $args{eps}       = $v->param('eps')       if defined $v->param('eps');
  $args{min_pts}   = $v->param('min_pts')   if defined $v->param('min_pts');
  # features é um array de colunas no JSON; param('features') colapsaria para a
  # última coluna, então lemos direto do input e repassamos o array íntegro.
  $args{features} = $input->{features} if defined $input->{features};

  # Mapeamento geotag -> colunas da clean.censo_escolas (fonte padrão do
  # pipeline). Só entra no filter se informado pelo usuário.
  my %filter;
  $filter{co_regiao}    = 0 + $v->param('codigo_regiao') if $v->param('codigo_regiao');
  $filter{co_uf}        = 0 + $v->param('codigo_uf')     if $v->param('codigo_uf');
  $filter{co_municipio} = 0 + $v->param('codigo_ibge')   if $v->param('codigo_ibge');
  $args{filter} = \%filter if %filter;

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

  my $analysis = $v->param('analysis') // 'full_summary';
  if ($analysis ne 'full_summary') {
    return $self->render(
      json  => { error => "Sub-análise '$analysis' não suportada: o motor R ainda não persiste esse recorte. Use 'full_summary'." },
      status => 400,
    );
  }

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
