# t/04-api/gestor/relatorios_salvos.t
# Assistente de Relatório (#219) — Fase 3, relatórios salvos do gestor:
#   POST   /api/gestor/:cod_inep/relatorios/salvos      {job_id}
#   GET    /api/gestor/:cod_inep/relatorios/salvos      ?page&per_page
#   GET    /api/gestor/:cod_inep/relatorios/salvos/:id
#   DELETE /api/gestor/:cod_inep/relatorios/salvos/:id
# Os jobs relatorio_gerar são criados direto no Minion (fila dedicada) e
# terminados à mão: o conteúdo salvo tem de vir do resultado do job.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $minion = $t->app->minion;
my $dbh    = $t->app->schema->storage->dbh;
my $FILA   = 'relatorio_salvos_test';

my $INEP  = '77770082';
my $OUTRO = '66660082';
my $SENHA = 'senha123';
my $EMAIL  = sprintf 'rels.a.%d@edumaps.test', $$;
my $CEMAIL = sprintf 'rels.c.%d@edumaps.test', $$;   # colega: mesma escola
my $OEMAIL = sprintf 'rels.b.%d@edumaps.test', $$;   # outra escola

my $cleanup = sub {
  $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE queue = ?}, $FILA);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $_) for $EMAIL, $CEMAIL, $OEMAIL;
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $_) for $INEP, $OUTRO;
};
$cleanup->();
END { $cleanup->() }

$dbh->do(q{INSERT INTO clean.censo_escolas
             (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, sg_uf, co_regiao)
           VALUES (2025, ?, 'Escola Salvos', 3, 3555406, 'SP', 3),
                  (2025, ?, 'Outra Salvos', 2, 2927408, 'BA', 2)}, {}, $INEP, $OUTRO);

sub sessao ($inep, $email) {
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $inep, nome => "Gestor $email", email => $email, senha => $SENHA,
  })->status_is(200);
  return $t->post_ok('/api/gestor/login', json => { email => $email, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
}
my %tok = (a => sessao($INEP, $EMAIL), c => sessao($INEP, $CEMAIL), o => sessao($OUTRO, $OEMAIL));
ok $tok{a} && $tok{c} && $tok{o}, 'tokens de sessão';
my ($GID) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);
my ($CID) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $CEMAIL);

my %auth = map { $_ => { Authorization => "Bearer $tok{$_}" } } keys %tok;
my $base = "/api/gestor/$INEP/relatorios/salvos";

# ReportResult de teste (com acentos, para pegar dupla codificação).
sub report_result (%o) {
  return {
    titulo    => $o{titulo} // 'Relatório de Ubatuba',
    gerado_em => '2026-10-12T12:00:00Z',
    recorte   => { nivel => 'municipio', codigo => '3555406', nome => 'Ubatuba' },
    tema      => { id => 'ideb_territorio', titulo => 'IDEB do território' },
    secoes    => [ { id => 'resumo', tipo => 'texto', titulo => 'Resumo', markdown => 'Situação estável.' } ],
    fontes    => [ 'INEP' ], avisos => [], rastreio => { provedor => 'mock' },
    cache_hit => Mojo::JSON::true,
  };
}

