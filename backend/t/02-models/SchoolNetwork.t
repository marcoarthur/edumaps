# t/02-models/SchoolNetwork.t
use lib qw(t/lib lib);
use Imports;
use Mojo::JSON qw(decode_json);
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Model::SchoolNetwork';
use ok 'EduMaps::Schema';

my $schema = EduMaps::Schema->go;
my $model  = EduMaps::Model::SchoolNetwork->new({ schema => $schema });
isa_ok($model, 'EduMaps::Model::SchoolNetwork');

my $TEST_IBGE_CODE = '3550308';  # São Paulo - SP

subtest 'summary() - Deve retornar a rede por tipo de administração' => sub {
  my $result = $model->summary({ codigo_ibge => $TEST_IBGE_CODE });

  is(ref $result, 'ARRAY', 'Retorna um arrayref');
  ok($result->@* >= 1, 'Possui pelo menos uma rede');

  for my $rede ($result->@*) {
    ok(exists $rede->{co_municipio} && $rede->{co_municipio} eq $TEST_IBGE_CODE, 'co_municipio presente');
    ok(exists $rede->{rede}, 'Campo rede presente');
    ok(exists $rede->{codigo_rede}, 'Campo codigo_rede presente');
    ok(exists $rede->{total_escolas}, 'Campo total_escolas presente');
    ok(exists $rede->{total_matriculas}, 'Campo total_matriculas presente');
    ok(exists $rede->{total_docentes}, 'Campo total_docentes presente');
  }
};

subtest 'summary() - Deve filtrar por rede (municipal)' => sub {
  my $result = $model->summary({ codigo_ibge => $TEST_IBGE_CODE, rede => 'municipal' });

  is($result->@*, 1, 'Retorna uma única rede');
  is($result->[0]{rede}, 'municipal', 'Rede é municipal');
  is($result->[0]{codigo_rede}, 3, 'Código da rede é 3');
};

subtest 'summary() - Deve retornar as 4 redes (incluindo federal)' => sub {
  my $result = $model->summary({ codigo_ibge => $TEST_IBGE_CODE });

  my %redes = map { $_->{rede} => 1 } $result->@*;
  ok($redes{municipal}, 'Possui rede municipal');
  ok($redes{estadual}, 'Possui rede estadual');
  ok($redes{privada}, 'Possui rede privada');
  ok($redes{federal}, 'Possui rede federal');
};

subtest 'summary() - Deve retornar array vazio para código inexistente' => sub {
  my $result = $model->summary({ codigo_ibge => '9999999' });
  is(ref $result, 'ARRAY', 'Retorna arrayref');
  is($result->@*, 0, 'Array vazio para município inexistente');
};

subtest 'schools() - Deve listar escolas de uma rede' => sub {
  my $result = $model->schools({ codigo_ibge => $TEST_IBGE_CODE, rede => 'municipal' });

  ok($result->@* >= 1, 'Possui escolas municipais');

  for my $school ($result->@*) {
    ok(exists $school->{co_entidade}, 'Campo co_entidade presente');
    ok(exists $school->{no_entidade}, 'Campo no_entidade presente');
    is($school->{tp_dependencia}, 3, 'Rede municipal (tp_dependencia=3)');
    ok(exists $school->{latitude}, 'Campo latitude presente');
    ok(exists $school->{matricula_qt_mat_bas}, 'Campo matricula presente');
  }
};

subtest 'markers() - Deve retornar GeoJSON FeatureCollection' => sub {
  my $result = $model->markers({ codigo_ibge => $TEST_IBGE_CODE });

  ok($result, 'Retornou algum valor');
  ok($result =~ /FeatureCollection/, 'É um FeatureCollection');

  my $geo = decode_json($result);
  is(ref $geo->{features}, 'ARRAY', 'Possui lista de features');
};

subtest 'performance() - Deve retornar série de desempenho' => sub {
  my $result = $model->performance({ codigo_ibge => $TEST_IBGE_CODE });

  ok($result->@* >= 1, 'Possui resultados de desempenho');

  for my $perf ($result->@*) {
    ok(exists $perf->{rede}, 'Campo rede presente');
    ok(exists $perf->{etapa}, 'Campo etapa presente');
    ok(exists $perf->{ano}, 'Campo ano presente');
    ok(exists $perf->{numero_escolas}, 'Campo numero_escolas presente');
    ok(exists $perf->{ideb_medio}, 'Campo ideb_medio presente');
  }
};

subtest 'performance() - Deve filtrar por rede e etapa' => sub {
  my $result = $model->performance({
    codigo_ibge => $TEST_IBGE_CODE,
    rede => 'estadual',
    etapa => 'fundamental_ii',
    desde => 2015,
  });

  ok($result->@* >= 1, 'Possui resultados filtrados');
  is($result->[0]{rede}, 'Estadual', 'Rede filtrada (capitalizada)');
  is($result->[0]{etapa}, 'fundamental_ii', 'Etapa filtrada');
};

done_testing;