# t/04-api/gestor/relacoes.t
# Testes das Relações Institucionais da escola (Etapas 1+2):
#   taxonomia editável (categorias), cadastro de entidades externas e CRUD das
#   relações (assunto/finalidade/responsável/próxima ação/prazo). Exige sessão
#   do gestor da escola. Só roda onde relacoes_escolar foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.relacoes')"
);

my $INEP   = '77777760';
my $OUTRA  = '66666650';
my $SENHA  = 'senha123';
my $EMAIL  = sprintf 'rel.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'rel.b.%d@edumaps.test', $$;

my ($token, $out_token);

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
    $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade)
              VALUES (2025, ?, ?)', {}, $inep, "Escola Relacoes $inep");
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  for my $email ($EMAIL, $OEMAIL) {
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $email);
  }
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.relacoes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.relacoes_entidades WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.relacoes_categorias WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
}

my $auth = sub { { Authorization => "Bearer $token" } };

subtest 'setup: gestor da escola + outra escola' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Relações', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  ok $token, 'login devolve token';

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Outra Escola', email => $OEMAIL, senha => $SENHA,
  })->status_is(200);
  $out_token = $t->post_ok('/api/gestor/login', json => { email => $OEMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
};

subtest 'index: taxonomia semeada (7 grupos + 10 finalidades)' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  my $data = $t->get_ok("/api/gestor/$INEP/relacoes", $auth->())
    ->status_is(200)->tx->res->json;

  is scalar(@{ $data->{categorias} }), 17, 'taxonomia semeada';
  is scalar(grep { $_->{eixo} eq 'entidade' } @{ $data->{categorias} }), 7, '7 grupos';
  is scalar(grep { $_->{eixo} eq 'finalidade' } @{ $data->{categorias} }), 10, '10 finalidades';
  is scalar(@{ $data->{entidades} }), 0, 'sem entidades ainda';
  is scalar(@{ $data->{relacoes} }), 0, 'sem relações ainda';
};

my ($ent_id, $rel_id);

subtest 'entidades: CRUD + unicidade' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  my $ent = $t->post_ok("/api/gestor/$INEP/relacoes/entidades", $auth->(), json => {
    tipo => 'Órgãos públicos', nome => 'Prefeitura de Teste',
    email => 'gabinete@pref.test', telefone => '6933330000',
    responsavel_externo => 'Secretaria de Obras',
    atributos => { ramal => 42 },
  })->status_is(201)->tx->res->json;
  $ent_id = $ent->{id};
  ok $ent_id > 0, 'entidade criada';
  is $ent->{atributos}{ramal}, 42, 'atributos livres (JSONB)';

  $t->post_ok("/api/gestor/$INEP/relacoes/entidades", $auth->(), json => {
    nome => 'prefeitura de teste',
  })->status_is(409)->json_has('/error');

  my $upd = $t->put_ok("/api/gestor/$INEP/relacoes/entidades/$ent_id", $auth->(), json => {
    tipo => 'Órgãos públicos', nome => 'Prefeitura Municipal', responsavel_externo => 'Obras',
  })->status_is(200)->tx->res->json;
  is $upd->{nome}, 'Prefeitura Municipal', 'entidade atualizada';

  my $list = $t->get_ok("/api/gestor/$INEP/relacoes/entidades?q=municipal", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@$list), 1, 'busca por nome';
};

subtest 'relações: CRUD, status/prioridade e filtros' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  my $rel = $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent_id,
    finalidade => 'Solicitação',
    assunto => 'Conserto do telhado',
    descricao => 'Telhado da quadra com infiltração.',
    status => 'aberta',
    prioridade => 'alta',
    responsavel_interno => 'Coordenador administrativo',
    proxima_acao => 'Cobrar orçamento',
    prazo => '2020-01-01',
  })->status_is(201)->tx->res->json;
  $rel_id = $rel->{id};
  is $rel->{entidade_nome}, 'Prefeitura Municipal', 'relação traz a entidade';
  is $rel->{status}, 'aberta', 'status';
  is $rel->{prioridade}, 'alta', 'prioridade';
  is $rel->{vencida}, 1, 'prazo no passado = vencida';

  my $vencidas = $t->get_ok("/api/gestor/$INEP/relacoes?vencidas=1", $auth->())
    ->status_is(200)->tx->res->json->{relacoes};
  is scalar(@$vencidas), 1, 'filtro vencidas';

  my $por_status = $t->get_ok("/api/gestor/$INEP/relacoes?status=concluida", $auth->())
    ->status_is(200)->tx->res->json->{relacoes};
  is scalar(@$por_status), 0, 'filtro por status';

  my $upd = $t->put_ok("/api/gestor/$INEP/relacoes/$rel_id", $auth->(), json => {
    entidade_id => $ent_id, assunto => 'Conserto do telhado', status => 'concluida', prioridade => 'media',
  })->status_is(200)->tx->res->json;
  is $upd->{status}, 'concluida', 'status atualizado';
  is $upd->{vencida}, 0, 'concluída não conta como vencida';
};

subtest 'regras: entidade com relação, ownership e validação' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  # não apaga entidade com relações (FK RESTRICT)
  $t->delete_ok("/api/gestor/$INEP/relacoes/entidades/$ent_id", $auth->())
    ->status_is(409)->json_has('/error');

  # relação apontando para entidade de OUTRA escola -> 404
  my $out_ent = $t->post_ok("/api/gestor/$OUTRA/relacoes/entidades", { Authorization => "Bearer $out_token" }, json => {
    nome => 'Entidade de outra escola',
  })->status_is(201)->tx->res->json;

  $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $out_ent->{id}, assunto => 'Invasão',
  })->status_is(404)->json_has('/error');

  # ownership
  $t->get_ok("/api/gestor/$INEP/relacoes", { Authorization => "Bearer $out_token" })
    ->status_is(403)->json_has('/error');
  $t->get_ok("/api/gestor/$INEP/relacoes")->status_is(401)->json_has('/error');

  # validação
  $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent_id,
  })->status_is(400)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent_id, assunto => 'X', status => 'xpto',
  })->status_is(400)->json_has('/error');

  # limpeza de relação libera a entidade
  $t->delete_ok("/api/gestor/$INEP/relacoes/$rel_id", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/relacoes/entidades/$ent_id", $auth->())->status_is(204);
};

done_testing;
