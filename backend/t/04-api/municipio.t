use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use DDP;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

subtest 'código existente (Campos Sales - CE)' => sub {
  my $cod = 2302701;

  $t->get_ok("/api/city/$cod/details")
  ->status_is(200)
  ->json_has('/profissionais_educacao')
  ->json_has('/cobertura_escolar')
  ->json_has('/detalhes_cidade')
  ->json_has('/porte_escola')
  ->json_like('/cobertura_escolar/nome_municipio' => qr/Campos Sales/)
  ->json_like('/detalhes_cidade/estado'           => qr/Ceará/);
};

subtest 'código existente (outro município)' => sub {
  # Escolha um código que exista no seu banco (ex: Alta Floresta D'Oeste - RO)
  my $cod = 1100015;

  $t->get_ok("/api/city/$cod/details")
  ->status_is(200)
  ->json_has('/detalhes_cidade/nome_municipio')
  ->json_like('/detalhes_cidade/estado' => qr/Rondônia|RO/);
};

subtest 'código inexistente (7 dígitos, sem dados)' => sub {
  my $cod = 9999999;

  $t->get_ok("/api/city/$cod/details")
  ->status_is(404);
};

subtest 'código com menos de 7 dígitos (rota não casa)' => sub {
  my $cod = 230270;    # 6 dígitos

  $t->get_ok("/api/city/$cod/details")
  ->status_is(404);
};

subtest 'código com mais de 7 dígitos (rota não casa)' => sub {
  my $cod = 23027010;  # 8 dígitos

  $t->get_ok("/api/city/$cod/details")
  ->status_is(404);
};

subtest 'código não numérico (rota não casa)' => sub {
  my $cod = 'abc1234';

  $t->get_ok("/api/city/$cod/details")
  ->status_is(404);
};

subtest 'verificação detalhada da estrutura da resposta' => sub {
  my $cod = 2302701;

  my $tx = $t->get_ok("/api/city/$cod/details")->status_is(200)->tx;
  my $json = $tx->res->json;

  # 1. Chaves principais existem
  ok exists $json->{detalhes_cidade},       'detalhes_cidade existe';
  ok exists $json->{porte_escola},          'porte_escola existe';
  ok exists $json->{profissionais_educacao},'profissionais_educacao existe';
  ok exists $json->{cobertura_escolar},     'cobertura_escolar existe';

  # 2. Tipos (referências simples)
  ok ref($json->{detalhes_cidade}) eq 'HASH',       'detalhes_cidade é um hash';
  ok ref($json->{porte_escola}) eq 'HASH',          'porte_escola é um hash';
  ok ref($json->{profissionais_educacao}) eq 'HASH', 'profissionais_educacao é um hash';
  ok ref($json->{cobertura_escolar}) eq 'HASH',     'cobertura_escolar é um hash';

  # 3. Cobertura escolar: deve ter pelo menos nome_municipio
  ok exists $json->{cobertura_escolar}{nome_municipio}, 'nome_municipio presente';

  # 4. Profissionais educação: pode estar vazio; apenas verifique que é hash
  #    (não exigimos chaves, pois pode não haver dados)
  pass('profissionais_educacao é um hash (pode estar vazio)');

  # 5. Porte escola: deve ter pelo menos uma chave, e cada chave deve ter 'total' e 'escolas' (array)
  my @porte_keys = keys %{$json->{porte_escola}};
  ok @porte_keys > 0, 'porte_escola contém pelo menos uma entrada';

  foreach my $porte (@porte_keys) {
    my $info = $json->{porte_escola}{$porte};
    ok exists $info->{total}, "porte $porte tem campo total";
    ok exists $info->{escolas}, "porte $porte tem campo escolas";
    ok ref($info->{escolas}) eq 'ARRAY', "escolas do porte $porte é um array";
  }

  # 6. Content-Type (ignorando charset)
  my $ct = $tx->res->headers->content_type;
  like $ct, qr{^application/json}, 'Content-Type é application/json (com ou sem charset)';

  # 7. (Opcional) Verificação de ordenação canônica – apenas se quiser garantir
  #    que as chaves do objeto principal estão em ordem alfabética.
  # my @top_keys = keys %$json;
  # my @sorted = sort @top_keys;
  # is_deeply \@top_keys, \@sorted, 'Chaves do objeto principal ordenadas canonicamente'
  #   or do { diag "Ordenação: " . join(', ', @top_keys) };
};

subtest 'OSM features com dados existentes' => sub {
  my $cod = 2302701;   # use um código que você sabe que tem dados OSM

  my $tx = $t->get_ok("/api/city/$cod/osm_features")->status_is(200)->tx;
  my $json = $tx->res->json;

  ok exists $json->{meta}, 'meta existe';
  ok exists $json->{geojson}, 'geojson existe';

  my $meta = $json->{meta};
  is $meta->{city_code}, $cod, 'city_code corresponde';
  ok exists $meta->{generated_at}, 'generated_at presente';
  ok $meta->{generated_at} =~ /^\d+$/, 'generated_at é um timestamp (número)';
  is $meta->{type}, 'landuse', 'type é landuse';

  my $geojson = $json->{geojson};
  is $geojson->{type}, 'FeatureCollection', 'tipo GeoJSON é FeatureCollection';
  ok ref($geojson->{features}) eq 'ARRAY', 'features é um array';
  ok @{$geojson->{features}} > 0, 'pelo menos uma feature presente';

  # Opcional: verifica estrutura da primeira feature
  my $first = $geojson->{features}[0];
  ok exists $first->{type}, 'feature tem type';
  ok exists $first->{geometry}, 'feature tem geometry';
  ok exists $first->{properties}, 'feature tem properties';
};

