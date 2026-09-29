use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Schema;
use EduMaps::Model::OSM;

# Serviço OSM offline para o teste (não toca a rede).
{
  package Test::OSM::Offline;
  use Mojo::Base 'EduMaps::Services::OSM', -signatures;
  our $FIXTURE;
  sub new($class, %args) {
    $class->SUPER::new(%args, offline => 1, fixture => $FIXTURE);
  }
}

my $sch = eval { EduMaps::Schema->go };
skip_all 'sem banco disponível (rode com EDUMAPS_DB_HOST=127.0.0.1)' unless $sch;

my $school = $sch->storage->dbh->selectrow_hashref(q{
  SELECT co_entidade, nu_ano_censo, co_municipio, latitude, longitude
    FROM clean.censo_escolas
   WHERE latitude IS NOT NULL
     AND longitude IS NOT NULL
     AND geometry IS NOT NULL
   ORDER BY co_entidade
   LIMIT 1
});
skip_all 'sem escola no censo local' unless $school;

$Test::OSM::Offline::FIXTURE = {
  version   => 0.6,
  generator => 'offline-test',
  elements  => [
    {
      type => 'node', id => 987654,
      lat  => 0 + $school->{latitude},
      lon  => 0 + $school->{longitude},
      tags => { amenity => 'library', name => 'Biblioteca Teste' },
    },
  ],
};

my $dbh = $sch->storage->dbh;
$dbh->begin_work;

my $model = EduMaps::Model::OSM->new(
  schema         => $sch,
  service_class  => 'Test::OSM::Offline',
  cache_ttl_days => 30,
);

subtest 'osm_for_school cacheia, persiste a feature e a relação (buffer)' => sub {
  my $res = $model->osm_for_school(
    co_entidade => $school->{co_entidade},
    raio        => 500,
    profiles    => ['educacao'],
  );

  ok $res->{digest},               'digest calculado';
  ok $res->{related} >= 1,         'feature relacionada ao buffer da escola';
  ok $sch->resultset('OsmQuery')->find($res->{digest}), 'osm_query persistido';

  my $feat = $sch->resultset('OsmFeature')->find({ osm_type => 'node', osm_id => 987654 });
  ok $feat, 'osm_feature persistida';
  is $feat->tags_key,   'amenity', 'tags_key';
  is $feat->tags_value, 'library', 'tags_value';

  my $rel = $sch->resultset('SchoolOsmFeature')->search({
    co_entidade => $school->{co_entidade},
    osm_type    => 'node',
    osm_id      => 987654,
  })->count;
  is $rel, 1, 'school_osm_feature (relação)';
};

subtest 'segunda chamada usa o cache (HIT)' => sub {
  my $res = $model->osm_for_school(
    co_entidade => $school->{co_entidade},
    raio        => 500,
    profiles    => ['educacao'],
  );
  ok $res->{related} >= 1, 'relação mantida no cache';
};

subtest 'school_features lê as features relacionadas' => sub {
  my $rs = $model->school_features($school->{co_entidade});
  ok $rs->count >= 1, 'ao menos uma feature relacionada';
};

subtest 'osm_for_municipio relaciona por ST_Within' => sub {
  my $mun = $sch->storage->dbh->selectrow_hashref(q{
    SELECT codigo_ibge,
           ST_X(ST_PointOnSurface(geometry)) AS lon,
           ST_Y(ST_PointOnSurface(geometry)) AS lat
      FROM clean.municipios_sp
     WHERE geometry IS NOT NULL
     ORDER BY codigo_ibge
     LIMIT 1
  });
  skip_all 'sem município com geometria no banco' unless $mun;

  $Test::OSM::Offline::FIXTURE = {
    elements => [
      {
        type => 'node', id => 555001,
        lat  => 0 + $mun->{lat}, lon => 0 + $mun->{lon},
        tags => { amenity => 'townhall', name => 'Prefeitura Teste' },
      },
    ],
  };

  my $res = $model->osm_for_municipio(
    codigo_ibge => $mun->{codigo_ibge},
    profiles    => ['administracao'],
  );

  ok $res->{related} >= 1, 'feature relacionada ao município';
  is $sch->resultset('MunicipioOsmFeature')->search({
    codigo_ibge => $mun->{codigo_ibge},
    osm_id      => 555001,
  })->count, 1, 'municipio_osm_feature';
};

$dbh->rollback;

done_testing;
