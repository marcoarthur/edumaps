package EduMaps::Roles::Business::Gestor::SimilarSchools;
use Mojo::Base -role, -signatures;
use utf8;

# Busca de escolas similares para o gestor. A similaridade é calculada por
# cosseno (pgvector, operador <=>) sobre um vetor de características montado
# na própria query: porte, localização (urbana/rural), condição
# socioeconômica (INSE) e etapas de ensino oferecidas (one-hot). O escopo
# limita a busca ao mesmo município, estado ou região (IBGE).

requires qw(schema);

our $DEFAULT_YEAR = 2025;

our @SCOPES = qw(municipio estado regiao);

# Ordinal do porte (0..1): mais matrículas => maior valor.
our @PORTE = (
  'Escola sem matrícula de escolarização',
  'Até 50 matrículas de escolarização',
  'Entre 51 e 200 matrículas de escolarização',
  'Entre 201 e 500 matrículas de escolarização',
  'Entre 501 e 1000 matrículas de escolarização',
  'Mais de 1000 matrículas de escolarização',
);

our @ETAPA_COLS = qw(
  in_comum_creche in_comum_pre in_comum_fund_ai in_comum_fund_af
  in_comum_medio_medio in_eja in_profissionalizante
);

our %ETAPA_LABEL = (
  in_comum_creche         => 'Creche',
  in_comum_pre            => 'Pré-escola',
  in_comum_fund_ai        => 'Fundamental (Anos Iniciais)',
  in_comum_fund_af        => 'Fundamental (Anos Finais)',
  in_comum_medio_medio    => 'Ensino Médio',
  in_eja                  => 'EJA',
  in_profissionalizante   => 'Educação Profissional',
);

# Vetor de características (10 dims): porte, localização, INSE, 7 etapas.
# CASE para o porte (ordinal) e INSE neutro quando o alvo não tem INSE.
our $FEATURE_VECTOR = <<~'SQL';
  ARRAY[
    CASE e.porte_escola
      WHEN 'Escola sem matrícula de escolarização' THEN 0.0
      WHEN 'Até 50 matrículas de escolarização' THEN 0.2
      WHEN 'Entre 51 e 200 matrículas de escolarização' THEN 0.4
      WHEN 'Entre 201 e 500 matrículas de escolarização' THEN 0.6
      WHEN 'Entre 501 e 1000 matrículas de escolarização' THEN 0.8
      WHEN 'Mais de 1000 matrículas de escolarização' THEN 1.0
      ELSE 0.5
    END,
    CASE ce.tp_localizacao WHEN 1 THEN 1 WHEN 2 THEN 0 ELSE 0.5 END,
    CASE WHEN ?::numeric IS NULL THEN 0 ELSE LEAST(COALESCE(i.media_inse, ?) / 10.0, 1) END,
    COALESCE(ce.in_comum_creche, 0),
    COALESCE(ce.in_comum_pre, 0),
    COALESCE(ce.in_comum_fund_ai, 0),
    COALESCE(ce.in_comum_fund_af, 0),
    COALESCE(ce.in_comum_medio_medio, 0),
    COALESCE(ce.in_eja, 0),
    COALESCE(ce.in_profissionalizante, 0)
  ]::vector
SQL

