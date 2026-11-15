package EduMaps::Controller::Cluster;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use EduMaps::Presets;
use Mojo::Util ();
use utf8;

sub presets($self) {
  $self->render(json => EduMaps::Presets->presets);
}

sub columns($self) {
  my $result = $self->instantiate_model(model => 'Cluster')->columns;
  return $self->render(json => { error => 'Sem colunas de indicadores disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub years($self) {
  my $result = $self->instantiate_model(model => 'Cluster')->years;
  return $self->render(json => { error => 'Sem anos IDEB disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub summary($self) {
  my $result = $self->instantiate_model(model => 'Cluster')->cluster_summary;
  return $self->render(json => { error => 'Nenhum cluster gerado ainda' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub schools($self) {
  my $v = $self->validation;
  $v->optional('codigo_regiao', 'trim')->num(1, 5);
  $v->optional('codigo_uf',     'trim')->like(qr/^\d{2}$/);
  $v->optional('codigo_ibge',   'trim')->like(qr/^\d{7}$/);
  return $self->bad_req if $self->any_error;

  my $params = {
    codigo_regiao => $self->param('codigo_regiao'),
    codigo_uf     => $self->param('codigo_uf'),
    codigo_ibge   => $self->param('codigo_ibge'),
  };

  my $result = $self->instantiate_model(model => 'Cluster')->clustered_schools($params);

  return $self->render(
    json => { error => "Nenhuma escola com cluster gerado para o recorte informado." },
    status => 404,
  ) unless $result;

  $self->render(text => $result, format => 'json');
}

# Execuções guardadas (#427) -------------------------------------------------

my $RUN_ID = qr/^run_\d+(?:_[0-9a-f]{4,16})?$/;

sub _execucao_ou_404($self) {
  my $run_id = $self->param('run_id') // '';
  unless ($run_id =~ $RUN_ID) {
    $self->render(json => { error => 'Execução inválida' }, status => 404);
    return;
  }
  my $exec = $self->instantiate_model(model => 'Cluster')->execucao($run_id);
  unless ($exec) {
    $self->render(json => { error => 'Execução não encontrada ou vencida (as execuções valem 90 dias).' }, status => 404);
    return;
  }
  return $exec;
}

sub execucao($self) {
  my $exec = $self->_execucao_ou_404 or return;
  $self->render(json => $exec);
}

sub execucao_escolas($self) {
  my $exec = $self->_execucao_ou_404 or return;
  my $geojson = $self->instantiate_model(model => 'Cluster')->escolas_execucao_geojson($exec->{run_id});
  $self->render(text => $geojson // '{"type":"FeatureCollection","features":[]}', format => 'json');
}

sub execucao_csv($self) {
  my $exec = $self->_execucao_ou_404 or return;
  my $features = $exec->{parametros}{features} // [];
  $features = [] unless ref $features eq 'ARRAY';
  my $linhas = $self->instantiate_model(model => 'Cluster')->linhas_execucao($exec->{run_id}, $features);

  my $q = sub ($v) {
    return '' unless defined $v;
    $v = "$v";
    return $v =~ /[";\n\r]/ ? '"' . ($v =~ s/"/""/gr) . '"' : $v;
  };
  # Separador ';' e BOM: abre direto no Excel em PT-BR (vírgula é decimal).
  my @cab = (qw(inep escola municipio uf rede grupo rotulo), @$features);
  my @out = (join ';', map { $q->($_) } @cab);
  for my $r (@$linhas) {
    push @out, join ';', map { $q->($_) } (
      $r->{co_entidade}, $r->{no_entidade}, $r->{no_municipio}, $r->{sg_uf}, $r->{rede},
      $r->{cluster_id}, $r->{cluster_label},
      map { defined $_ ? (sprintf('%.6g', $_) =~ s/\./,/r) : undef } @{ $r->{valores} },
    );
  }

  my $nome = "agrupamento-$exec->{run_id}.csv";
  $self->res->headers->content_type('text/csv; charset=utf-8');
  $self->res->headers->content_disposition(qq{attachment; filename="$nome"});
  $self->render(data => Mojo::Util::encode('UTF-8', "\x{FEFF}" . join("\r\n", @out) . "\r\n"));
}

sub regions($self) {
  my $result = $self->instantiate_model(model => 'Cluster')->regions;
  return $self->render(json => { error => 'Sem regiões disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub ufs($self) {
  my $v = $self->validation;
  $v->optional('codigo_regiao', 'trim')->num(1, 5);
  return $self->bad_req if $self->any_error;

  my $result = $self->instantiate_model(model => 'Cluster')->ufs({
    codigo_regiao => $self->param('codigo_regiao'),
  });
  return $self->render(json => { error => 'Sem UFs disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub municipalities($self) {
  my $v = $self->validation;
  $v->optional('codigo_uf', 'trim')->like(qr/^\d{2}$/);
  return $self->bad_req if $self->any_error;

  my $result = $self->instantiate_model(model => 'Cluster')->municipalities({
    codigo_uf => $self->param('codigo_uf'),
  });
  return $self->render(json => { error => 'Sem municípios disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

1;