# t/04-api/gestor/influencia.t
# Testes da API da área de influência da escola (#255/#137):
#   GET /api/gestor/:cod_inep/influencia  (somente leitura da camada)
#
# A camada clean.escola_influencia é materializada pelo job refresh_influencia
# (clean.refresh_escola_influencia); aqui ela é materializada direto no banco
# para a escola de teste.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_table = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.escola_influencia')"
);

# INEPs sintéticos (8 dígitos, ausentes da base) para não tocar dados reais:
# todo o teste é criação -> leitura -> limpeza do que ele mesmo criou.
my $INEP   = '99000001';   # escola de teste
my $OUTRO  = '99000002';   # outra escola (gestor de fora)
my $SENHA  = 'senha123';
my $EMAIL  = sprintf 'infl.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'infl.b.%d@edumaps.test', $$;

my ($token, $out_token);

my $setup_school = sub {
  my ($inep) = @_;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  $dbh->do(q{
    INSERT INTO clean.censo_escolas
      (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, latitude, longitude, geometry)
    VALUES (2025, ?, ?, 3, 2307304, -23.5, -46.6,
            ST_SetSRID(ST_MakePoint(-46.6, -23.5), 4674))
  }, {}, $inep, "Escola Influência $inep");
};

my $cleanup = sub {
  eval {
    my $dbh = $t->app->schema->storage->dbh;
    $dbh->do('DELETE FROM clean.escola_influencia WHERE co_entidade IN (?, ?)', {}, $INEP, $OUTRO)
      if $has_table;
    # sessões/telemetria e contas criadas pelo perfil/login de teste
    my $sub = 'SELECT id FROM clean.gestores WHERE email IN (?, ?)';
    $dbh->do("DELETE FROM clean.session_tracking WHERE gestor_id IN ($sub)", {}, $EMAIL, $OEMAIL);
    $dbh->do("DELETE FROM clean.sessoes WHERE gestor_id IN ($sub)", {}, $EMAIL, $OEMAIL);
    $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $EMAIL, $OEMAIL);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?) AND nu_ano_censo = 2025', {}, $INEP, $OUTRO);
  };
};

END { $cleanup->() }

$setup_school->($INEP);
$setup_school->($OUTRO);

subtest 'setup: gestores das escolas' => sub {
  plan skip_all => 'clean.escola_influencia ausente (migration nao aplicada)'
    unless $has_table;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Influência', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRO, nome => 'Gestor Outro', email => $OEMAIL, senha => $SENHA,
  })->status_is(200);
  $out_token = $t->post_ok('/api/gestor/login', json => { email => $OEMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};

  ok $token && $out_token, 'tokens de sessão';
};

subtest 'GET: exige sessão e é restrito à própria escola' => sub {
  plan skip_all => 'sem tabela' unless $has_table;

  $t->get_ok("/api/gestor/$INEP/influencia")->status_is(401);
  $t->get_ok("/api/gestor/$INEP/influencia",
    { Authorization => "Bearer $out_token" })->status_is(403);
};

subtest 'GET: 404 quando a escola ainda não foi materializada' => sub {
  plan skip_all => 'sem tabela' unless $has_table;

  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.escola_influencia WHERE co_entidade = ?', {}, $INEP);

  $t->get_ok("/api/gestor/$INEP/influencia", { Authorization => "Bearer $token" })
    ->status_is(404)->json_like('/error' => qr/não calculada|calculada/i);
};

subtest 'GET: metadados + GeoJSON dos buffers' => sub {
  plan skip_all => 'sem tabela' unless $has_table;

  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('SELECT clean.refresh_escola_influencia(?::integer[], ?::bigint[])',
    {}, '{500,1000,2000}', '{' . $INEP . '}');

  my $json = $t->get_ok("/api/gestor/$INEP/influencia", { Authorization => "Bearer $token" })
    ->status_is(200)->tx->res->json;

  is $json->{co_entidade}, $INEP + 0, 'escola correta';
  is $json->{nu_ano_censo}, 2025, 'ano do censo';
  is $json->{tier}, 'buffer', 'tier buffer';
  is $json->{versao}, 'influencia-v1', 'versão da metodologia';
  ok $json->{computado_em}, 'carimbo de cálculo';
  is $json->{raios}, [500, 1000, 2000], 'três raios materializados';

  is $json->{escola}{nome}, "Escola Influência $INEP", 'nome da escola';
  is $json->{escola}{latitude}, -23.5, 'latitude da escola';

  is $json->{geojson}{type}, 'FeatureCollection', 'tipo do GeoJSON';
  is scalar(@{ $json->{geojson}{features} }), 3, 'três feições no mapa';

  my $f0 = $json->{geojson}{features}[0];
  is $f0->{geometry}{type}, 'Polygon', 'geometria é polígono (a camada real)';
  is $f0->{properties}{raio_m}, 500, 'primeiro raio = 500 m (ordenado)';
  is $f0->{properties}{tier}, 'buffer', 'tier na feição';
  ok( ($f0->{properties}{area_km2} // 0) > 0.7 && $f0->{properties}{area_km2} < 0.79,
    "área do buffer de 500 m (~0.785 km²): $f0->{properties}{area_km2}" );
};

subtest 'GET: sem vazamento de outra escola (IDOR)' => sub {
  plan skip_all => 'sem tabela' unless $has_table;

  # materializa a OUTRA escola e confirma que ela não aparece na resposta da INEP
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('SELECT clean.refresh_escola_influencia(?::integer[], ?::bigint[])',
    {}, '{500}', '{' . $OUTRO . '}');

  my $json = $t->get_ok("/api/gestor/$INEP/influencia", { Authorization => "Bearer $token" })
    ->status_is(200)->tx->res->json;
  is scalar(@{ $json->{geojson}{features} }), 3, 'só as feições da própria escola';
};

done_testing;
