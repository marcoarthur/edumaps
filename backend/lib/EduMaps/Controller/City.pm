package EduMaps::Controller::City;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use DateTime;
use utf8;
use Mojo::Util ();
use EduMaps::BaseAnalise ();   # #601: a lista do piso

has default_date => sub { DateTime->new( month => 6, year => 2025 ) };
has min_search_len => 4;
has default_limit => 10;

sub details ($self) {
  my $cod_ibge = $self->param('codigo_ibge');
  my $model    = $self->instantiate_model(model => 'City');
  my $details  = $model->details($cod_ibge);

  return $self->reply->not_found unless keys %$details;

  # Dispara o evento no EventBus da aplicação
  if ($self->app->event_bus) {
    $self->app->event_bus->emit(
      'city.details.requested',
      {
        codigo_ibge => $cod_ibge,
        year        => $self->param('year') // 2025,
      }, source => __PACKAGE__
    );
  }

  $self->render(json => $details);
}

sub schools($self) {
  my $cod = $self->param('codigo_ibge');
  my $model = $self->instantiate_model(model => 'City');
  my $schools = $self->instantiate_model(model => 'City')->find_schools($cod);

  return $self->reply->not_found unless $schools;
  $self->render(text => $schools, format => 'json');
}

sub osm_features($self) {
  my $cod = $self->param('codigo_ibge');
  my $model = $self->instantiate_model(model => 'City'); 

  $self->render(
    text => $model->osm_features($cod),
    format => 'json',
  );
}

sub payroll($self) {
  my $v = $self->validation;
  $v->optional('month')->like(qr/^\d+$/);
  $v->optional('year')->like(qr/^\d+$/);

  return $self->bad_req if $self->any_error;

  my $date = eval {
    DateTime->new( 
      year    => $v->param('year') // $self->default_date->year,
      month   => $v->param('month') // $self->default_date->month,
      locale  => 'pt',
    );
  };
  return $self->bad_req if $@;

  my $model = $self->instantiate_model(model => 'City');
  my $result = $model->payroll($v->param('codigo_ibge'), $date);
  $self->render(json => $result->to_array);
}

sub overall_payroll($self) {
  my $model = $self->instantiate_model(model => 'City', route_params => [qw(codigo_ibge)]);

  # #554: o modelo devolve o JSON já em bytes UTF-8; com `text` o Mojo
  # codificava de novo, e "São Paulo" saía "SÃ£o Paulo".
  $self->render(
    data => $model->overall_payroll,
    format => 'json'
  );
}

sub payroll_details($self) {

  my $model = $self->instantiate_model(model => 'City');
  my $v = $self->validation;
  $v->optional('month')->like(qr/^\d+$/);
  $v->optional('year')->like(qr/^\d+$/);

  return $self->bad_req if $self->any_error;

  my $date = eval {
    DateTime->new( 
      year    => $v->param('year') // $self->default_date->year,
      month   => $v->param('month') // $self->default_date->month,
      locale  => 'pt',
    );
  };
  return $self->bad_req if $@;

  $self->render(
    text => $model->payroll_details($self->param('codigo_ibge'), $date),
    format => 'json',
  );

}

