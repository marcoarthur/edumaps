package EduMaps::Model::OSM;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use EduMaps::Services::OSM;
use EduMaps::Services::OSM::Query;
use Mojo::JSON qw(decode_json encode_json);
use Time::Piece;
use utf8;

=head1 NAME

EduMaps::Model::OSM - Cache e relações do OSM com as entidades do EduMaps

=head1 DESCRIPTION

Usa o L<EduMaps::Services::OSM> para buscar feições do OpenStreetMap e
gerencia o cache em banco (C<clean.osm_query> / C<clean.osm_feature>) e a
relação dessas feições com as entidades do EduMaps:

  * C<osm_for_school>    - buffer (raio) ao redor da escola (censo_escolas);
  * C<osm_for_municipio> - polígono do município (municipios_sp).

O cache é indexado pelo digest da query (Overpass QL) e respeita um TTL
(C<cache_ttl_days>, default 30; 0 desliga a expiração). A relação com a
escola/município é validada no banco por C<ST_DWithin>/C<ST_Within>.

=cut

has rs => 'OsmFeature';
has service_class => 'EduMaps::Services::OSM';
has cache_ttl_days => sub { 30 };
has default_raio   => sub { 1000 };

# ---------------------------------------------------------------------------
# API principal
# ---------------------------------------------------------------------------

sub osm_for_school($self, %args) {
  my $co   = $args{co_entidade} // die 'Need co_entidade';
  my $raio = $args{raio} // $self->default_raio;

  my $school = $self->_load_school($co, $args{nu_ano_censo});
  die sprintf('Escola não encontrada no censo: %s', $co) unless $school;
  die sprintf('Escola sem coordenadas (latitude/longitude): %s', $co)
    unless defined $school->{latitude} && defined $school->{longitude};

  my $profiles = $args{profiles} // (exists $args{filters} ? [] : ['equipamentos_publicos']);

  $self->_emit_progress(5, 'Preparando consulta OSM');

  my $query = EduMaps::Services::OSM::Query->new(
    target => {
      type => 'around',
      lat  => 0 + $school->{latitude},
      lon  => 0 + $school->{longitude},
      raio => $raio,
    },
    (exists $args{profiles} ? (profiles => $args{profiles}) : ()),
    (exists $args{filters}  ? (filters  => $args{filters})  : ()),
    log => $self->log,
  );

  my $run = $self->_ensure_query(
    $query,
    city_fid => $school->{co_municipio},
    refresh  => $args{refresh},
  );

  my $related = $self->_relate_school(
    $co, $school->{nu_ano_censo}, $raio, $run->{digest}
  );

  # Sobrescreve a seleção atual (upsert) — raio/perfis/digest/atualizado_em.
  $self->record_selection(
    $co, $school->{nu_ano_censo}, $raio, $profiles, $run->{digest}
  );

  $self->_emit_progress(98, 'Concluindo');

  my $sel = $self->current_selection($co, $school->{nu_ano_censo});

  return {
    digest       => $run->{digest},
    raio         => $raio,
    profiles     => $profiles,
    nu_ano_censo => 0 + $school->{nu_ano_censo},
    related      => $related,
    updated_at   => $sel ? $sel->{updated_at} : undef,
    geojson      => $run->{geojson},
  };
}

sub osm_for_municipio($self, %args) {
  my $codigo_ibge = $args{codigo_ibge} // die 'Need codigo_ibge';

  my $geom = $self->_load_municipio_geometry($codigo_ibge)
    or die sprintf('Município sem geometria: %s', $codigo_ibge);

  my $query = EduMaps::Services::OSM::Query->new(
    target => { type => 'poly', geometry => $geom },
    (exists $args{profiles} ? (profiles => $args{profiles}) : ()),
    (exists $args{filters}  ? (filters  => $args{filters})  : ()),
    log => $self->log,
  );

  my $run = $self->_ensure_query(
    $query,
    city_fid => $codigo_ibge,
    refresh  => $args{refresh},
  );

  my $related = $self->_relate_municipio($codigo_ibge, $run->{digest});

  return {
    digest      => $run->{digest},
    codigo_ibge => $codigo_ibge,
    related     => $related,
    geojson     => $run->{geojson},
  };
}

# ---------------------------------------------------------------------------
# Leituras
# ---------------------------------------------------------------------------

sub school_features($self, $co_entidade, $nu_ano_censo = undef) {
  my $search = { 'school_osm_features.co_entidade' => $co_entidade };
  $search->{'school_osm_features.nu_ano_censo'} = $nu_ano_censo if defined $nu_ano_censo;

  return $self->dbic->search_rs(
    $search,
    {
      join     => 'school_osm_features',
      distinct => 1,
    }
  );
}

