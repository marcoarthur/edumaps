package EduMaps::Model::Cluster;

use Mojo::Base "EduMaps::Model::Base", -signatures;
use Role::Tiny::With;
use utf8;

has rs => 'CensoEscolas';

=pod

=head1 NAME

EduMaps::Model::Cluster - Consultas de leitura sobre resultados de clusterização

=head1 DESCRIPTION

Fornece a leitura GeoJSON das escolas agrupadas por um job de clusterização
(Task::Clustering + motor R/edumapsr). O campo C<cluster_id> é gravado
dinamicamente em C<clean.school_indicators> (tabela denormalizada de
indicadores, populada pelo job para o ano escolhido) pelo motor R
(ALTER TABLE ADD COLUMN + UPDATE), por isso aqui a consulta é feita com SQL
puro em vez do source DBIC.

=head1 METHODS

=head2 clustered_schools

    my $feature_collection = $model->clustered_schools({
      codigo_regiao => '1',
      codigo_uf     => '35',
      codigo_ibge   => '3550308',
    });

Recorte geotag opcional (região, UF e município — pode combinar qualquer
subconjunto). Retorna a string GeoJSON FeatureCollection das escolas com
C<cluster_id> preenchido; C<undef> se a coluna ainda não existir (nenhum job
rodou) ou se o recorte não tiver resultados.

=cut

sub clustered_schools($self, $params = {}) {
  my @where = ('cluster_id IS NOT NULL');
  my @binds;
  for my $pair ([co_regiao => $params->{codigo_regiao}],
                [co_uf     => $params->{codigo_uf}],
                [co_municipio => $params->{codigo_ibge}]) {
    my ($col, $val) = @$pair;
    next unless defined $val && length $val;
    push @where, "$col = ?";
    push @binds, $val;
  }

  my $sql = $self->cluster_geojson_query;
  $sql =~ s/__WHERE__/join(' AND ', @where)/e;

  my $dbh = eval { $self->schema->storage->dbh } || return undef;
  my $col_exists = eval {
    $dbh->selectall_arrayref(
      "SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'clean'
           AND table_name = 'school_indicators'
           AND column_name = 'cluster_id'",
    );
  } || [];
  return undef unless @$col_exists;

  my $row = eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute(@binds);
    $sth->fetchrow_arrayref;
  };
  return undef unless $row;

  my $feature = eval { $self->json->utf8(0)->decode($row->[0]) };
  return undef unless $feature;
  return undef unless $feature->{features} && ref $feature->{features} eq 'ARRAY' && @{ $feature->{features} };
  return $row->[0];
}

sub cluster_geojson_query($self) {
  return <<~'EOSQL';
  SELECT json_build_object(
    'type', 'FeatureCollection',
    'features', COALESCE(json_agg(json_build_object(
      'type', 'Feature',
      'geometry',
        COALESCE(
          ST_AsGeoJSON(geometry)::json,
          ST_AsGeoJSON(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326))::json
        ),
      'properties', json_build_object(
        'co_entidade', co_entidade,
        'no_entidade', no_entidade,
        'cluster_id', cluster_id,
        'latitude', latitude,
        'longitude', longitude
      )
    )) FILTER (WHERE geometry IS NOT NULL OR (
      latitude IS NOT NULL AND longitude IS NOT NULL
    )), '[]'::json)
  ) AS feature
  FROM clean.school_indicators
  WHERE __WHERE__
  EOSQL
}

# ---------------------------------------------------------------------------
# Cascata de seleção de geotag (região → UF → município), alimentada pelos
# valores distintos presentes em clean.censo_escolas.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Catálogo de features e anos disponíveis para clusterização. As features são
# as colunas de clean.school_indicators (tabela denormalizada populada pelo
# job), com o comment vindo do metadado (col_description) — usado no
# autocomplete do frontend. table_name indica a origem do indicador.
# ---------------------------------------------------------------------------

sub columns($self) {
  my $dbh = eval { $self->schema->storage->dbh } || return [];
  my $rows = eval {
    $dbh->selectall_arrayref(<<~'EOSQL', { Slice => {} });
      SELECT c.column_name,
             c.data_type,
             COALESCE(
               col_description('clean.school_indicators'::regclass, c.ordinal_position),
               ''
             ) AS comment,
             CASE
               WHEN c.column_name IN (
                 'prop_licenciatura', 'prop_mestrado', 'prop_doutorado',
                 'prop_efetivos', 'prop_sem_especializacao', 'qt_doc_bas'
               ) THEN 'censo_docentes'
               WHEN c.column_name IN (
                 'ano_ideb', 'nota_media', 'nota_matematica', 'nota_portugues',
                 'ideb_observado', 'aprovacao_si_4'
               ) THEN 'ideb_notas_escolas'
               ELSE 'censo_escolas'
             END AS table_name
      FROM information_schema.columns c
      WHERE c.table_schema = 'clean'
        AND c.table_name = 'school_indicators'
      ORDER BY c.ordinal_position
    EOSQL
  };
  return [] unless $rows;
  return $rows;
}

sub years($self) {
  my $dbh = eval { $self->schema->storage->dbh } || return [];
  my $rows = eval {
    $dbh->selectall_arrayref(
      'SELECT DISTINCT ano FROM clean.ideb_notas_escolas ORDER BY ano DESC',
      { Slice => {} },
    );
  };
  return [] unless $rows;
  return $rows;
}

# ---------------------------------------------------------------------------
# Cascata de seleção de geotag (região → UF → município), alimentada pelos
# valores distintos presentes em clean.censo_escolas.
# ---------------------------------------------------------------------------

sub regions($self) {
  my $rs = $self->dbic;
  return $rs->search_rs(undef, {
    select   => [ 'co_regiao', 'no_regiao' ],
    as       => [ 'co_regiao', 'no_regiao' ],
    distinct => 1,
    order_by => [ 'co_regiao' ],
  })->as_hash->get_all;
}

sub ufs($self, $params = {}) {
  my $rs = $self->dbic;
  my $search = $params->{codigo_regiao} ? { co_regiao => $params->{codigo_regiao} } : undef;
  return $rs->search_rs($search, {
    select   => [ 'co_uf', 'sg_uf', 'no_uf' ],
    as       => [ 'co_uf', 'sg_uf', 'no_uf' ],
    distinct => 1,
    order_by => [ 'co_uf' ],
  })->as_hash->get_all;
}

sub municipalities($self, $params = {}) {
  my $rs = $self->dbic;
  my $search = $params->{codigo_uf} ? { co_uf => $params->{codigo_uf} } : undef;
  return $rs->search_rs($search, {
    select   => [ 'co_municipio', 'no_municipio' ],
    as       => [ 'co_municipio', 'no_municipio' ],
    distinct => 1,
    order_by => [ 'no_municipio' ],
  })->as_hash->get_all;
}

1;