# #601 (QC-01 da P2): quem fica abaixo do piso no ano na rede municipal,
# uma linha por pessoa (regra da contagem do painel). ?ano=AAAA (padrão: o
# último ano com folha do município); ?formato=csv baixa o arquivo. Pública,
# pela mesma decisão da folha por escola (só o CPF mascarado do SIOPE).
sub piso ($self) {
  my $v = $self->validation;
  $v->optional('ano', 'trim')->like(qr/^\d{4}$/);
  $v->optional('formato', 'trim')->in(qw(json csv));
  return $self->render(json => { error => 'Parâmetros inválidos' }, status => 400) if $v->has_error;
  my $ibge = $self->param('codigo_ibge');
  my $cod6 = substr($ibge, 0, 6);
  my $dbh  = $self->app->schema->storage->dbh;
  my $ano  = $v->param('ano') // $dbh->selectrow_array(
    'SELECT max(ano) FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $cod6);
  return $self->render(json => { error => 'Sem folha do município' }, status => 404) unless $ano;
  my $l = EduMaps::BaseAnalise->abaixo_piso_lista($dbh, $cod6, $ano);
  return $self->render(json => { error => $l->{erro} }, status => 404) if $l->{erro};
  my ($nome, $uf) = $dbh->selectrow_array(
    'SELECT no_municipio, sg_uf FROM clean.censo_escolas WHERE co_municipio::text = ? ORDER BY nu_ano_censo DESC LIMIT 1', {}, $ibge);
  if (($v->param('formato') // 'json') eq 'csv') {
    $self->res->headers->content_type('text/csv; charset=utf-8');
    $self->res->headers->content_disposition(qq{attachment; filename="abaixo-piso-$ibge-$ano.csv"});
    return $self->render(data => Mojo::Util::encode('UTF-8', EduMaps::BaseAnalise->abaixo_piso_csv($l)));
  }
  $self->render(json => {
    codigo_ibge => $ibge, municipio => $nome, uf => $uf, ano => 0 + $ano, %$l,
    colunas => [ map { { nome => $_->[0], descricao => $_->[1] } } @EduMaps::BaseAnalise::PISO_LISTA_COLUNAS ],
  });
}

# #614 (QF-01 da P2): o painel financeiro da rede municipal aberto pelo
# município, o mesmo do painel da rede de uma escola sem folha própria.
# Município sem folha carregada → 404; ano sem folha → 400 com os anos.
sub finance ($self) {
  my $v = $self->validation;
  $v->optional('ano', 'trim')->like(qr/^\d{4}$/);
  return $self->bad_req if $self->any_error;
  my $ibge  = $self->param('codigo_ibge');
  my $model = $self->instantiate_model(model => 'School');
  return $self->render(json => { error => 'Sem folha do SIOPE carregada para a rede municipal deste município' }, status => 404)
    unless @{ $model->rede_anos($ibge) };
  my $r = $model->financial_summary({
    codigo_ibge => $ibge,
    (defined $v->param('ano') ? (ano => 0 + $v->param('ano')) : ()),
  });
  return $self->render(json => { error => 'Sem folha neste ano', anos => $r->{anos} }, status => 400)
    if ($r->{error} // '') eq 'ano_sem_folha';
  $self->render(json => $r);
}

sub finance_anos ($self) {
  my $model = $self->instantiate_model(model => 'School');
  $self->render(json => { codigo_ibge => $self->param('codigo_ibge'), anos => $model->rede_anos($self->param('codigo_ibge')) });
}

sub payroll_rede ($self) {
  my $v = $self->validation;
  $v->optional('date', 'trim')->like(qr<^\d{2}-\d{4}$>);
  return $self->bad_req if $self->any_error;
  my $model  = $self->instantiate_model(model => 'School');
  my $result = $model->rede_payroll({ codigo_ibge => $self->param('codigo_ibge'), date => $v->param('date') // '10-2025' });
  return $self->render(json => { error => 'Sem folha da rede municipal neste mês' }, status => 404)
    unless $result->size > 0;
  $self->render(json => $result);
}

sub search_by_name($self) {
  my $model = $self->instantiate_model(model => 'City', route_params => [qw(name)]);
  my $opts = {name => $self->param('name')};

  if (length($opts->{name}) < $self->min_search_len ) {
    return $self->bad_req('name have to be greater than ' . $self->min_search_len);
  }

  $self->render(
    text => $model->search_by_name($opts),
    format => 'json',
  );
}

sub detail_by_name($self) {
  my $model = $self->instantiate_model(model => 'City');
  my $opts = {name => $self->param('name')};

  if (length($opts->{name}) < $self->min_search_len ) {
    return $self->bad_req('name have to be greater than ' . $self->min_search_len);
  }

  $self->render(
    text => $model->city_details($opts),
    format => 'json',
  );
}

sub analytic_details($self) {
  my $model = $self->instantiate_model(
    model => 'City', route_params => [qw(codigo_ibge)]
  );

  my $results = $model->analytic_details;
  if ( $results ) {
    $self->render(json => $results);
  } else {
    $self->render(text => 'Not found', status => 404);
  }
}

sub search_for_complete($self) {
  my $v = $self->validation;
  $v->required('q', 'trim')->like(qr/^[\w\sÀ-ÿ',.\-]+$/u);
  $v->optional('limit')->num(1, 100);

  return $self->bad_req if $self->any_error;

  my $model = $self->instantiate_model(model => 'City');

  $self->render(
    data => $model->search_for_complete, format => 'json'
  );
}

sub search_analytic($self) {
  my $v = $self->validation;
  $v->required('term','not_empty')->like(qr/^[\w\s]+$/);
  $v->optional('limit')->num;

  return $self->bad_req if $self->any_error;

  my $model = $self->instantiate_model(model => 'City');
  my $result = $model->search_analytic(
    {
      term => $self->param('term'),
      limit => $self->param('limit') || $self->default_limit
    }
  );

  $self->render(text => $result, format => 'json');
}

sub similar_cities($self) {
  my $v = $self->validation;
  $v->required('codigo_ibge')->is_ibge_code;
  $v->optional('limit')->num(1,100);
  $v->optional('similarity')->is_between(0,1);

  return $self->bad_req if $self->any_error;

  my $model = $self->instantiate_model(model => 'City');
  my $result = $model->similar_cities(
    { 
      codigo_ibge => $v->param('codigo_ibge'),
      limit => $v->param('limit') || $self->default_limit,
      similarity => $v->param('similarity'),
    }
  );

  $self->render( json => $result->to_array );
}

sub search_suggestions($self) {
  my $v = $self->validation;

  $v->required($_, 'trim')->like(qr/.{3,100}/) for qw/q/;
  $v->optional('limit', 'trim')->num(1,50);

  return $self->bad_req if $self->any_error;

  my $model = $self->instantiate_model(model => 'City');
  my $params = {
    nome_municipio => $self->param('q'), limit => $self->param('limit') // 50
  };
  my $result = $model->suggests($params);
  return $self->render( json => $result );
}

1;

__END__

=head1 NAME

EduMaps::Controller::City - API de dados municipais

=head1 DESCRIPTION

Controlador para endpoints da API de cidades, fornecendo informações
geoespaciais, educacionais e demográficas de municípios brasileiros.

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=cut
