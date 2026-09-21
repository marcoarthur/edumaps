# t/04-api/gestor/finance_siope.t
# Testes do disparo assíncrono do SIOPE pelo painel financeiro (rede municipal).
#   Exige sessão do gestor da escola; só a rede municipal tem dados; não
#   permite baixar ano já presente (por município); faixa 2020..ano atual.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use DateTime;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $minion = $t->app->minion;

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.remuneracao_municipal')"
);

my $INEP_MUN = '77777750';   # municipal
my $INEP_EST = '66666640';   # estadual
my $MUN      = substr($INEP_MUN, 0, 6);  # código antigo do município
my $SENHA    = 'senha123';
my $EMAIL    = sprintf 'fin.a.%d@edumaps.test', $$;
my $OEMAIL   = sprintf 'fin.b.%d@edumaps.test', $$;
my $ANO_OK   = DateTime->now->year - 1;

my ($token, $out_token);

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  for my $inep ($INEP_MUN, $INEP_EST) {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia)
            VALUES (2025, ?, ?, 3)', {}, $INEP_MUN, 'Escola Municipal SIOPE');
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia)
            VALUES (2025, ?, ?, 2)', {}, $INEP_EST, 'Escola Estadual SIOPE');
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  for my $email ($EMAIL, $OEMAIL) {
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $email);
  }
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  for my $inep ($INEP_MUN, $INEP_EST) {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
}

my $auth  = sub { { Authorization => "Bearer $token" } };
my $oauth = sub { { Authorization => "Bearer $out_token" } };

subtest 'setup: gestor municipal + gestor estadual' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_MUN, nome => 'Gestor Municipal', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_EST, nome => 'Gestor Estadual', email => $OEMAIL, senha => $SENHA,
  })->status_is(200);
  $out_token = $t->post_ok('/api/gestor/login', json => { email => $OEMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};

  ok $token && $out_token, 'tokens de sessão';
};

subtest 'finance: metadados do SIOPE (municipal x estadual)' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  my $mun = $t->get_ok("/api/school/$INEP_MUN/finance")
    ->status_is(200)->tx->res->json;
  is $mun->{siope}{habilitado}, 1, 'municipal: SIOPE habilitado';
  is $mun->{siope}{cod_municipio}, $MUN, 'código do município derivado do INEP';
  is $mun->{siope}{ano_inicial}, 2020, 'faixa inicia em 2020';
  is $mun->{escola}{dependencia_administrativa}, 'Municipal', 'rede na resposta';

  my $est = $t->get_ok("/api/school/$INEP_EST/finance")
    ->status_is(200)->tx->res->json;
  is $est->{siope}{habilitado}, 0, 'estadual: SIOPE oculto';
};

subtest 'disparo: exige sessão e é restrito à rede municipal' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok("/api/gestor/$INEP_MUN/financeiro/siope", json => { ano => $ANO_OK })
    ->status_is(401);

  # gestor de outra escola não dispara na escola alheia
  $t->post_ok("/api/gestor/$INEP_MUN/financeiro/siope", $oauth->(), json => { ano => $ANO_OK })
    ->status_is(403);

  # estadual: sem SIOPE
  $t->post_ok("/api/gestor/$INEP_EST/financeiro/siope", $oauth->(), json => { ano => $ANO_OK })
    ->status_is(422)->json_has('/error');
};

subtest 'disparo: municipal enfileira a task query_siope' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  my $tx = $t->post_ok("/api/gestor/$INEP_MUN/financeiro/siope", $auth->(), json => { ano => $ANO_OK })
    ->status_is(202)
    ->header_like(Location => qr/progress\?job_id=\d+/)
    ->json_has('/job_id');

  my $job_id = $tx->tx->res->json->{job_id};
  my $job = $minion->job($job_id);
  is $job->task, 'query_siope', 'task correta enfileirada';
  ok $minion->backend->remove_job($job_id), "job $job_id removido";
};

subtest 'disparo: validações (ano fora da faixa e ano já presente)' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  # ano fora de 2020..atual
  $t->post_ok("/api/gestor/$INEP_MUN/financeiro/siope", $auth->(), json => { ano => 2010 })
    ->status_is(400)->json_has('/error');

  # ano já presente para o município -> 409
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('INSERT INTO clean.remuneracao_municipal (ano, cod_municipio, cod_inep, rede)
            VALUES (?, ?, ?, ?)', {}, '2023', $MUN, $INEP_MUN, 'Municipal');

  $t->post_ok("/api/gestor/$INEP_MUN/financeiro/siope", $auth->(), json => { ano => 2023 })
    ->status_is(409)->json_has('/error');

  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
};

done_testing;