sub municipio_features($self, $codigo_ibge) {
  return $self->dbic->search_rs(
    { 'municipio_osm_features.codigo_ibge' => $codigo_ibge },
    { join => 'municipio_osm_features', distinct => 1 }
  );
}

sub query_features($self, $digest) {
  return $self->dbic->search_rs(
    { 'osm_query_features.digest' => $digest },
    { join => 'osm_query_features', distinct => 1 }
  );
}

# Seleção atual (raio/perfis/digest/atualizado_em) da escola.
sub current_selection($self, $co_entidade, $nu_ano_censo = undef) {
  my $ano = $nu_ano_censo // $self->_latest_ano($co_entidade);
  return undef unless $ano;

  my $row = $self->schema->resultset('SchoolOsmQuery')
    ->find({ co_entidade => $co_entidade, nu_ano_censo => $ano });
  return undef unless $row;

  my $profiles = eval { decode_json($row->profiles) } || [];

  return {
    co_entidade  => 0 + $row->co_entidade,
    nu_ano_censo => 0 + $row->nu_ano_censo,
    raio         => 0 + $row->raio,
    profiles     => $profiles,
    digest       => $row->digest,
    updated_at   => $row->updated_at,
  };
}

# Grava (upsert) a seleção usada — sobrescreve a anterior.
sub record_selection($self, $co_entidade, $nu_ano_censo, $raio, $profiles, $digest) {
  $self->schema->resultset('SchoolOsmQuery')->update_or_create({
    co_entidade  => $co_entidade,
    nu_ano_censo => $nu_ano_censo,
    raio         => $raio,
    profiles     => encode_json($profiles // []),
    digest       => $digest,
    updated_at   => \'now()',
  });
}

# Resumo dos POIs relacionados à escola, por categoria.
sub school_pois_summary($self, $co_entidade, $nu_ano_censo = undef) {
  my @params = ($co_entidade);
  my $where  = 's.co_entidade = ?';
  if (defined $nu_ano_censo) {
    $where .= ' AND s.nu_ano_censo = ?';
    push @params, $nu_ano_censo;
  }

  my $rows = $self->_dbh->selectall_arrayref(qq{
    SELECT COALESCE(f.category, f.tags_key, 'outros') AS category, count(*) AS count
      FROM clean.school_osm_feature s
      JOIN clean.osm_feature f
        ON f.osm_type = s.osm_type AND f.osm_id = s.osm_id
     WHERE $where
     GROUP BY 1
     ORDER BY count DESC, category ASC
  }, { Slice => {} }, @params);

  my $total = 0;
  $total += $_->{count} for @$rows;

  return {
    total  => $total,
    resumo => [ map { { category => $_->{category}, count => 0 + $_->{count} } } @$rows ],
  };
}

# Localização da escola (para desenhar no mapa junto aos POIs).
sub school_location($self, $co_entidade, $nu_ano_censo = undef) {
  my $row = $self->_load_school($co_entidade, $nu_ano_censo);
  return undef unless $row;

  return {
    co_entidade  => 0 + $row->{co_entidade},
    nu_ano_censo => 0 + $row->{nu_ano_censo},
    nome         => $row->{no_entidade},
    latitude     => defined $row->{latitude}  ? 0 + $row->{latitude}  : undef,
    longitude    => defined $row->{longitude} ? 0 + $row->{longitude} : undef,
  };
}

# GeoJSON dos POIs relacionados à escola, com a geometria reduzida ao
# centroide (ST_PointOnSurface) — leve para desenhar no mapa.
sub school_pois_geojson($self, $co_entidade, $nu_ano_censo = undef) {
  my @params = ($co_entidade);
  my $where  = 's.co_entidade = ?';
  if (defined $nu_ano_censo) {
    $where .= ' AND s.nu_ano_censo = ?';
    push @params, $nu_ano_censo;
  }

  my $json = $self->_dbh->selectrow_array(qq{
    SELECT json_build_object(
      'type', 'FeatureCollection',
      'features', COALESCE(json_agg(
        json_build_object(
          'type', 'Feature',
          'geometry', ST_AsGeoJSON(ST_PointOnSurface(f.geom))::json,
          'properties', json_build_object(
            'osm_type', f.osm_type,
            'osm_id', f.osm_id,
            'category', COALESCE(f.category, f.tags_key, 'outros'),
            'nome', f.properties->>'name',
            'distance_m', s.distance_m
          )
        )
        ORDER BY s.distance_m NULLS LAST, f.osm_type, f.osm_id
      ), '[]'::json)
    )
    FROM clean.school_osm_feature s
    JOIN clean.osm_feature f
      ON f.osm_type = s.osm_type AND f.osm_id = s.osm_id
   WHERE $where AND f.geom IS NOT NULL
  }, undef, @params);

  return $json ? decode_json($json) : { type => 'FeatureCollection', features => [] };
}

# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------

sub _dbh($self) { $self->schema->storage->dbh }

sub _latest_ano($self, $co) {
  return $self->_dbh->selectrow_array(
    'SELECT max(nu_ano_censo) FROM clean.censo_escolas WHERE co_entidade = ?',
    undef, $co
  );
}

sub _emit_progress($self, $percent, $message = '') {
  $self->emit(progress => { percent => $percent, message => $message });
}

sub _load_school($self, $co, $ano = undef) {
  my $where  = 'co_entidade = ?';
  my @params = ($co);
  if (defined $ano) {
    $where .= ' AND nu_ano_censo = ?';
    push @params, $ano;
  }

  my $row = $self->_dbh->selectrow_hashref(
    qq{
      SELECT co_entidade, nu_ano_censo, co_municipio, no_entidade, latitude, longitude
        FROM clean.censo_escolas
       WHERE $where
       ORDER BY nu_ano_censo DESC
       LIMIT 1
    },
    undef, @params
  );
  return $row;
}

sub _load_municipio_geometry($self, $codigo_ibge) {
  my $geojson = $self->_dbh->selectrow_array(
    'SELECT ST_AsGeoJSON(geometry) FROM clean.municipios_sp WHERE codigo_ibge = ?',
    undef, $codigo_ibge
  );
  return $geojson ? decode_json($geojson) : undef;
}

sub _cached_raw($self, $digest, $refresh) {
  return undef if $refresh;

  my $row = eval { $self->schema->resultset('OsmQuery')->find($digest) };
  return undef unless $row && defined $row->raw_results;

  if ($self->cache_ttl_days) {
    my $last = $row->last_run // '';
    $last =~ s/\.\d+$//;   # o timestamp do PG pode vir com fração de segundos
    my $epoch = eval { Time::Piece->strptime($last, '%Y-%m-%d %H:%M:%S')->epoch };
    return undef if !$epoch || (time - $epoch) > $self->cache_ttl_days * 86_400;
  }

  return decode_json($row->raw_results);
}

# Garante a execução (cache ou Overpass), persiste features e devolve
# { digest, geojson, raw }.
sub _ensure_query($self, $query, %opts) {
  my $digest   = $query->digest;
  my $cached   = $self->_cached_raw($digest, $opts{refresh});
  my $geojson;
  my $raw;

  if ($cached) {
    $self->log->info("OSM cache HIT para digest $digest");
    $self->_emit_progress(80, 'Usando dados do cache local');
    $raw     = $cached;
    $geojson = $self->service_class->new(query => $query, log => $self->log)->parse($raw);
  }
  else {
    $self->log->info("OSM cache MISS para digest $digest; consultando Overpass");
    my $svc = $self->service_class->new(query => $query, log => $self->log);
    $svc->on(progress => sub ($evt, $p) {
      my $phase = $p->{phase} // '';
      my ($pct, $msg) = (10, 'Consultando o OpenStreetMap');

      if ($phase eq 'download osm') {
        $pct = 10 + int(($p->{processed} // 0) * 0.3);
        $msg = 'Baixando dados do OpenStreetMap';
      }
      elsif ($phase eq 'geojson') {
        my $total = $p->{total} // 0;
        my $proc  = $p->{processed} // 0;
        $pct = 40 + ($total ? int(($proc / $total) * 50) : 0);
        $msg = sprintf 'Processando feições (%d/%d)', $proc, $total;
      }

      $self->_emit_progress($pct, $msg);
    });

    $geojson = $svc->run;
    $raw     = $svc->raw;

    # Garante a linha em clean.osm_query (proveniência/FK) antes das features.
    $self->_save_query(
      $digest,
      {
        query   => $query->to_ql,
        data    => $svc->raw_body // encode_json($raw),
        elapsed => $svc->elapsed,
      },
      $opts{city_fid},
    );
  }

  $self->_emit_progress(92, 'Persistindo POIs');
  $self->_store_features($query, $digest, $geojson);

  return { digest => $digest, geojson => $geojson, raw => $raw };
}

sub _save_query($self, $digest, $info, $city_fid) {
  $self->log->info("Gravando resultado OSM (digest $digest)");
  $self->schema->resultset('OsmQuery')->update_or_create(
    {
      digest       => $digest,
      query        => $info->{query},
      raw_results  => $info->{data},
      elapsed_time => $info->{elapsed},
      city_fid     => $city_fid,
      last_run     => \'now()',
    }
  );
}

sub _store_features($self, $query, $digest, $geojson) {
  my $dbh = $self->_dbh;

  my $sth_feature = $dbh->prepare(q{
    INSERT INTO clean.osm_feature
      (osm_type, osm_id, tags_key, tags_value, category, geom, properties, updated_at)
    VALUES (?, ?, ?, ?, ?, ST_Transform(ST_GeomFromGeoJSON(?::json), 4674), ?::jsonb, now())
    ON CONFLICT (osm_type, osm_id) DO UPDATE SET
      tags_key   = EXCLUDED.tags_key,
      tags_value = EXCLUDED.tags_value,
      category   = EXCLUDED.category,
      geom       = EXCLUDED.geom,
      properties = EXCLUDED.properties,
      updated_at = now()
  });

  my $sth_link = $dbh->prepare(q{
    INSERT INTO clean.osm_query_feature (digest, osm_type, osm_id)
    VALUES (?, ?, ?)
    ON CONFLICT (digest, osm_type, osm_id) DO NOTHING
  });

  my $stored = 0;
  for my $f (@{ $geojson->{features} // [] }) {
    my $props    = $f->{properties} // {};
    my $osm_type = $props->{osm_type} // next;
    my $osm_id   = $props->{osm_id}   // next;
    next unless $f->{geometry};

    my ($key, $value, $category) = $query->classify($props);

    $sth_feature->execute(
      $osm_type, $osm_id, $key, $value, $category,
      encode_json($f->{geometry}), encode_json($props)
    );
    $sth_link->execute($digest, $osm_type, $osm_id);
    $stored++;
  }

  return $stored;
}

sub _relate_school($self, $co, $ano, $raio, $digest) {
  my $dbh = $self->_dbh;

  $dbh->do(
    'DELETE FROM clean.school_osm_feature WHERE co_entidade = ? AND nu_ano_censo = ?',
    undef, $co, $ano
  );

  my $n = $dbh->do(q{
    INSERT INTO clean.school_osm_feature
      (co_entidade, nu_ano_censo, osm_type, osm_id, raio, distance_m, digest)
    SELECT ?, ?, f.osm_type, f.osm_id, ?, 
           ST_Distance(f.geom::geography, esc.geom::geography), ?
      FROM clean.osm_feature f
      JOIN (
        SELECT COALESCE(
                 geometry,
                 ST_SetSRID(ST_MakePoint(longitude::float, latitude::float), 4674)
               ) AS geom
          FROM clean.censo_escolas
         WHERE co_entidade = ? AND nu_ano_censo = ?
      ) esc ON TRUE
     WHERE f.geom IS NOT NULL
       AND ST_DWithin(f.geom::geography, esc.geom::geography, ?)
       AND (f.osm_type, f.osm_id) IN (
         SELECT osm_type, osm_id FROM clean.osm_query_feature WHERE digest = ?
       )
    ON CONFLICT (co_entidade, nu_ano_censo, osm_type, osm_id) DO NOTHING
  }, undef, $co, $ano, $raio, $digest, $co, $ano, $raio, $digest);

  return 0 + ($n // 0);
}

sub _relate_municipio($self, $codigo_ibge, $digest) {
  my $dbh = $self->_dbh;

  $dbh->do(
    'DELETE FROM clean.municipio_osm_feature WHERE codigo_ibge = ?',
    undef, $codigo_ibge
  );

  my $n = $dbh->do(q{
    INSERT INTO clean.municipio_osm_feature (codigo_ibge, osm_type, osm_id, digest)
    SELECT ?, f.osm_type, f.osm_id, ?
      FROM clean.osm_feature f
     WHERE f.geom IS NOT NULL
       AND ST_Within(f.geom, (
             SELECT geometry FROM clean.municipios_sp WHERE codigo_ibge = ?
           ))
       AND (f.osm_type, f.osm_id) IN (
         SELECT osm_type, osm_id FROM clean.osm_query_feature WHERE digest = ?
       )
    ON CONFLICT (codigo_ibge, osm_type, osm_id) DO NOTHING
  }, undef, $codigo_ibge, $digest, $codigo_ibge, $digest);

  return 0 + ($n // 0);
}

1;
