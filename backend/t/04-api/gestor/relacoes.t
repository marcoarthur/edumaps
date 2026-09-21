# t/04-api/gestor/relacoes.t
# Testes das Relações Institucionais da escola (Etapas 1+2):
#   taxonomia editável (categorias), cadastro de entidades externas e CRUD das
#   relações (assunto/finalidade/responsável/próxima ação/prazo). Exige sessão
#   do gestor da escola. Só roda onde relacoes_escolar foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use DateTime;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $UPLOAD_DIR = "/tmp/edumaps_relacoes_test_$$";
$t->app->config->{upload_dir} = $UPLOAD_DIR;

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
  system('rm', '-rf', $UPLOAD_DIR);
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

subtest 'agenda: visão temporal derivada (com e sem prazo)' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  my $hoje  = DateTime->today(time_zone => 'local');
  my $futuro = $hoje->clone->add(days => 10)->ymd;

  my $ent = $t->post_ok("/api/gestor/$INEP/relacoes/entidades", $auth->(), json => {
    nome => 'Agenda Escola',
  })->status_is(201)->tx->res->json;

  my $futura = $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent->{id}, assunto => 'Reunião futura', prazo => $futuro, prioridade => 'media',
  })->status_is(201)->tx->res->json;
  my $vencida = $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent->{id}, assunto => 'Cobrança atrasada', prazo => '2020-01-01', prioridade => 'alta',
  })->status_is(201)->tx->res->json;
  my $sem_prazo = $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent->{id}, assunto => 'Sem prazo', proxima_acao => 'Definir data',
  })->status_is(201)->tx->res->json;

  my $ag = $t->get_ok("/api/gestor/$INEP/relacoes/agenda", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@{ $ag->{itens} }), 2, 'duas relações com prazo';
  is $ag->{itens}[0]{assunto}, 'Cobrança atrasada', 'ordenado por prazo (vencida primeiro)';
  is $ag->{itens}[0]{vencida}, 1, 'vencida marcada';
  is scalar(@{ $ag->{sem_prazo} }), 1, 'uma sem prazo';
  is $ag->{sem_prazo}[0]{assunto}, 'Sem prazo', 'sem prazo listada à parte';
  cmp_ok $ag->{vencidas}, '>=', 1, 'contagem de vencidas';

  my $recorte = $t->get_ok("/api/gestor/$INEP/relacoes/agenda?de=$futuro", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@{ $recorte->{itens} }), 1, 'recorte por data exclui a vencida';

  $t->delete_ok("/api/gestor/$INEP/relacoes/$_->{id}", $auth->())->status_is(204)
    for ($futura, $vencida, $sem_prazo);
  $t->delete_ok("/api/gestor/$INEP/relacoes/entidades/$ent->{id}", $auth->())->status_is(204);
};

subtest 'interações: timeline CRUD no detalhe' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  my $ent = $t->post_ok("/api/gestor/$INEP/relacoes/entidades", $auth->(), json => {
    nome => 'Interações Escola',
  })->status_is(201)->tx->res->json;
  my $rel = $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent->{id}, assunto => 'Relação com timeline',
  })->status_is(201)->tx->res->json;

  my $inter = $t->post_ok("/api/gestor/$INEP/relacoes/$rel->{id}/interacoes", $auth->(), json => {
    data => '2026-09-15', canal => 'reunião', participante => 'Secretaria de Obras',
    assunto => 'Reunião inicial', resultado => 'Enviar ofício com o pedido',
  })->status_is(201)->tx->res->json;
  is $inter->{canal}, 'reunião', 'interação criada';

  my $det = $t->get_ok("/api/gestor/$INEP/relacoes/$rel->{id}", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@{ $det->{interacoes} }), 1, 'detalhe traz a timeline';
  is $det->{interacoes}[0]{resultado}, 'Enviar ofício com o pedido', 'resultado na timeline';

  my $upd = $t->put_ok("/api/gestor/$INEP/relacoes/$rel->{id}/interacoes/$inter->{id}", $auth->(), json => {
    assunto => 'Reunião inicial (revisada)', resultado => 'Ofício enviado',
  })->status_is(200)->tx->res->json;
  is $upd->{resultado}, 'Ofício enviado', 'interação atualizada';

  $t->delete_ok("/api/gestor/$INEP/relacoes/$rel->{id}/interacoes/$inter->{id}", $auth->())
    ->status_is(204);

  $t->delete_ok("/api/gestor/$INEP/relacoes/$rel->{id}", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/relacoes/entidades/$ent->{id}", $auth->())->status_is(204);
};

subtest 'documentos: upload, download, extensão e exclusão' => sub {
  plan skip_all => 'clean.relacoes ausente (migration nao aplicada)'
    unless $has_tables;

  my $ent = $t->post_ok("/api/gestor/$INEP/relacoes/entidades", $auth->(), json => {
    nome => 'Documentos Escola',
  })->status_is(201)->tx->res->json;
  my $rel = $t->post_ok("/api/gestor/$INEP/relacoes", $auth->(), json => {
    entidade_id => $ent->{id}, assunto => 'Relação com documentos',
  })->status_is(201)->tx->res->json;

  my $up = $t->post_ok("/api/gestor/$INEP/relacoes/$rel->{id}/documentos",
    { Authorization => "Bearer $token" },
    form => {
      arquivo   => { content => '%PDF-1.4 ofício', filename => 'oficio.pdf' },
      referencia => 'OF-123',
    })->status_is(201)->tx->res->json;
  my ($doc) = @{ $up->{documentos} };
  is $doc->{nome_original}, 'oficio.pdf', 'documento registrado';
  is $doc->{referencia}, 'OF-123', 'referência preservada';
  is $doc->{mime}, 'application/pdf', 'mime inferido';

  my $det = $t->get_ok("/api/gestor/$INEP/relacoes/$rel->{id}", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@{ $det->{documentos} }), 1, 'detalhe traz os documentos';

  $t->get_ok("/api/gestor/$INEP/relacoes/$rel->{id}/documentos/$doc->{id}", $auth->())
    ->status_is(200)->content_is('%PDF-1.4 ofício');

  $t->post_ok("/api/gestor/$INEP/relacoes/$rel->{id}/documentos",
    { Authorization => "Bearer $token" },
    form => { arquivo => { content => 'MZ', filename => 'malicioso.exe' } })
    ->status_is(400)->json_has('/error');

  $t->delete_ok("/api/gestor/$INEP/relacoes/$rel->{id}/documentos/$doc->{id}", $auth->())
    ->status_is(204);

  $t->delete_ok("/api/gestor/$INEP/relacoes/$rel->{id}", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/relacoes/entidades/$ent->{id}", $auth->())->status_is(204);
};

done_testing;
