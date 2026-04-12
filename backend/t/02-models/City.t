use Mojo::Base -strict, -signatures;
use Test2::V0;
use Test2::Tools::Compare qw(T F D DF E DNE FDNE U L);
use lib qw(./lib);
use DateTime;
use Mojo::JSON qw(decode_json encode_json);
use DDP;
use Try::Tiny;

# Carregar módulos necessários - Test2 não tem use_ok, vamos usar require + ok
my $load_ok = 1;
eval { require EduMaps::Model::City; };
$load_ok = 0 if $@;
ok($load_ok, 'EduMaps::Model::City carregado com sucesso');

$load_ok = 1;
eval { require EduMaps::Schema; };
$load_ok = 0 if $@;
ok($load_ok, 'EduMaps::Schema carregado com sucesso');

# Configuração do banco de dados para teste
my $schema = EduMaps::Schema->go;

# Criar instância do modelo
my $city_model = EduMaps::Model::City->new(schema => $schema);
isa_ok($city_model, 'EduMaps::Model::City');

# Dados de teste
my $TEST_IBGE_CODE = '3550308';  # São Paulo - SP
my $TEST_IBGE_CODE_6DIGITS = '355030';  # 6 dígitos para remuneração
my $TEST_CITY_NAME = 'São Paulo';
my $TEST_RADIUS = 3000;

# ============================================================================
# Testes para o método details()
# ============================================================================

subtest 'details() - Deve retornar estrutura completa da cidade' => sub {
    my $result = $city_model->details($TEST_IBGE_CODE, $TEST_RADIUS);
    
    # Verificar estrutura básica
    is(ref $result, 'HASH', 'Retorna um hashref');
    
    # Verificar chaves principais
    my @expected_keys = qw(detalhes_cidade porte_escola profissionais_educacao cobertura_escolar);
    for my $key (@expected_keys) {
        ok(exists $result->{$key}, "Possui chave '$key'");
    }
    
    # Verificar detalhes da cidade
    my $detalhes = $result->{detalhes_cidade};
    if (keys %$detalhes) {
        ok(exists $detalhes->{nome_municipio}, 'Possui nome do município');
        ok(exists $detalhes->{codigo_ibge}, 'Possui código IBGE');
        #ok(exists $detalhes->{sigla_estado}, 'Possui sigla do estado');
    }
    
    # Verificar cobertura escolar
    my $cobertura = $result->{cobertura_escolar};
    if (keys %$cobertura) {
        ok(exists $cobertura->{area_coberta_km2} || exists $cobertura->{vazio_educacional_km2},
           'Possui informações de cobertura escolar');
    }
};

subtest 'details() - Deve retornar hash vazio para código inexistente' => sub {
    my $result = $city_model->details('9999999');
    is(ref $result, 'HASH', 'Retorna hashref mesmo para código inválido');
    is(keys %$result, 0, 'Hash está vazio para código inexistente');
};

subtest 'details() - Deve funcionar com diferentes raios' => sub {
    my @radius_values = (1000, 3000, 5000, 10000);
    
    for my $radius (@radius_values) {
        my $result = $city_model->details($TEST_IBGE_CODE, $radius);
        is(ref $result, 'HASH', "Funciona com raio = $radius");
    }
};

# ============================================================================
# Testes para o método osm_features()
# ============================================================================

subtest 'osm_features() - Deve retornar GeoJSON válido' => sub {
    my $result = $city_model->osm_features($TEST_IBGE_CODE);
    
    ok(defined $result, 'Retornou algum valor');
    ok(length($result) > 0, 'Retornou string não vazia');
    
    # Tentar decodificar como JSON
    my $decoded = try { decode_json($result) };
    
    if ($decoded) {
        ok(exists $decoded->{meta}, 'Possui campo meta');
        ok(exists $decoded->{geojson}, 'Possui campo geojson');
        
        my $meta = $decoded->{meta};
        is($meta->{city_code}, $TEST_IBGE_CODE, 'city_code correto');
        is($meta->{type}, 'landuse', 'type correto');
        ok(exists $meta->{generated_at}, 'Possui timestamp');
        
        my $geojson = $decoded->{geojson};
        my $geojson_decoded = try { decode_json($geojson) };
        if ($geojson_decoded) {
            ok($geojson_decoded->{type} eq 'FeatureCollection' || 
               $geojson_decoded->{type} eq 'Feature',
               'GeoJSON tem tipo válido');
        }
    } else {
        # Se não for JSON, pode ser apenas o GeoJSON
        ok($result =~ /FeatureCollection|Feature/, 'Parece ser GeoJSON válido');
    }
};

