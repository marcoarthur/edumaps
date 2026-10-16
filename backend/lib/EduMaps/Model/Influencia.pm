package EduMaps::Model::Influencia;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Mojo::JSON qw(decode_json);
use utf8;

=head1 NAME

EduMaps::Model::Influencia - leitura da área de influência da escola (#255/#137)

=head1 DESCRIPTION

Leitura (somente) da camada materializada C<clean.escola_influencia>
(metodologia C<influencia-v1>, F<docs/analises/influencia.md>). Tier 1 =
buffer de raio documentado (C<raio_m>, em metros) ao redor da escola.

A materialização é responsabilidade do job C<refresh_influencia>
(C<clean.refresh_escola_influencia>) — este modelo nunca escreve. A geometria
é lida do banco (C<ST_AsGeoJSON>), portanto o mapa mostra *a* camada, não um
círculo recalculado no cliente.

Seguindo a regra da #154, distinguimos ausência de zero:

  * escola sem linha na camada -> C<status> devolve C<undef>
    ("ainda não calculada");
  * escola com linha(s)        -> o polígono materializado é real.

=cut

# A geometria de origem é anual (clean.censo_escolas.nu_ano_censo): o ano mais
# recente materializado é o que o painel mostra por padrão.
sub _latest_ano($self, $co_entidade) {
  return $self->_dbh->selectrow_array(
    'SELECT max(nu_ano_censo) FROM clean.escola_influencia WHERE co_entidade = ?',
    undef, $co_entidade
  );
}

sub _dbh($self) { $self->schema->storage->dbh }

# Localização da escola (para desenhar o ponto junto aos buffers).
sub escola_localizacao($self, $co_entidade, $nu_ano_censo = undef) {
  my $where  = 'co_entidade = ?';
  my @params = ($co_entidade);
  if (defined $nu_ano_censo) {
    $where .= ' AND nu_ano_censo = ?';
    push @params, $nu_ano_censo;
  }

  my $row = $self->_dbh->selectrow_hashref(
    qq{
      SELECT co_entidade, nu_ano_censo, no_entidade, latitude, longitude
        FROM clean.censo_escolas
       WHERE $where
       ORDER BY nu_ano_censo DESC
       LIMIT 1
    },
    undef, @params
  );
  return undef unless $row;

  return {
    co_entidade  => 0 + $row->{co_entidade},
    nu_ano_censo => 0 + $row->{nu_ano_censo},
    nome         => $row->{no_entidade},
    latitude     => defined $row->{latitude}  ? 0 + $row->{latitude}  : undef,
    longitude    => defined $row->{longitude} ? 0 + $row->{longitude} : undef,
  };
}

# GeoJSON (FeatureCollection) dos buffers materializados — um polígono por raio,
# ordenado do menor para o maior (o cliente desenha por cima o menor).
sub geojson($self, $co_entidade, $nu_ano_censo) {
  my $json = $self->_dbh->selectrow_array(qq{
    SELECT json_build_object(
      'type', 'FeatureCollection',
      'features', COALESCE(json_agg(
        json_build_object(
          'type', 'Feature',
          'geometry', ST_AsGeoJSON(geom)::json,
          'properties', json_build_object(
            'raio_m', raio_m,
            'tier', tier,
            'versao', versao,
            'area_km2', ROUND((ST_Area(geom::geography) / 1000000.0)::numeric, 4),
            'computado_em', computado_em
          )
        ) ORDER BY raio_m
      ), '[]'::json)
    )
    FROM clean.escola_influencia
   WHERE co_entidade = ? AND nu_ano_censo = ?
  }, undef, $co_entidade, $nu_ano_censo);

  return $json ? decode_json($json) : { type => 'FeatureCollection', features => [] };
}

# Estado da camada para o painel: proveniência + localização + geometria.
# Devolve C<undef> quando a escola ainda não foi materializada (#154).
sub status($self, $co_entidade, $nu_ano_censo = undef) {
  my $ano = $nu_ano_censo // $self->_latest_ano($co_entidade);
  return undef unless $ano;

  my $meta = $self->_dbh->selectrow_hashref(qq{
    SELECT versao, tier, computado_em
      FROM clean.escola_influencia
     WHERE co_entidade = ? AND nu_ano_censo = ?
     ORDER BY computado_em DESC, raio_m ASC
     LIMIT 1
  }, undef, $co_entidade, $ano);
  return undef unless $meta;

  my $geojson = $self->geojson($co_entidade, $ano);

  return {
    co_entidade  => 0 + $co_entidade,
    nu_ano_censo => 0 + $ano,
    computado    => 1,
    versao       => $meta->{versao},
    tier         => $meta->{tier},
    computado_em => $meta->{computado_em},
    raios        => [ map { 0 + $_->{properties}{raio_m} } @{ $geojson->{features} } ],
    escola       => $self->escola_localizacao($co_entidade, $ano),
    geojson      => $geojson,
  };
}

1;