# Cria um job relatorio_gerar e o leva ao estado pedido.
sub job_relatorio (%o) {
  my $id = $minion->enqueue(relatorio_gerar => [{
    gestor_id => $o{gestor_id} // $GID,
    cod_inep  => $o{cod_inep}  // $INEP,
    geotag    => { nivel => 'municipio', codigo => '3555406' },
    tema      => 'ideb_territorio',
    opcoes    => { etapa => 'fundamental_ii' },
  }] => { queue => $FILA });
  my $estado = $o{estado} // 'finished';
  return $id if $estado eq 'inactive';
  my $job = $minion->worker->register->dequeue(0, { queues => [$FILA], id => $id });
  is $job->id, $id, 'job retirado da fila';
  if    ($estado eq 'finished') { $job->finish($o{result} // report_result()) }
  elsif ($estado eq 'failed')   { $job->fail({ error => 'falhou' }) }
  return $id;
}

subtest '401 sem sessão / 403 em escola alheia' => sub {
  $t->post_ok($base, json => { job_id => 1 })->status_is(401);
  $t->get_ok($base)->status_is(401);
  $t->get_ok("$base/1")->status_is(401);
  $t->delete_ok("$base/1")->status_is(401);

  $t->post_ok($base, $auth{o}, json => { job_id => 1 })->status_is(403);
  $t->get_ok($base, $auth{o})->status_is(403);
  $t->get_ok("$base/1", $auth{o})->status_is(403);
  $t->delete_ok("$base/1", $auth{o})->status_is(403);
};

subtest 'POST: 400 para corpo sem job_id válido' => sub {
  $t->post_ok($base, $auth{a}, json => {})->status_is(400);
  $t->post_ok($base, $auth{a}, json => { job_id => 'abc' })->status_is(400);
  $t->post_ok($base, $auth{a}, json => { job_id => [1] })->status_is(400);
};

my ($job1, $salvo_id);
subtest 'POST: salva job finished (201) e de novo (200, mesmo id)' => sub {
  $job1 = job_relatorio();
  # Lixo no corpo: o conteúdo NÃO pode vir do cliente.
  $t->post_ok($base, $auth{a}, json => {
    job_id => $job1, titulo => 'ADULTERADO', conteudo => { titulo => 'ADULTERADO' },
    relatorio => { secoes => [] }, tema_id => 'x', nivel => 'uf',
  })->status_is(201)
    ->header_like(Location => qr{/relatorios/salvos/\d+$})
    ->json_is('/titulo', 'Relatório de Ubatuba')
    ->json_is('/tema', { id => 'ideb_territorio', titulo => 'IDEB do território' })
    ->json_is('/recorte', { nivel => 'municipio', codigo => '3555406', nome => 'Ubatuba' })
    ->json_is('/opcoes', { etapa => 'fundamental_ii' })
    ->json_is('/gerado_em', '2026-10-12T12:00:00Z')
    ->json_like('/salvo_em', qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
  $salvo_id = $t->tx->res->json->{id};
  ok $salvo_id, 'id do salvo';
  ok !exists $t->tx->res->json->{relatorio}, 'resumo sem relatorio';

  $t->post_ok($base, $auth{a}, json => { job_id => "$job1" })->status_is(200)
    ->json_is('/id', $salvo_id);

  my ($n) = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.relatorios_salvos WHERE gestor_id = ?', {}, $GID);
  is $n, 1, 'uma linha só (UNIQUE gestor_id, job_id)';

  my ($conteudo) = $dbh->selectrow_array(
    'SELECT conteudo::text FROM clean.relatorios_salvos WHERE id = ?', {}, $salvo_id);
  my $c = Mojo::JSON::from_json($conteudo);
  ok !exists $c->{cache_hit}, 'cache_hit não é gravado';
  is $c->{titulo}, 'Relatório de Ubatuba', 'conteúdo do job (com acento íntegro)';
  unlike $conteudo, qr/ADULTERADO/, 'corpo do cliente ignorado';
};

subtest 'POST: job de outro gestor / outra task / outra escola / inexistente -> 404' => sub {
  my $alheio = job_relatorio(gestor_id => $CID);
  $t->post_ok($base, $auth{a}, json => { job_id => $alheio })->status_is(404);

  my $outra = $minion->enqueue(chat_ask => [{ gestor_id => $GID, cod_inep => $INEP }] => { queue => $FILA });
  $t->post_ok($base, $auth{a}, json => { job_id => $outra })->status_is(404);

  my $outra_escola = job_relatorio(cod_inep => $OUTRO);
  $t->post_ok($base, $auth{a}, json => { job_id => $outra_escola })->status_is(404);

  $t->post_ok($base, $auth{a}, json => { job_id => 999999999 })->status_is(404);
};

subtest 'POST: job failed / ainda não terminou -> 409' => sub {
  my $falhou = job_relatorio(estado => 'failed');
  $t->post_ok($base, $auth{a}, json => { job_id => $falhou })->status_is(409)->json_has('/error');

  my $ativo = job_relatorio(estado => 'active');
  $t->post_ok($base, $auth{a}, json => { job_id => $ativo })->status_is(409);

  my $na_fila = job_relatorio(estado => 'inactive');
  $t->post_ok($base, $auth{a}, json => { job_id => $na_fila })->status_is(409);
};

subtest 'GET lista: paginada, mais recentes primeiro, só do gestor' => sub {
  # mais dois salvos do gestor A e um do colega (mesma escola)
  my @ids = ($salvo_id);
  for my $i (2, 3) {
    my $j = job_relatorio(result => report_result(titulo => "Relatório $i"));
    $t->post_ok($base, $auth{a}, json => { job_id => $j })->status_is(201);
    push @ids, $t->tx->res->json->{id};
  }
  my $jc = job_relatorio(gestor_id => $CID);
  $t->post_ok($base, $auth{c}, json => { job_id => $jc })->status_is(201);
  my $colega_id = $t->tx->res->json->{id};

  $t->get_ok($base, $auth{a})->status_is(200)
    ->json_is('/total', 3)->json_is('/page', 1)->json_is('/per_page', 20)
    ->json_is('/items/0/id', $ids[2])
    ->json_is('/items/0/titulo', 'Relatório 3')
    ->json_is('/items/2/id', $ids[0]);
  ok !exists $t->tx->res->json->{items}[0]{relatorio}, 'lista só com resumos';

  $t->get_ok("$base?page=2&per_page=2", $auth{a})->status_is(200)
    ->json_is('/total', 3)->json_is('/page', 2)->json_is('/per_page', 2)
    ->json_is('/items', [ $t->app->model('Gestor')->listar_relatorios_salvos($GID, 2, 2)->{items}[0] ]);
  is scalar @{ $t->tx->res->json->{items} }, 1, 'página 2 com 1 item';
  is $t->tx->res->json->{items}[0]{id}, $ids[0], 'o mais antigo na página 2';

  $t->get_ok("$base?per_page=500", $auth{a})->status_is(200)->json_is('/per_page', 100);
  $t->get_ok("$base?page=0&per_page=x", $auth{a})->status_is(200)
    ->json_is('/page', 1)->json_is('/per_page', 20);

  $t->get_ok($base, $auth{c})->status_is(200)
    ->json_is('/total', 1)->json_is('/items/0/id', $colega_id);

  # GET :id / DELETE :id de outro gestor (mesma escola) -> 404
  $t->get_ok("$base/$salvo_id", $auth{c})->status_is(404);
  $t->delete_ok("$base/$salvo_id", $auth{c})->status_is(404);
  $t->get_ok("$base/$colega_id", $auth{a})->status_is(404);
};

subtest 'GET :id: resumo + relatorio' => sub {
  $t->get_ok("$base/$salvo_id", $auth{a})->status_is(200)
    ->json_is('/id', $salvo_id)
    ->json_is('/titulo', 'Relatório de Ubatuba')
    ->json_is('/recorte/nome', 'Ubatuba')
    ->json_is('/gerado_em', '2026-10-12T12:00:00Z')
    ->json_has('/salvo_em')
    ->json_is('/relatorio/titulo', 'Relatório de Ubatuba')
    ->json_is('/relatorio/secoes/0/markdown', 'Situação estável.')
    ->json_is('/relatorio/tema/titulo', 'IDEB do território')
    ->json_hasnt('/relatorio/cache_hit');

  $t->get_ok("$base/999999999", $auth{a})->status_is(404);
};

subtest 'DELETE :id' => sub {
  $t->delete_ok("$base/$salvo_id", $auth{a})->status_is(200)->json_is('/ok', 1);
  $t->get_ok("$base/$salvo_id", $auth{a})->status_is(404);
  $t->delete_ok("$base/$salvo_id", $auth{a})->status_is(404);
  $t->get_ok($base, $auth{a})->status_is(200)->json_is('/total', 2);

  # o job continua lá: salvar de novo cria um novo (201)
  $t->post_ok($base, $auth{a}, json => { job_id => $job1 })->status_is(201);
};

subtest 'cascade: remover o gestor remove os salvos' => sub {
  my ($antes) = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.relatorios_salvos WHERE gestor_id = ?', {}, $GID);
  ok $antes > 0, 'há salvos do gestor';
  $dbh->do('DELETE FROM clean.gestores WHERE id = ?', {}, $GID);
  my ($depois) = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.relatorios_salvos WHERE gestor_id = ?', {}, $GID);
  is $depois, 0, 'salvos removidos em cascata';
};

done_testing();
