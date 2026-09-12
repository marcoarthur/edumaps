package EduMaps::Roles::Business::School::Searching;
use Mojo::Base -role, -signatures;
use Carp qw(croak);

requires qw(schema default_limit);

# substitui default_columns para CensoEscolas
has censo_columns => sub {
  my $end_expr =<<~'EOE';
  concat_ws(', ',
      NULLIF(ds_endereco, ''),
      NULLIF(nu_endereco, ''),
      NULLIF(ds_complemento, ''),
      NULLIF(no_bairro, ''),
      concat_ws(' - ',
          NULLIF(no_municipio, ''),
          NULLIF(sg_uf, '')
      ),
      NULLIF(co_cep, '')
  ) AS endereco_completo
  EOE

  my $tel_expr =<<~'EOE';
  concat_ws(' ',
      CASE
          WHEN nu_ddd IS NOT NULL THEN '(' || nu_ddd || ')'
      END,
      NULLIF(trim(nu_telefone), '')
  ) AS telefone
  EOE

  my $zap_expr =<<~'EOE';
  CASE
      WHEN nu_ddd IS NOT NULL
       AND NULLIF(trim(nu_telefone), '') IS NOT NULL
      THEN concat(
          'https://wa.me/55',
          nu_ddd,
          regexp_replace(nu_telefone, '\D', '', 'g')
      )
  END AS whatsapp
  EOE

  my $osm_expr =<<~'EOE';
  'https://www.openstreetmap.org/?mlat=' || latitude || 
  '&mlon=' || longitude ||'&zoom=18#map=18/' || latitude || '/' || longitude
  EOE

  my $tipo_expr =<<~'EOE';
  CASE tp_dependencia
      WHEN 1 THEN 'Federal'
      WHEN 2 THEN 'Estadual'
      WHEN 3 THEN 'Municipal'
      WHEN 4 THEN 'Privada'
      ELSE 'Não informado'
  END AS tipo 
  EOE

  my $mod_expr =<<~'EOE';
  array_remove(ARRAY[
      CASE WHEN in_comum_creche              = 1 THEN 'Creche' END,
      CASE WHEN in_comum_pre                 = 1 THEN 'Pré-escola' END,
      CASE WHEN in_comum_fund_ai             = 1 THEN 'Fundamental AI' END,
      CASE WHEN in_comum_fund_af             = 1 THEN 'Fundamental AF' END,
      CASE WHEN in_comum_medio_medio         = 1 THEN 'Ensino Médio' END,
      CASE WHEN in_comum_medio_integrado     = 1 THEN 'Médio Integrado' END,
      CASE WHEN in_comum_medio_fic           = 1 THEN 'Médio FIC' END,
      CASE WHEN in_comum_medio_normal        = 1 THEN 'Magistério' END,
      CASE WHEN in_comum_eja_fund            = 1 THEN 'EJA Fundamental' END,
      CASE WHEN in_comum_eja_medio           = 1 THEN 'EJA Médio' END,
      CASE WHEN in_comum_eja_prof            = 1 THEN 'EJA Profissional' END,
      CASE WHEN in_comum_prof                = 1 THEN 'Educação Profissional' END,

      CASE WHEN in_esp_exclusiva_creche      = 1 THEN 'Creche (Especial)' END,
      CASE WHEN in_esp_exclusiva_pre         = 1 THEN 'Pré-escola (Especial)' END,
      CASE WHEN in_esp_exclusiva_fund_ai     = 1 THEN 'Fundamental AI (Especial)' END,
      CASE WHEN in_esp_exclusiva_fund_af     = 1 THEN 'Fundamental AF (Especial)' END,
      CASE WHEN in_esp_exclusiva_medio_medio = 1 THEN 'Ensino Médio (Especial)' END,
      CASE WHEN in_esp_exclusiva_medio_integr= 1 THEN 'Médio Integrado (Especial)' END,
      CASE WHEN in_esp_exclusiva_medio_fic   = 1 THEN 'Médio FIC (Especial)' END,
      CASE WHEN in_esp_exclusiva_medio_normal= 1 THEN 'Magistério (Especial)' END,
      CASE WHEN in_esp_exclusiva_eja_fund    = 1 THEN 'EJA Fundamental (Especial)' END,
      CASE WHEN in_esp_exclusiva_eja_medio   = 1 THEN 'EJA Médio (Especial)' END,
      CASE WHEN in_esp_exclusiva_eja_prof    = 1 THEN 'EJA Profissional (Especial)' END,
      CASE WHEN in_esp_exclusiva_prof        = 1 THEN 'Educação Profissional (Especial)' END
  ], NULL) AS etapas_ensino
  EOE

  return state $cols = [
    qw(latitude longitude),
    { escola => 'no_entidade' },
    { codigo_inep => 'co_entidade' },
    { endereco => \$end_expr },
    { telefone => \$tel_expr },
    { municipio => 'no_municipio' },
    { uf => 'no_uf' },
    { osm => \$osm_expr },
    { tipo => \$tipo_expr },
    { modalidades => \$mod_expr },
    { whatsapp => \$zap_expr },
  ];
};

sub search($self, $params = {}) {
  my $v = $self->validation;
  $v->input($params);
  $v->optional($_, 'trim')->like(qr/.{3,100}/) for qw/escola municipio/;
  $v->optional('limit', 'trim')->num(1,500);

  croak "Erro dos parametros" if $v->has_error;
  # wrap db operator and metachar
  my $clean = {};
  for (qw/escola municipio/) {
    if (my $value = $v->param($_)) {
      $clean->{$_} = { -ilike => "%$value%" };
    }
  }
  
  croak "Sem parâmetros válidos" if scalar(keys $params->%*) == 0;

  my $rs = $self->schema->resultset('Escolas');
  my $results = $rs->search_rs($clean)
  ->limit($v->param('limit') || $self->default_limit)
  ->columns($self->default_columns)
  ->as_hash->get_all;

  return $results;
}

sub search_pageable($self, $params) {
  my $rs = $self->schema->resultset('CensoEscolas');
  my $ilike = sub($val) { return { -ilike => "%$val%" } };

  my $search = {
    length($params->{escola})    > 2 ? (no_entidade => $ilike->($params->{escola})) : (),
    length($params->{municipio}) > 2 ? (no_municipio => $ilike->($params->{municipio})) : (),
    tp_situacao_funcionamento => 1,
  };

  my $results = $rs->search_rs($search)->columns($self->censo_columns)
  ->order_by('no_entidade')->as_hash
  ->page_size($params->{per_page})->set_page($params->{page})
  ->to_api_response;

  return $results;
}

sub suggests($self, $params = {}) {
  my $rs = $self->schema->resultset('CensoEscolas');
  my $v = $self->validation;

  $v->input($params);
  $v->required($_, 'trim')->like(qr/.{3,100}/) for qw/no_entidade/;
  $v->optional('limit', 'trim')->num(1,50);

  croak "Erro dos parametros" if $v->has_error;

  my $cols = [
    {id => 'co_entidade'}, { nome => 'no_entidade'}, {municipio => 'no_municipio'}
  ];
  my $limit = $params->{limit} // 50;
  delete $params->{limit};

  $params->{no_entidade} = {-ilike => "%$params->{no_entidade}%"};

  my $results = $rs->search_rs($params)->limit($limit)->columns($cols)
  ->order_by(['no_entidade', 'no_municipio'])->as_hash->get_all;

  return $results->to_array;
}

1;