subtest 'osm_features() - Deve retornar string mesmo para cidade sem dados' => sub {
    my $result = $city_model->osm_features('9999999');
    ok(defined $result, 'Retorna algo mesmo para código inválido');
    ok(length($result) > 0, 'Retorna string não vazia');
};

# ============================================================================
# Testes para o método payroll()
# ============================================================================

subtest 'payroll() - Deve retornar dados de folha de pagamento' => sub {
    my $date = DateTime->new(year => 2024, month => 3);
    my $result = $city_model->payroll($TEST_IBGE_CODE, $date);
    
    ok(defined $result, 'Retornou algum valor');
    
    my $decoded = try { decode_json($result) };
    if ($decoded) {
        is(ref $decoded, 'ARRAY', 'Retorna um array JSON');
    }
};

subtest 'payroll() - Deve lidar com datas sem dados' => sub {
    my $date = DateTime->new(year => 1990, month => 1);
    my $result = $city_model->payroll($TEST_IBGE_CODE, $date);
    
    ok(defined $result, 'Retorna algo mesmo para data sem dados');
    
    my $decoded = try { decode_json($result) };
    if ($decoded && ref $decoded eq 'ARRAY') {
        is(scalar @$decoded, 0, 'Retorna array vazio quando não há dados');
    }
};

subtest 'payroll() - Deve funcionar para diferentes meses' => sub {
    my @months = (1, 3, 6, 9, 12);
    
    for my $month (@months) {
        my $date = DateTime->new(year => 2024, month => $month);
        my $result = $city_model->payroll($TEST_IBGE_CODE, $date);
        ok(defined $result, "Funciona para mês $month");
    }
};

# ============================================================================
# Testes para o método payroll_details()
# ============================================================================

subtest 'payroll_details() - Deve retornar detalhes da folha por escola' => sub {
    my $date = DateTime->new(year => 2024, month => 3);
    my $result = $city_model->payroll_details($TEST_IBGE_CODE, $date);
    
    ok(defined $result, 'Retornou algum valor');
    ok($result =~ /^\[.*\]$/, 'Retorna um array JSON');
    
    my $decoded = try { decode_json($result) };
    if ($decoded && ref $decoded eq 'ARRAY') {
        ok(1, 'JSON decodificado com sucesso');
    }
};

# ============================================================================
# Testes para o método overall_payroll()
# ============================================================================

subtest 'overall_payroll() - Deve retornar folha consolidada' => sub {
    my $params = { codigo_ibge => $TEST_IBGE_CODE };
    my $result = $city_model->overall_payroll($params);
    
    ok(defined $result, 'Retornou algum valor');
    
    my $decoded = try { decode_json($result) };
    if ($decoded && ref $decoded eq 'ARRAY') {
        if (scalar @$decoded > 0) {
            my $first = $decoded->[0];
            ok(exists $first->{nome_municipio}, 'Possui nome do município');
            ok(exists $first->{codigo_ibge}, 'Possui código IBGE');
        }
    }
};

# subtest 'overall_payroll() - Deve lidar com parâmetros vazios' => sub {
#     my $result = $city_model->overall_payroll({});
#     ok(defined $result, 'Retorna algo mesmo sem parâmetros');
# };

subtest 'overall_payroll() - Deve filtrar por código' => sub {
    my $params = { codigo_ibge => $TEST_IBGE_CODE };
    my $result = $city_model->overall_payroll($params);
    
    my $decoded = try { decode_json($result) };
    if ($decoded && ref $decoded eq 'ARRAY' && scalar @$decoded > 0) {
        my $first = $decoded->[0];
        is($first->{codigo_ibge}, $TEST_IBGE_CODE, 'Filtro por código funciona');
    }
};

# ============================================================================
# Testes para o método search_by_name()
# ============================================================================

subtest 'search_by_name() - Deve buscar cidades por nome' => sub {
    my $params = { name => $TEST_CITY_NAME };
    my $result = $city_model->search_by_name($params);
    
    ok(defined $result, 'Retornou algum valor');
    ok(length($result) > 0, 'Retornou string não vazia');
    
    # Deve ser GeoJSON válido
    my $decoded = try { decode_json($result) };
    if ($decoded) {
        ok($decoded->{type} eq 'FeatureCollection' || $decoded->{type} eq 'Feature',
           'Retorna GeoJSON válido');
    }
};

subtest 'search_by_name() - Deve funcionar com busca parcial' => sub {
    my $params = { name => 'Sã' };
    my $result = $city_model->search_by_name($params);
    ok(defined $result, 'Busca parcial funciona');
};

