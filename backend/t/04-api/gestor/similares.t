# t/04-api/gestor/similares.t
# Testes da API de escolas similares do gestor:
#   GET /api/gestor/:cod_inep/similares?scope=municipio|estado|regiao&limit=n
# A busca usa pgvector (<=> sobre vetor de características). O subteste de
# happy path só roda onde a extensão vector foi instalada (migration
# school_embedding); em ambientes sem ela é pulado.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $INEP = '11000040';

my $has_vector = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('analytics.school_embedding')"
);

sub get_similares {
  my (%args) = @_;
  my $q = '';
  $q .= build_query(%args) if %args;
  $t->get_ok("/api/gestor/$INEP/similares$q")->status_is(200)->tx->res->json;
}

sub build_query {
  my (%args) = @_;
  my @parts;
  push @parts, "scope=$args{scope}" if $args{scope};
  push @parts, "limit=$args{limit}" if defined $args{limit};
  return '?' . join('&', @parts);
}

subtest 'GET /api/gestor/:inep/similares: happy path (pgvector)' => sub {
  plan skip_all => 'analytics.school_embedding ausente (pgvector nao migrado)'
    unless $has_vector;

  my $json = get_similares();

  is $json->{escola_alvo}{id_escola}, $INEP, 'alvo identificado';
  ok length($json->{escola_alvo}{nome}) > 0, 'alvo: nome';

  is $json->{scope}, 'municipio', 'escopo padrão = município';
  is $json->{limit}, 10, 'limite padrão = 10';

  ok ref($json->{similares}) eq 'ARRAY', 'similares é array';
  ok scalar(@{ $json->{similares} }) > 0, 'retorna ao menos uma escola similar';

  my $alvo_muni = $json->{escola_alvo}{municipio};
  my $prev = 2;
  for my $s (@{ $json->{similares} }) {
    isnt $s->{id_escola}, $INEP, "não inclui a própria escola ($s->{id_escola})";
    ok length($s->{nome}) > 0, 'similar: nome presente';
    is $s->{municipio}, $alvo_muni, 'similar no mesmo município';
    ok defined $s->{similarity}, 'similar: similarity presente';
    ok $s->{similarity} >= 0 && $s->{similarity} <= 1, 'similarity em [0, 1]';
    cmp_ok $s->{similarity}, '<=', $prev, 'ordenado por similaridade desc';
    $prev = $s->{similarity};
  }
};

subtest 'escopo estado e região' => sub {
  plan skip_all => 'analytics.school_embedding ausente (pgvector nao migrado)'
    unless $has_vector;

  my $json = get_similares(scope => 'estado');
  is $json->{scope}, 'estado', 'escopo estado';
  ok scalar(@{ $json->{similares} }) > 0, 'retorna similares no estado';

  my $alvo_uf = $json->{escola_alvo}{uf};
  for my $s (@{ $json->{similares} }) {
    is $s->{uf}, $alvo_uf, "similar no mesmo estado ($s->{id_escola})";
  }

  my $regiao = get_similares(scope => 'regiao');
  is $regiao->{scope}, 'regiao', 'escopo região';
  ok ref($regiao->{similares}) eq 'ARRAY', 'similares região é array';
};

subtest 'validação de scope e limit' => sub {
  plan skip_all => 'analytics.school_embedding ausente (pgvector nao migrado)'
    unless $has_vector;

  my $invalid = get_similares(scope => 'pais');
  is $invalid->{scope}, 'municipio', 'scope desconhecido cai para município';

  my $small = get_similares(limit => 3);
  is $small->{limit}, 3, 'limit=3 respeitado';
  cmp_ok scalar(@{ $small->{similares} }), '<=', 3, 'no máximo 3 similares';

  my $big = get_similares(limit => 999);
  is $big->{limit}, 50, 'limit>50 é limitado a 50';
};

subtest 'erros' => sub {
  $t->get_ok("/api/gestor/99999999/similares")->status_is(404);
  $t->get_ok('/api/gestor/123/similares')->status_is(404);
};

done_testing();