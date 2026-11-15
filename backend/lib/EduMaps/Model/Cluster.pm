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
        'cluster_label', cluster_label,
        'cluster_rank', cluster_rank,
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
# Resumo semântico por cluster (rótulo em linguagem natural + indicadores).
# Lê a execução mais recente registrada em analytics.clustering_metadata
# (run_id ordenado desc) para a tabela denormalizada. O rótulo/rank vêm do
# extra_metrics (JSON) gravado pelo motor R; os indicadores vêm do centroide
# (JSON) do cluster.
# ---------------------------------------------------------------------------

sub cluster_summary($self, $run_id = undef) {
  my $dbh = eval { $self->schema->storage->dbh } || return [];
  # Com run_id (#427), o resumo é o daquela execução; sem, o da mais recente
  # (comportamento antigo, mantido para quem ainda chama sem run_id).
  my $alvo = defined $run_id ? '?' : <<~'EOSQL';
    (SELECT run_id
       FROM analytics.clustering_metadata
      WHERE target_table = 'clean.school_indicators'
      ORDER BY run_id DESC
      LIMIT 1)
    EOSQL
  my $rows = eval {
    $dbh->selectall_arrayref(<<~"EOSQL", { Slice => {} }, (defined $run_id ? ($run_id) : ()));
      SELECT cluster_id::int   AS cluster_id,
             cluster_size::int AS cluster_size,
             is_noise::int     AS is_noise,
             centroids,
             extra_metrics
      FROM analytics.clustering_metadata
      WHERE run_id = $alvo
      ORDER BY cluster_id
      EOSQL
  };
  return [] unless $rows && @$rows;

  my $json = $self->json;
  my @summary;
  for my $row (@$rows) {
    # O banco já devolve strings utf8-flagged; usa utf8(0) (mesmo padrão de
    # clustered_schools/Clustering.pm) para decodificar sem re-encodar.
    my $indicators = eval { $json->utf8(0)->decode($row->{centroids} // '{}') } || {};
    $indicators = {} unless ref $indicators eq 'HASH';
    # extra_metrics é gravado pelo R como ARRAY de objetos ([{...}]), então
    # normalizamos para o hashref do cluster (primeiro elemento).
    my $extra = eval { $json->utf8(0)->decode($row->{extra_metrics} // '{}') } || {};
    $extra = $extra->[0] if ref $extra eq 'ARRAY' && @$extra;
    $extra = {} unless ref $extra eq 'HASH';
    push @summary, {
      cluster_id    => 0 + $row->{cluster_id},
      cluster_size  => 0 + $row->{cluster_size},
      is_noise      => $row->{is_noise} ? 1 : 0,
      cluster_label => $extra->{cluster_label} // ('Cluster ' . $row->{cluster_id}),
      cluster_rank  => $extra->{cluster_rank},
      indicators    => $indicators,
    };
  }
  return \@summary;
}

# ---------------------------------------------------------------------------
# Execuções guardadas (#427): cada agrupamento da tela tem um run_id, com
# recorte, parâmetros, universo, resumo, mapa e exportação próprios. Nome,
# município e coordenadas das escolas vêm do Censo mais recente; o grupo e
# os valores dos indicadores, da própria execução (citável).
# ---------------------------------------------------------------------------

sub execucao($self, $run_id) {
  my $dbh = eval { $self->schema->storage->dbh } || return undef;
  my $row = eval {
    $dbh->selectrow_hashref(<<~'EOSQL', undef, $run_id);
      SELECT run_id, job_id, estado, recorte::text AS recorte, parametros::text AS parametros,
             universo::text AS universo,
             to_char(criado_em AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD"T"HH24:MI:SS') AS criado_em,
             to_char(expira_em AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD') AS expira_em,
             (SELECT count(*)::int FROM analytics.cluster_atribuicoes a WHERE a.run_id = e.run_id) AS n_atribuicoes,
             (SELECT count(*)::int
                FROM analytics.cluster_atribuicoes a
                JOIN clean.censo_escolas c
                  ON c.co_entidade = a.co_entidade
                 AND c.nu_ano_censo = (SELECT max(nu_ano_censo) FROM clean.censo_escolas)
               WHERE a.run_id = e.run_id
                 AND (c.geometry IS NOT NULL OR (c.latitude IS NOT NULL AND c.longitude IS NOT NULL))
             ) AS n_no_mapa
        FROM analytics.cluster_execucoes e
       WHERE run_id = ? AND expira_em > now()
      EOSQL
  };
  return undef unless $row;

  my $json = $self->json->utf8(0);
  $row->{$_} = eval { $json->decode($row->{$_} // '{}') } || {} for qw(recorte parametros universo);
  $row->{resumo} = $self->cluster_summary($run_id);
  return $row;
}

sub escolas_execucao_geojson($self, $run_id) {
  my $dbh = eval { $self->schema->storage->dbh } || return undef;
  my ($geojson) = eval {
    $dbh->selectrow_array(<<~'EOSQL', undef, $run_id);
      SELECT json_build_object(
        'type', 'FeatureCollection',
        'features', COALESCE(json_agg(json_build_object(
          'type', 'Feature',
          'geometry', COALESCE(
            ST_AsGeoJSON(c.geometry)::json,
            ST_AsGeoJSON(ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4326))::json
          ),
          'properties', json_build_object(
            'co_entidade', a.co_entidade,
            'no_entidade', c.no_entidade,
            'cluster_id', a.cluster_id,
            'cluster_label', a.cluster_label,
            'cluster_rank', a.cluster_rank,
            'latitude', c.latitude,
            'longitude', c.longitude
          )
        )) FILTER (WHERE c.geometry IS NOT NULL OR (c.latitude IS NOT NULL AND c.longitude IS NOT NULL)),
        '[]'::json)
      )
      FROM analytics.cluster_atribuicoes a
      JOIN analytics.cluster_execucoes e ON e.run_id = a.run_id AND e.expira_em > now()
      LEFT JOIN clean.censo_escolas c
        ON c.co_entidade = a.co_entidade
       AND c.nu_ano_censo = (SELECT max(nu_ano_censo) FROM clean.censo_escolas)
      WHERE a.run_id = ?
      EOSQL
  };
  return $geojson;
}

# Linhas da exportação: uma por escola agrupada, com os indicadores usados
# na ordem dos parâmetros da execução.
sub linhas_execucao($self, $run_id, $features = []) {
  my $dbh = eval { $self->schema->storage->dbh } || return [];
  my $rows = eval {
    $dbh->selectall_arrayref(<<~'EOSQL', { Slice => {} }, $run_id);
      SELECT a.co_entidade, c.no_entidade, c.no_municipio, c.sg_uf,
             CASE c.tp_dependencia WHEN 1 THEN 'Federal' WHEN 2 THEN 'Estadual'
                                   WHEN 3 THEN 'Municipal' WHEN 4 THEN 'Privada' END AS rede,
             a.cluster_id, a.cluster_label, a.valores::text AS valores
        FROM analytics.cluster_atribuicoes a
        LEFT JOIN clean.censo_escolas c
          ON c.co_entidade = a.co_entidade
         AND c.nu_ano_censo = (SELECT max(nu_ano_censo) FROM clean.censo_escolas)
       WHERE a.run_id = ?
       ORDER BY a.cluster_id, c.no_entidade, a.co_entidade
      EOSQL
  } || [];
  my $json = $self->json->utf8(0);
  for my $r (@$rows) {
    my $v = eval { $json->decode(delete $r->{valores} // '{}') } || {};
    $r->{valores} = [ map { $v->{$_} } @$features ];
  }
  return $rows;
}

# Apaga as execuções vencidas (90 dias) e os metadados por grupo delas.
# As atribuições saem pela FK (ON DELETE CASCADE). Devolve quantas saíram.
sub limpar_execucoes_vencidas($self) {
  my $dbh = $self->schema->storage->dbh;
  # clustering_metadata é criada pelo motor R na primeira execução.
  my ($tem_meta) = $dbh->selectrow_array(
    q{SELECT to_regclass('analytics.clustering_metadata') IS NOT NULL});
  $dbh->do(<<~'EOSQL') if $tem_meta;
    DELETE FROM analytics.clustering_metadata m
     USING analytics.cluster_execucoes e
     WHERE m.run_id = e.run_id AND e.expira_em <= now()
    EOSQL
  return 0 + $dbh->do('DELETE FROM analytics.cluster_execucoes WHERE expira_em <= now()');
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