subtest 'OSM features: código existente sem dados OSM' => sub {
  my $cod = 1100020;   # município existente, mas sem dados OSM

  my $tx = $t->get_ok("/api/city/$cod/osm_features")->status_is(200)->tx;
  my $json = $tx->res->json;

  ok exists $json->{meta}, 'meta existe';
  ok exists $json->{geojson}, 'geojson existe';

  my $meta = $json->{meta};
  is $meta->{city_code}, $cod, 'city_code corresponde';
  is $meta->{type}, 'landuse', 'type é landuse';
  ok exists $meta->{generated_at}, 'generated_at presente';

  my $geojson = $json->{geojson};
  is $geojson->{type}, 'FeatureCollection', 'tipo GeoJSON é FeatureCollection';
  ok ref($geojson->{features}) eq 'ARRAY', 'features é um array';
  is @{$geojson->{features}}, 0, 'features está vazio (sem dados OSM)';
};

subtest 'OSM features: código inexistente (sem dados em nenhuma tabela)' => sub {
  my $cod = 9999999;   # código que não existe em lugar nenhum

  my $tx = $t->get_ok("/api/city/$cod/osm_features")->status_is(200)->tx;
  my $json = $tx->res->json;

  # Mesmo comportamento: meta + geojson vazio
  ok exists $json->{meta}, 'meta existe';
  ok exists $json->{geojson}, 'geojson existe';
  is $json->{meta}{city_code}, $cod, 'city_code corresponde';
  is $json->{meta}{type}, 'landuse', 'type é landuse';
  is $json->{geojson}{type}, 'FeatureCollection', 'tipo GeoJSON é FeatureCollection';
  is @{$json->{geojson}{features}}, 0, 'features vazio';
};

subtest 'OSM features: código com formato inválido (rota não casa)' => sub {
  $t->get_ok("/api/city/230270/osm_features")->status_is(404);   # 6 dígitos
  $t->get_ok("/api/city/23027010/osm_features")->status_is(404); # 8 dígitos
  $t->get_ok("/api/city/abc1234/osm_features")->status_is(404);  # não numérico
};

subtest 'payroll: código válido com ano/mês válidos' => sub {
  my $cod = 2302701;   # Campos Sales
  my $year = 2024;
  my $month = 6;

  my $tx = $t->get_ok("/api/city/$cod/payroll?year=$year&month=$month")->status_is(200)->tx;
  my $data = $tx->res->json;

  # Deve ser um array (pode estar vazio se não houver dados)
  ok ref($data) eq 'ARRAY', 'resposta é um array';

  if (@$data) {
    # Verifica estrutura do primeiro registro
    my $first = $data->[0];
    ok exists $first->{escola}, 'escola presente';
    ok exists $first->{mes}, 'mes presente';
    ok exists $first->{ano}, 'ano presente';
    ok exists $first->{total_professores}, 'total_professores presente';
    ok exists $first->{total_salarios}, 'total_salarios presente';
    is $first->{ano}, $year, 'ano corresponde';
    is $first->{mes}, ucfirst(DateTime->new(year => $year, month => $month)->month_name), 'mes corresponde';
  } else {
    pass 'array vazio (sem dados de folha)';
  }
};

subtest 'payroll: código válido sem parâmetros (default 2025/06)' => sub {
  my $cod = 2302701;

  my $tx = $t->get_ok("/api/city/$cod/payroll")->status_is(200)->tx;
  my $data = $tx->res->json;

  ok ref($data) eq 'ARRAY', 'resposta é um array';

  if (@$data) {
    my $first = $data->[0];
    is $first->{ano}, 2025, 'ano default 2025';
    is $first->{mes}, 'Junho', 'mês default junho';
  } else {
    pass 'array vazio';
  }
};

subtest 'payroll: ano inválido (não numérico)' => sub {
  my $cod = 2302701;
  $t->get_ok("/api/city/$cod/payroll?year=abcd")->status_is(400)
    ->content_like(qr/Bad request/);
};

subtest 'payroll: mês inválido (não numérico)' => sub {
  my $cod = 2302701;
  $t->get_ok("/api/city/$cod/payroll?month=xyz")->status_is(400)
    ->content_like(qr/Bad request/);
};

subtest 'payroll: mês inválido (fora do intervalo 1-12)' => sub {
  my $cod = 2302701;
  $t->get_ok("/api/city/$cod/payroll?month=13")->status_is(400);
};

subtest 'payroll: código existente sem dados de folha' => sub {
  my $cod = 3553807;   # município existente, mas sem folha (ou que não tenha)
  my $tx = $t->get_ok("/api/city/$cod/payroll")->status_is(200)->tx;
  my $data = $tx->res->json;
  ok ref($data) eq 'ARRAY', 'resposta é um array';
  is @$data, 0, 'array vazio (sem folha)';
};

subtest 'payroll: código inexistente (sem dados em nenhuma tabela)' => sub {
  my $cod = 9999999;
  my $tx = $t->get_ok("/api/city/$cod/payroll")->status_is(200)->tx;
  my $data = $tx->res->json;
  ok ref($data) eq 'ARRAY', 'resposta é um array';
  is @$data, 0, 'array vazio (cidade não existe)';
};

subtest 'payroll: código com formato inválido (rota não casa)' => sub {
  $t->get_ok("/api/city/230270/payroll")->status_is(404);   # 6 dígitos
  $t->get_ok("/api/city/23027010/payroll")->status_is(404); # 8 dígitos
  $t->get_ok("/api/city/abc1234/payroll")->status_is(404);  # não numérico
};

done_testing;
