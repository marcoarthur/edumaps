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

# Número a partir de um valor do DBI (0 fallback); preserva a ausência (undef).
sub _num($v) { defined $v ? 0 + $v : undef }

# A tabela do entorno é uma change posterior à da influência: se ainda não foi
# aplicada, o endpoint continua de pé (só sem leitura — ausência ≠ zero, #154).
sub _tem_tabela_entorno($self) {
  return $self->_dbh->selectrow_array(
    "SELECT to_regclass('clean.escola_entorno_socioeconomico')") ? 1 : 0;
}

# Arealização socioeconômica do entorno (#137, bloco B) por raio: setores do
# Censo 2022 intersectados com a área de influência. Devolve { raio_m => \%leitura }.
# Ausência ≠ zero (#154): raio sem linha — ou componente sem insumo no Censo —
# vem como undef, e o cliente mostra "—" em vez de 0.
sub entorno_por_raio($self, $co_entidade, $nu_ano_censo) {
  return {} unless $self->_tem_tabela_entorno;

  my $rows = $self->_dbh->selectall_arrayref(qq{
    SELECT raio_m, pop_total, densidade_pop_km2,
           renda_per_capita, renda_resp_media, renda_resp_mediana,
           pct_sem_instrucao, pct_fund_incomp, pct_medio_mais, pct_analfabeto,
           pct_esgoto_inadequado, pct_agua_sem_rede, pct_lixo_inadequado,
           pct_sem_banheiro, cobertura_pct,
           n_setores, n_setores_suprimidos, versao
      FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ?
  }, { Slice => {} }, $co_entidade, $nu_ano_censo);

  my %por_raio;
  for my $r (@$rows) {
    $por_raio{ 0 + $r->{raio_m} } = {
      pop_total             => _num($r->{pop_total}),
      densidade_pop_km2     => _num($r->{densidade_pop_km2}),
      renda_per_capita      => _num($r->{renda_per_capita}),
      renda_resp_media      => _num($r->{renda_resp_media}),
      renda_resp_mediana    => _num($r->{renda_resp_mediana}),
      pct_sem_instrucao     => _num($r->{pct_sem_instrucao}),
      pct_fund_incomp       => _num($r->{pct_fund_incomp}),
      pct_medio_mais        => _num($r->{pct_medio_mais}),
      pct_analfabeto        => _num($r->{pct_analfabeto}),
      pct_esgoto_inadequado => _num($r->{pct_esgoto_inadequado}),
      pct_agua_sem_rede     => _num($r->{pct_agua_sem_rede}),
      pct_lixo_inadequado   => _num($r->{pct_lixo_inadequado}),
      pct_sem_banheiro      => _num($r->{pct_sem_banheiro}),
      cobertura_pct         => _num($r->{cobertura_pct}),
      n_setores             => 0 + $r->{n_setores},
      n_setores_suprimidos  => 0 + $r->{n_setores_suprimidos},
      versao                => $r->{versao},
    };
  }

  return \%por_raio;
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

  # Leitura do entorno socioeconômico (#137, bloco B) anexada a cada anel. Sem
  # linha na tabela do entorno, `entorno` fica null (ausência ≠ 0, #154).
  my $entorno = $self->entorno_por_raio($co_entidade, $ano);
  for my $feat (@{ $geojson->{features} }) {
    my $raio = 0 + ($feat->{properties}{raio_m} // 0);
    $feat->{properties}{entorno} = $entorno->{$raio};
  }

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