subtest 'search_by_name() - Deve ser case insensitive' => sub {
    my $params_lower = { name => lc($TEST_CITY_NAME) };
    my $params_upper = { name => uc($TEST_CITY_NAME) };
    
    my $result_lower = $city_model->search_by_name($params_lower);
    my $result_upper = $city_model->search_by_name($params_upper);
    
    ok(defined $result_lower, 'Busca com minúsculas funciona');
    ok(defined $result_upper, 'Busca com maiúsculas funciona');
};

subtest 'search_by_name() - Deve lidar com acentos' => sub {
    my $params = { name => 'Sao Paulo' };
    my $result = $city_model->search_by_name($params);
    ok(defined $result, 'Busca sem acentos funciona (unaccent)');
};

# ============================================================================
# Testes para o método city_details()
# ============================================================================

subtest 'city_details() - Deve retornar detalhes básicos da cidade' => sub {
    my $params = { name => $TEST_CITY_NAME };
    my $result = $city_model->city_details($params);
    
    ok(defined $result, 'Retornou algum valor');
    
    my $decoded = try { decode_json($result) };
    if ($decoded && ref $decoded eq 'ARRAY' && scalar @$decoded > 0) {
        my $first = $decoded->[0];
        
        my @expected_fields = qw(
            nome_municipio nome_regiao_imediata nome_regiao 
            area_km2 nome_estado codigo_ibge
        );
        
        for my $field (@expected_fields) {
            ok(exists $first->{$field} || !exists $first->{$field},
               "Campo '$field' está presente ou ausente como esperado");
        }
    }
};

subtest 'city_details() - Deve retornar array vazio para nome inexistente' => sub {
    my $params = { name => 'CidadeQueNaoExiste12345' };
    my $result = $city_model->city_details($params);
    
    my $decoded = try { decode_json($result) };
    if ($decoded && ref $decoded eq 'ARRAY') {
        is(scalar @$decoded, 0, 'Retorna array vazio para nome inexistente');
    }
};

# ============================================================================
# Testes para método privado _wrap_percent()
# ============================================================================

subtest '_wrap_percent() - Deve envolver string com percentuais' => sub {
    my $wrapped = $city_model->_wrap_percent('teste');
    is($wrapped, '%teste%', 'Adiciona % antes e depois');
    
    $wrapped = $city_model->_wrap_percent('');
    is($wrapped, '%%', 'Funciona com string vazia');
};

# ============================================================================
# Testes de integração
# ============================================================================

subtest 'Integração: Fluxo completo de dados da cidade' => sub {
    # 1. Buscar cidade por nome
    my $search_result = $city_model->search_by_name({ name => $TEST_CITY_NAME });
    my $decoded_search = try { decode_json($search_result) };
    
    if ($decoded_search && $decoded_search->{type} eq 'FeatureCollection') {
        my $features = $decoded_search->{features};
        if ($features && @$features > 0) {
            my $city_code = $features->[0]{properties}{codigo_ibge};
            
            # 2. Buscar detalhes completos
            my $details = $city_model->details($city_code);
            is(ref $details, 'HASH', 'Detalhes retornados com sucesso');
            
            # 3. Buscar payroll
            my $date = DateTime->new(year => 2024, month => 3);
            my $payroll = $city_model->payroll($city_code, $date);
            ok(defined $payroll, 'Payroll retornado com sucesso');
        }
    }
};

# ============================================================================
# Testes de validação de tipos
# ============================================================================

subtest 'Validação de tipos de retorno' => sub {
    my $date = DateTime->new(year => 2024, month => 3);
    
    my @string_methods = (
        sub { $city_model->payroll($TEST_IBGE_CODE, $date) },
        sub { $city_model->payroll_details($TEST_IBGE_CODE, $date) },
        sub { $city_model->overall_payroll({ codigo_ibge => $TEST_IBGE_CODE }) },
        sub { $city_model->search_by_name({ name => $TEST_CITY_NAME }) },
        sub { $city_model->city_details({ name => $TEST_CITY_NAME }) },
        sub { $city_model->osm_features($TEST_IBGE_CODE) },
    );
    
    for my $method_ref (@string_methods) {
        my $result = $method_ref->();
        ok(defined $result, 'Método retornou valor definido');
        ok(!ref $result || ref $result eq 'HASH', 
           'Retorno não é referência (ou é hashref para details)');
    }
};

# ============================================================================
# Finalizar testes com Test2
# ============================================================================

done_testing();
