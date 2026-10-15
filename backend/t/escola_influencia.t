use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Schema;

# Camada de influência da escola (#255/#137, metodologia influencia-v1):
# clean.escola_influencia + clean.refresh_escola_influencia().
# Integração real com o banco local (rode com EDUMAPS_DB_HOST=127.0.0.1).
# Tudo acontece dentro de uma transação e é revertido no fim.

my $sch = eval { EduMaps::Schema->go };
skip_all 'sem banco disponível (rode com EDUMAPS_DB_HOST=127.0.0.1)' unless $sch;

my $dbh = $sch->storage->dbh;

my $has_fn = $dbh->selectrow_array(
  "SELECT to_regprocedure('clean.refresh_escola_influencia(integer[],bigint[])')"
);
skip_all 'clean.refresh_escola_influencia ausente (migration não aplicada)'
  unless $has_fn;

my $school = $dbh->selectrow_hashref(q{
  SELECT co_entidade, nu_ano_censo
    FROM clean.censo_escolas
   WHERE geometry IS NOT NULL
   ORDER BY co_entidade
   LIMIT 1
});
skip_all 'sem escola com geometria no censo local' unless $school;

my $co  = $school->{co_entidade};
my $ano = $school->{nu_ano_censo};

$dbh->begin_work;

subtest 'refresh materializa buffers (tier, raio, SRID, versão)' => sub {
  my $n = $dbh->selectrow_array(
    'SELECT clean.refresh_escola_influencia(?::integer[], ?::bigint[])',
    {}, '{500,1000}', '{' . $co . '}'
  );
  ok $n >= 2, "refresh gerou linhas ($n)";

  my $rows = $dbh->selectall_arrayref(q{
    SELECT tier, raio_m, versao, ST_SRID(geom) AS srid, geometrytype(geom) AS gtype
      FROM clean.escola_influencia
     WHERE co_entidade = ? AND nu_ano_censo = ?
     ORDER BY raio_m
  }, { Slice => {} }, $co, $ano);

  is scalar @$rows, 2, 'duas linhas (500 e 1000)';
  is $rows->[0]{raio_m}, 500,  'raio 500';
  is $rows->[1]{raio_m}, 1000, 'raio 1000';
  is $rows->[0]{tier}, 'buffer', 'tier buffer';
  is $rows->[0]{versao}, 'influencia-v1', 'versão da metodologia';
  is $rows->[0]{srid}, 4674, 'SRID 4674';
  like $rows->[0]{gtype}, qr/POLYGON/i, 'geometria é polígono';
};

subtest 'área do buffer é métrica (~π·r²)' => sub {
  my $area = $dbh->selectrow_array(q{
    SELECT ST_Area(geom::geography) FROM clean.escola_influencia
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $co, $ano);
  # buffer de geography é em metros; o polígono inscreve o círculo, logo a
  # área fica um pouco abaixo de π·500² (785398).
  ok($area > 770000 && $area < 785400, "área ~π·500² ($area)");
};

subtest 'o raio corta certo: 400 m dentro, 600 m fora' => sub {
  my $dentro = $dbh->selectrow_array(q{
    SELECT ST_Covers(b.geom::geography, ST_Project(e.geometry::geography, 400, 0))::int
      FROM clean.escola_influencia b
      JOIN clean.censo_escolas e
        ON e.co_entidade = b.co_entidade AND e.nu_ano_censo = b.nu_ano_censo
     WHERE b.co_entidade = ? AND b.nu_ano_censo = ? AND b.raio_m = 500
  }, {}, $co, $ano);
  ok $dentro, 'ponto a 400 m está dentro do buffer de 500 m';

  my $fora = $dbh->selectrow_array(q{
    SELECT ST_Covers(b.geom::geography, ST_Project(e.geometry::geography, 600, 0))::int
      FROM clean.escola_influencia b
      JOIN clean.censo_escolas e
        ON e.co_entidade = b.co_entidade AND e.nu_ano_censo = b.nu_ano_censo
     WHERE b.co_entidade = ? AND b.nu_ano_censo = ? AND b.raio_m = 500
  }, {}, $co, $ano);
  ok !$fora, 'ponto a 600 m está fora do buffer de 500 m';
};

subtest 'idempotente: o segundo refresh não duplica' => sub {
  my $n = $dbh->selectrow_array(
    'SELECT clean.refresh_escola_influencia(?::integer[], ?::bigint[])',
    {}, '{500,1000}', '{' . $co . '}'
  );
  ok $n >= 2, "refresh devolve linhas afetadas ($n)";

  my $count = $dbh->selectrow_array(q{
    SELECT count(*) FROM clean.escola_influencia
     WHERE co_entidade = ? AND nu_ano_censo = ?
  }, {}, $co, $ano);
  is $count, 2, 'continua com 2 linhas (UPSERT, sem duplicar)';
};

subtest 'raio inválido é rejeitado' => sub {
  my $ok = eval {
    $dbh->selectrow_array(
      'SELECT clean.refresh_escola_influencia(?::integer[], ?::bigint[])',
      {}, '{0}', '{' . $co . '}'
    );
    1;
  };
  ok !$ok, 'raio 0 levanta exceção';
};

$dbh->rollback;

done_testing;
