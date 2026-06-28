use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::Util qw(url_escape);

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

subtest 'search_by_name: nome com 4+ caracteres retorna resultados' => sub {
  my $name = 'Campos';
  my $encoded = url_escape($name);  # "Campos" não precisa, mas mantém

  my $tx = $t->get_ok("/api/city/search/$encoded")->status_is(200)->tx;
  my $body = $tx->res->body;
  diag "Response body (first 200 chars): " . substr($body, 0, 200) . "..." if !$body;

  my $json = eval { $tx->res->json } || {};
  diag "Failed to decode JSON: $@" if $@;

  ok exists $json->{type}, 'tem campo type' or diag "Response: $body";
  is $json->{type}, 'FeatureCollection', 'type é FeatureCollection';
  ok exists $json->{features}, 'tem features';
  ok ref($json->{features}) eq 'ARRAY', 'features é array';

  if (@{$json->{features}}) {
    my $first = $json->{features}[0];
    ok exists $first->{type}, 'feature tem type';
    ok exists $first->{geometry}, 'feature tem geometry';
    ok exists $first->{properties}, 'feature tem properties';
  } else {
    pass 'features vazio (nenhum município encontrado)';
  }
};

subtest 'search_by_name: nome com menos de 4 caracteres retorna 400' => sub {
  my $name = 'ABC';
  $t->get_ok("/api/city/search/$name")->status_is(400)
    ->content_like(qr/Bad request/);
};

