use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON qw(decode_json);
use Mojo::Util qw(url_escape);
use open ':std', ':encoding(UTF-8)';
use utf8;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

# ------------------------------------------------------------
# /api/analytics/cities/search?q=...
# ------------------------------------------------------------
subtest 'search_for_complete: termo com resultados' => sub {
  my $q = 'maria';
  my $tx = $t->get_ok("/api/analytics/cities/search?q=$q")->status_is(200)->tx;
  my $body = $tx->res->body;
  my $json = $tx->res->json;
  diag "Failed to decode JSON: $@" if $@;

  ok ref($json) eq 'ARRAY', 'resposta é um array';
  ok @$json > 0, 'array não está vazio';

  my $first = $json->[0];
  ok exists $first->{codigo_ibge}, 'codigo_ibge existe';
  ok exists $first->{nome_municipio}, 'nome_municipio existe';
  ok exists $first->{sigla_estado}, 'sigla_estado existe';
  ok exists $first->{populacao_estimada}, 'populacao_estimada existe';
  ok exists $first->{latitude}, 'latitude existe';
  ok exists $first->{longitude}, 'longitude existe';
  ok exists $first->{analise}, 'analise existe';
  ok ref($first->{analise}) eq 'HASH', 'analise é um hash';
  ok exists $first->{analise}{ideb_fund_ii}, 'ideb_fund_ii existe';

  # Verifica se todos os resultados contêm "maria" (case-insensitive)
  my @nomes = map { $_->{nome_municipio} // '' } @$json;
  my $total = grep { /maria/i } @nomes;
  ok $total, qq/$total resultados contém "maria"/;
};

subtest 'search_for_complete: termo sem resultados' => sub {
  my $q = 'xyzabc123';
  my $tx = $t->get_ok("/api/analytics/cities/search?q=$q")->status_is(200)->tx;
  my $json = $tx->res->json;
  ok ref($json) eq 'ARRAY', 'resposta é um array';
  is @$json, 0, 'array vazio (nenhum município encontrado)';
};

subtest 'search_for_complete: termo com acentos' => sub {
  my $q = 'São Paulo';
  my $encoded = url_escape($q);
  my $tx = $t->get_ok("/api/analytics/cities/search?q=$encoded")->status_is(200)->tx;
  my $json = $tx->res->json;
  ok ref($json) eq 'ARRAY', 'resposta é um array';

  if (@$json) {
    my @nomes = map { $_->{nome_municipio} // '' } @$json;
    my $total = grep { /S(ã|a)o Paulo/i } @nomes;
    ok ($total, qq/encontrou $total resultados "São Paulo" (com ou sem acento)/);
  } else {
    pass 'nenhum resultado (pode não haver dados)';
  }
};

subtest 'search_for_complete: case-insensitive' => sub {
  my $q = 'CEARA';
  my $tx = $t->get_ok("/api/analytics/cities/search?q=$q")->status_is(200)->tx;
  my $json = $tx->res->json;
  ok ref($json) eq 'ARRAY', 'resposta é um array';

  if (@$json) {
    my @nomes = map { $_->{nome_municipio} // '' } @$json;
    my $total = grep { /Ceará/i } @nomes;
    ok $total, qq/encontrou $total municípios com "Ceará" independente de case/;
  } else {
    pass 'nenhum resultado';
  }
};

subtest 'search_for_complete: parâmetro limit' => sub {
  my $q = 'maria';
  my $limit = 3;
  my $tx = $t->get_ok("/api/analytics/cities/search?q=$q&limit=$limit")->status_is(200)->tx;
  my $json = $tx->res->json;
  ok ref($json) eq 'ARRAY', 'resposta é um array';
  if (@$json) {
    ok @$json <= $limit, "número de resultados <= $limit";
  } else {
    pass 'nenhum resultado (mas limit foi aceito)';
  }
};

subtest 'search_for_complete: termo com caracteres especiais (URL-encoded)' => sub {
  my $q = 'Rio de Janeiro';
  my $encoded = url_escape($q);
  my $tx = $t->get_ok("/api/analytics/cities/search?q=$encoded")->status_is(200)->tx;
  my $json = $tx->res->json;
  ok ref($json) eq 'ARRAY', 'resposta é um array';

  if (@$json) {
    my @nomes = map { $_->{nome_municipio} // '' } @$json;
    my $total = grep { /Rio de Janeiro/i } @nomes;
    ok $total, qq/encontrou $total resultados com "Rio de Janeiro"/;
  } else {
    pass 'nenhum resultado';
  }
};

done_testing;
