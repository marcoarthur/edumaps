use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Schema;
use EduMaps::Model::OSM;

# Indicador de completude da malha viária no buffer de 500 m (#131 e2).
# Integração real com o banco local (rode com EDUMAPS_DB_HOST=127.0.0.1).
# Tudo acontece dentro de uma transação e é revertido no fim.

my $sch = eval { EduMaps::Schema->go };
skip_all 'sem banco disponível (rode com EDUMAPS_DB_HOST=127.0.0.1)' unless $sch;

my $dbh = $sch->storage->dbh;

my $has_fn = $dbh->selectrow_array(
  "SELECT to_regprocedure('clean.iv_mobilidade_completude_malha(bigint,integer,text)')"
);
skip_all 'função clean.iv_mobilidade_completude_malha ausente (migration não aplicada)'
  unless $has_fn;

my $school = $dbh->selectrow_hashref(q{
  SELECT co_entidade, nu_ano_censo, co_municipio,
         ST_X(geometry) AS lon, ST_Y(geometry) AS lat
    FROM clean.censo_escolas
   WHERE geometry IS NOT NULL
   ORDER BY co_entidade
   LIMIT 1
});
skip_all 'sem escola com geometria no censo local' unless $school;

my $co  = $school->{co_entidade};
my $ano = $school->{nu_ano_censo};
my $lon = 0 + $school->{lon};
my $lat = 0 + $school->{lat};
my $mun = $school->{co_municipio} // '3554003';

# Digests únicos por execução (evita colisão com dados reais/de execuções).
my $d_malha = sprintf 'tst_malha_%d', $$;
my $d_pois  = sprintf 'tst_pois_%d',  $$;
my $d_vazio = sprintf 'tst_vazio_%d', $$;

my $ql_malha = qq{[out:json][timeout:60];\n(\n  nwr["highway"](around:500,$lat,$lon);\n);\nout body;\n>;\nout skel qt;\n};
my $ql_pois  = qq{[out:json][timeout:60];\n(\n  nwr["amenity"="library"](around:500,$lat,$lon);\n);\nout body;\n>;\nout skel qt;\n};

$dbh->begin_work;

for my $q ([$d_malha, $ql_malha], [$d_pois, $ql_pois], [$d_vazio, $ql_malha]) {
  $dbh->do(
    'INSERT INTO clean.osm_query (digest, query, city_fid) VALUES (?,?,?)',
    {}, $q->[0], $q->[1], $mun
  );
}

# Via (highway) de ~22 km passando pelo centro da escola (o buffer corta nos
# 500 m, sobrando ~1 km = o diâmetro).
$dbh->do(q{
  INSERT INTO clean.osm_feature (osm_type, osm_id, tags_key, tags_value, category, geom, properties)
  VALUES ('way', 990001, 'highway', 'residential', 'highway=residential',
          ST_SetSRID(ST_MakeLine(ST_MakePoint(?, ?), ST_MakePoint(?, ?)), 4674),
          '{"highway":"residential"}'::jsonb)
  ON CONFLICT (osm_type, osm_id) DO UPDATE SET geom = EXCLUDED.geom, tags_key = EXCLUDED.tags_key
}, {}, $lon - 0.1, $lat, $lon + 0.1, $lat);

# POI (não-via) no buffer.
$dbh->do(q{
  INSERT INTO clean.osm_feature (osm_type, osm_id, tags_key, tags_value, category, geom, properties)
  VALUES ('node', 990002, 'amenity', 'library', 'amenity=library',
          ST_SetSRID(ST_MakePoint(?, ?), 4674), '{"amenity":"library"}'::jsonb)
  ON CONFLICT (osm_type, osm_id) DO UPDATE SET geom = EXCLUDED.geom, tags_key = EXCLUDED.tags_key
}, {}, $lon, $lat);