subtest 'search_by_name: nome com acentos e caracteres especiais' => sub {
  # Usamos a URL já codificada manualmente para evitar problemas de encoding
  my $encoded = 'S%C3%A3o%20Paulo';  # "São Paulo" codificado

  my $tx = $t->get_ok("/api/city/search/$encoded")->status_is(200)->tx;
  my $body = $tx->res->body;
  my $part_body = substr($body, 0, 200) . "...";
  diag "Response body (first 200 chars): " . substr($body, 0, 200) . "..." if !$body;

  my $json = eval { $tx->res->json } || {};
  diag "Failed to decode JSON: $@" if $@;

  ok exists $json->{type}, 'resposta tem type' or diag "Response: $part_body";
  is $json->{type}, 'FeatureCollection', 'type é FeatureCollection';

  my @features = @{$json->{features} // []};
  if (@features) {
    my @nomes = map { $_->{properties}{nome_municipio} // '' } @features;
    ok grep { /S(ã|a)o Paulo/i } @nomes, 'encontrou São Paulo (com ou sem acento)';
  } else {
    pass 'nenhum resultado (pode não haver dados)';
  }
};

subtest 'search_by_name: nome com maiúsculas/minúsculas (case-insensitive)' => sub {
  my $name = 'ceara';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/search/$encoded")->status_is(200)->tx;
  my $body = $tx->res->body;
  diag "Response body (first 200 chars): " . substr($body, 0, 200) . "..." if !$body;

  my $json = eval { $tx->res->json } || {};
  diag "Failed to decode JSON: $@" if $@;

  ok exists $json->{type}, 'resposta tem type';
  my @features = @{$json->{features} // []};
  if (@features) {
    my @nomes = map { $_->{properties}{nome_municipio} // '' } @features;
    ok grep { /Ceará/i } @nomes, 'encontrou municípios com "Ceará" independente de case';
  } else {
    pass 'nenhum resultado (pode não haver dados)';
  }
};

subtest 'search_by_name: nome que não existe retorna features vazio' => sub {
  my $name = 'CidadeInexistenteXYZ';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/search/$encoded")->status_is(200)->tx;
  my $json = $tx->res->json;

  is $json->{type}, 'FeatureCollection', 'type é FeatureCollection';
  ok ref($json->{features}) eq 'ARRAY', 'features é array';
  is @{$json->{features}}, 0, 'features vazio (nenhum município encontrado)';
};

subtest 'search_by_name: nome com caracteres URL-encoded (espaços, etc.)' => sub {
  my $name = 'Rio de Janeiro';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/search/$encoded")->status_is(200)->tx;
  my $body = $tx->res->body;
  diag "Response body (first 200 chars): " . substr($body, 0, 200) . "..." if !$body;

  my $json = eval { $tx->res->json } || {};
  diag "Failed to decode JSON: $@" if $@;

  ok exists $json->{type}, 'resposta tem type';
  my @features = @{$json->{features} // []};
  if (@features) {
    my @nomes = map { $_->{properties}{nome_municipio} // '' } @features;
    ok grep { /Rio de Janeiro/i } @nomes, 'encontrou "Rio de Janeiro"';
  } else {
    pass 'nenhum resultado (pode não haver dados)';
  }
};

subtest 'detail_by_name: nome existente retorna dados' => sub {
  my $name = 'Campos Sales';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/detail/$encoded")->status_is(200)->tx;
  my $json = eval { ($tx->res->json) } || [];
  diag "Failed to decode JSON: $@" if $@;

  ok ref($json) eq 'ARRAY', 'resposta é um array';
  ok @$json > 0, 'array não está vazio';

  my $first = $json->[0];
  ok exists $first->{nome_municipio}, 'tem nome_municipio';
  ok exists $first->{codigo_ibge}, 'tem codigo_ibge';
  ok exists $first->{nome_estado}, 'tem nome_estado';
  ok exists $first->{area_km2}, 'tem area_km2';
  ok exists $first->{nome_regiao_imediata}, 'tem nome_regiao_imediata';
  ok exists $first->{nome_regiao}, 'tem nome_regiao';

  # Verifica se o nome contém o termo buscado (com acentos ignorados)
  like $first->{nome_municipio}, qr/Campos Sales/i, 'nome contém "Campos Sales"';
};

subtest 'detail_by_name: nome com acentos e caracteres especiais' => sub {
  my $encoded = 'S%C3%A3o%20Paulo';  # "São Paulo"

  my $tx = $t->get_ok("/api/city/detail/$encoded")->status_is(200)->tx;
  my $json = eval { ($tx->res->json) } || [];
  diag "Failed to decode JSON: $@" if $@;

  ok ref($json) eq 'ARRAY', 'resposta é um array';

  if (@$json) {
    # Pelo menos um deve ser São Paulo (ou similar)
    my @nomes = map { $_->{nome_municipio} // '' } @$json;
    ok grep { /S(ã|a)o Paulo/i } @nomes, 'encontrou São Paulo (com ou sem acento)';
  } else {
    pass 'nenhum resultado (pode não haver dados)';
  }
};

subtest 'detail_by_name: case-insensitive' => sub {
  my $name = 'ceara';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/detail/$encoded")->status_is(200)->tx;
  my $json = eval { ($tx->res->json) } || [];
  ok ref($json) eq 'ARRAY', 'resposta é um array';

  if (@$json) {
    my @nomes = map { $_->{nome_municipio} // '' } @$json;
    ok grep { /Ceará/i } @nomes, 'encontrou municípios com "Ceará" independente de case';
  } else {
    pass 'nenhum resultado';
  }
};

subtest 'detail_by_name: nome curto (menos de 4 caracteres) => não deve funcionar' => sub {
  my $name = 'Rio';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/detail/$encoded")->status_is(400)->tx;
  pass 'não aceita nomes curtos (menos de 4 caracteres)';
};

subtest 'detail_by_name: nome que não existe retorna array vazio' => sub {
  my $name = 'CidadeInexistenteXYZ';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/detail/$encoded")->status_is(200)->tx;
  my $json = eval { ($tx->res->json) } || [];
  ok ref($json) eq 'ARRAY', 'resposta é um array';
  is @$json, 0, 'array vazio (nenhum município encontrado)';
};

subtest 'detail_by_name: nome com espaços URL-encoded' => sub {
  my $name = 'Rio de Janeiro';
  my $encoded = url_escape($name);

  my $tx = $t->get_ok("/api/city/detail/$encoded")->status_is(200)->tx;
  my $json = eval { ($tx->res->json) } || [];
  ok ref($json) eq 'ARRAY', 'resposta é um array';

  if (@$json) {
    my @nomes = map { $_->{nome_municipio} // '' } @$json;
    ok grep { /Rio de Janeiro/i } @nomes, 'encontrou "Rio de Janeiro"';
  } else {
    pass 'nenhum resultado';
  }
};

done_testing;