sub similar_schools ($self, $params = {}) {
  my $cod_inep = $params->{cod_inep} or return;

  my $scope = $params->{scope} // 'municipio';
  $scope = 'municipio' unless grep { $_ eq $scope } @SCOPES;

  my $limit = $params->{limit} // 10;
  $limit = ($limit =~ /\A\d+\z/) ? int($limit) : 10;
  $limit = 1 if $limit < 1;
  $limit = 50 if $limit > 50;

  my $censo = $self->_target_censo($cod_inep) or return;
  my $esc   = $self->_target_escola($cod_inep) || {};
  my $inse  = $self->_target_inse($cod_inep)   || {};

  my $scope_col = 'co_municipio';
  $scope_col = 'co_uf'      if $scope eq 'estado';
  $scope_col = 'co_regiao'  if $scope eq 'regiao';

  my $scope_value = $censo->{$scope_col} or return;

  my $porte_dim = $self->_porte_ordinal($esc->{porte_escola});
  my $tp_loc    = $censo->{tp_localizacao};
  my $loc_dim   = defined $tp_loc && $tp_loc == 1 ? 1 : defined $tp_loc && $tp_loc == 2 ? 0 : 0.5;
  my $inse_val  = $inse->{media_inse};
  my @flags     = map { $censo->{$_} // 0 } @ETAPA_COLS;

  my $target_vector = join(',', $porte_dim + 0, $loc_dim, ($inse_val // 0) / 10, @flags);

  my $sql = <<~"SQL";
    SELECT
      ce.co_entidade,
      COALESCE(e.escola, ce.no_entidade)             AS nome,
      COALESCE(e.municipio, ce.no_municipio)         AS municipio,
      COALESCE(e.uf, ce.sg_uf)                       AS uf,
      e.porte_escola,
      COALESCE(e.localizacao,
        CASE ce.tp_localizacao WHEN 1 THEN 'Urbana' WHEN 2 THEN 'Rural' END) AS localizacao,
      i.media_inse,
      e.latitude,
      e.longitude,
      COALESCE(ce.in_comum_creche, 0)        AS in_comum_creche,
      COALESCE(ce.in_comum_pre, 0)           AS in_comum_pre,
      COALESCE(ce.in_comum_fund_ai, 0)       AS in_comum_fund_ai,
      COALESCE(ce.in_comum_fund_af, 0)       AS in_comum_fund_af,
      COALESCE(ce.in_comum_medio_medio, 0)   AS in_comum_medio_medio,
      COALESCE(ce.in_eja, 0)                 AS in_eja,
      COALESCE(ce.in_profissionalizante, 0)  AS in_profissionalizante,
      (1 - ($FEATURE_VECTOR <=> ?::vector))  AS similarity
    FROM clean.censo_escolas ce
    LEFT JOIN clean.escolas e ON e.codigo_inep = ce.co_entidade
    LEFT JOIN clean.inse i    ON i.id_escola = ce.co_entidade
    WHERE ce.co_entidade <> ?
      AND ce.tp_situacao_funcionamento = 1
      AND ce.nu_ano_censo = ?
      AND ce.$scope_col = ?
    ORDER BY similarity DESC
    LIMIT ?
  SQL

  my @binds = (
    $inse_val,          # INSE do alvo (undef => dimensão neutra)
    $inse_val,
    "[$target_vector]",
    $cod_inep,
    $DEFAULT_YEAR,
    $scope_value,
    $limit,
  );

  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(
    sub ($me, $dbh) {
      $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
    }
  );

  my @similares = map {
    +{
      id_escola    => $_->{co_entidade} + 0,
      nome         => $_->{nome},
      municipio    => $_->{municipio},
      uf           => $_->{uf},
      porte_escola => $_->{porte_escola},
      localizacao  => $_->{localizacao},
      media_inse   => $self->_num($_->{media_inse}),
      etapas       => $self->_etapas($_),
      latitude     => $self->_num($_->{latitude}),
      longitude    => $self->_num($_->{longitude}),
      similarity   => $self->_num(sprintf('%.4f', $_->{similarity})),
    }
  } @{$rows // []};

  return {
    escola_alvo => {
      id_escola    => $cod_inep + 0,
      nome         => $censo->{no_entidade},
      municipio    => $esc->{municipio} // $censo->{no_municipio},
      uf           => $esc->{uf} // $censo->{sg_uf},
      porte_escola => $esc->{porte_escola},
      localizacao  => $esc->{localizacao}
        // ($censo->{tp_localizacao} == 1 ? 'Urbana' : $censo->{tp_localizacao} == 2 ? 'Rural' : undef),
      media_inse   => $self->_num($inse_val),
      latitude     => $self->_num($esc->{latitude}),
      longitude    => $self->_num($esc->{longitude}),
    },
    scope    => $scope,
    limit    => $limit,
    similares => \@similares,
  };
}

sub _target_censo ($self, $cod_inep) {
  my @cols = (
    qw(co_entidade co_municipio co_uf co_regiao no_entidade no_municipio sg_uf
       tp_localizacao tp_situacao_funcionamento),
    @ETAPA_COLS,
  );

  $self->schema->resultset('CensoEscolas')
    ->search_rs({ co_entidade => $cod_inep, nu_ano_censo => $DEFAULT_YEAR })
    ->columns(\@cols)
    ->as_hash->first;
}

sub _target_escola ($self, $cod_inep) {
  $self->schema->resultset('Escolas')
    ->search_rs({ codigo_inep => $cod_inep })
    ->as_hash->first;
}

sub _target_inse ($self, $cod_inep) {
  $self->schema->resultset('Inse')
    ->search_rs({ id_escola => $cod_inep })
    ->as_hash->first;
}

sub _porte_ordinal ($self, $porte) {
  for my $i (0 .. $#PORTE) {
    return $i / 5 if $porte eq $PORTE[$i];
  }
  return 0.5;
}

sub _etapas ($self, $row) {
  my @labels = map { $ETAPA_LABEL{$_} } grep { $row->{$_} ? 1 : 0 } @ETAPA_COLS;
  return join(', ', @labels) || 'Não informado';
}

sub _num ($self, $value) {
  return undef unless defined $value;
  return $value + 0;
}

1;