# Relação: d_malha tem a via; d_pois tem só o POI (sem via).
$dbh->do(q{
  INSERT INTO clean.school_osm_feature (co_entidade, nu_ano_censo, osm_type, osm_id, raio, distance_m, digest)
  VALUES (?, ?, 'way', 990001, 500, 0, ?), (?, ?, 'node', 990002, 500, 0, ?)
  ON CONFLICT (co_entidade, nu_ano_censo, osm_type, osm_id) DO UPDATE SET digest = EXCLUDED.digest
}, {}, $co, $ano, $d_malha, $co, $ano, $d_pois);

my $fn = sub {
  my ($digest) = @_;
  return $dbh->selectrow_array(
    'SELECT clean.iv_mobilidade_completude_malha(?,?,?)', undef, $co, $ano, $digest
  );
};

subtest 'função SQL: densidade de via no buffer (m/km²)' => sub {
  my $v = $fn->($d_malha);
  ok defined $v, 'valor não nulo';
  # diâmetro do buffer (2*500 m) / área(π·500²) * 1e6 ≈ 1273 m/km²
  ok($v > 1200 && $v < 1350, "densidade próxima de 1273 m/km² ($v)");
};

subtest 'função SQL: 0 quando a extração não trouxe via (não é ausência)' => sub {
  my $v = $fn->($d_pois);
  ok defined $v, 'há extração para o digest => valor definido';
  is 0 + $v, 0, 'sem via no buffer => 0';
};

subtest 'função SQL: NULL quando não há extração para o digest' => sub {
  my $v = $fn->($d_vazio);
  is $v, undef, 'sem extração => NULL (ausência, não zero)';
};

my $model = EduMaps::Model::OSM->new(schema => $sch);

subtest 'Model: sem malha_viaria devolve ausência (guarda)' => sub {
  $dbh->do(q{
    INSERT INTO clean.school_osm_query (co_entidade, nu_ano_censo, raio, profiles, digest, updated_at)
    VALUES (?,?,500,'["equipamentos_publicos"]'::jsonb,?,now())
    ON CONFLICT (co_entidade, nu_ano_censo) DO UPDATE
      SET raio = EXCLUDED.raio, profiles = EXCLUDED.profiles,
          digest = EXCLUDED.digest, updated_at = now()
  }, {}, $co, $ano, $d_malha);

  my $r = $model->iv_mobilidade_completude_malha(co_entidade => $co, nu_ano_censo => $ano);
  is $r->{extraido}, 0, 'não extraído (perfil sem malha_viaria)';
  is $r->{valor}, undef, 'valor nulo (ausência, não zero)';
  is $r->{unidade}, 'm/km²', 'unidade';
  is $r->{raio}, 500, 'raio do buffer';
};

subtest 'Model: com malha_viaria calcula a densidade' => sub {
  $dbh->do(q{
    UPDATE clean.school_osm_query
       SET profiles = '["malha_viaria"]'::jsonb, digest = ?, updated_at = now()
     WHERE co_entidade = ? AND nu_ano_censo = ?
  }, {}, $d_malha, $co, $ano);

  my $r = $model->iv_mobilidade_completude_malha(co_entidade => $co, nu_ano_censo => $ano);
  is $r->{extraido}, 1, 'extraído';
  ok defined $r->{valor} && $r->{valor} > 0, "valor positivo ($r->{valor})";
  is $r->{digest}, $d_malha, 'digest da seleção';
  is $r->{unidade}, 'm/km²', 'unidade';
};

subtest 'Model: digest/profiles explícitos (caminho do job)' => sub {
  my $r = $model->iv_mobilidade_completude_malha(
    co_entidade => $co, nu_ano_censo => $ano,
    digest => $d_pois, profiles => ['malha_viaria'],
  );
  is $r->{extraido}, 1, 'extraído (perfil explícito)';
  is 0 + $r->{valor}, 0, '0 porque a extração só tem POI (sem via)';

  my $r2 = $model->iv_mobilidade_completude_malha(
    co_entidade => $co, nu_ano_censo => $ano,
    digest => $d_malha, profiles => ['equipamentos_publicos'],
  );
  is $r2->{extraido}, 0, 'guarda: perfil explícito sem malha_viaria';
  is $r2->{valor}, undef, 'valor nulo';
};

$dbh->rollback;

done_testing;
