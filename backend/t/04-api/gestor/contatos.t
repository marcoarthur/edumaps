# t/04-api/gestor/contatos.t
# Testes da API de contatos e grupos do gestor (módulo Reuniões e Atas):
#   CRUD de contatos, grupos (organização por drag-and-drop) e import em lote.
# Exige sessão do gestor da escola (Bearer). Só roda onde a migration
# gestor_reunioes foi aplicada (clean.reunioes presente).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.reunioes')"
);

my $INEP  = '99999999';
my $CPF   = sprintf('1234567%04d', $$ % 10000);
my $EMAIL = sprintf 'teste.contatos.%d@edumaps.test', $$;
my $SENHA = 'senha123';

my $token;
my $auth = sub { { Authorization => "Bearer $token" } };

my $out_token;
my $OUTRA = '88888888';
my $out_email = sprintf 'outra.contatos.%d@edumaps.test', $$;

# INEP usado no subteste da folha de pagamento (com três categorias).
my $INEP_FOLHA = '99999998';
my $FOLHA_EMAIL = sprintf 'folha.contatos.%d@edumaps.test', $$;

# Self-signup governado exige escola existente; garante INEPs de teste no
# clean.escolas e remove sobras de execuções anteriores (base compartilhada).
if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA, $INEP_FOLHA) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da API de contatos');
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $out_email);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $FOLHA_EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE cpf = ?', {}, $CPF);
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep = ?', {}, $INEP_FOLHA);
  for my $inep ($INEP, $OUTRA, $INEP_FOLHA) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

subtest 'setup: gestor da escola + sessão' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Contatos', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  my $login = $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $token = $login->{token};

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Outra Escola', email => $out_email, senha => $SENHA,
  })->status_is(200);
  my $out_log = $t->post_ok('/api/gestor/login', json => {
    email => $out_email, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $out_token = $out_log->{token};
};

subtest 'sem sessão: 401' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  $t->get_ok("/api/gestor/$INEP/contatos")->status_is(401)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/contatos", json => { nome => 'X' })->status_is(401);
};

subtest 'contatos: criar, listar, atualizar, excluir' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $c = $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Ana Professora', email => 'ana@edu.test', telefone => '(11) 99999-0001', cargo => 'Professora',
  })->status_is(201)->tx->res->json;
  ok $c->{id} > 0, 'contato criado com id';
  is $c->{nome}, 'Ana Professora', 'nome';
  ok !exists $c->{cpf}, 'sem campos PII extras';

  my $list = $t->get_ok("/api/gestor/$INEP/contatos", $auth->())
    ->status_is(200)->tx->res->json;
  ok grep({ $_->{id} == $c->{id} } @$list), 'contato aparece na lista';

  my $upd = $t->put_ok("/api/gestor/$INEP/contatos/$c->{id}", $auth->(), json => {
    nome => 'Ana Coordenadora', email => 'ana@edu.test', cargo => 'Coordenadora',
  })->status_is(200)->tx->res->json;
  is $upd->{nome}, 'Ana Coordenadora', 'atualizado';

  $t->delete_ok("/api/gestor/$INEP/contatos/$c->{id}", $auth->())->status_is(204);
  my $list2 = $t->get_ok("/api/gestor/$INEP/contatos", $auth->())
    ->status_is(200)->tx->res->json;
  ok !grep({ $_->{id} == $c->{id} } @$list2), 'contato removido da lista';
};

subtest 'contatos: e-mail duplicado na escola -> 409' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Carlos Pais', email => 'carlos@edu.test', telefone => '(11) 99999-0002',
  })->status_is(201);
  $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Carlos Duplicado', email => 'Carlos@edu.test',
  })->status_is(409)->json_has('/error');
};

subtest 'contatos: validações' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => { nome => '' })
    ->status_is(400)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Sem Email', email => 'invalido',
  })->status_is(400)->json_has('/error');
};

subtest 'grupos: criar, listar, atualizar, excluir (sem apagar contatos)' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $g = $t->post_ok("/api/gestor/$INEP/grupos", $auth->(), json => { nome => 'Professores' })
    ->status_is(201)->tx->res->json;
  ok $g->{id} > 0, 'grupo criado';
  is $g->{n_contatos}, 0, 'começa vazio';

  my $c = $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Maria Docente', email => 'maria@edu.test', grupo_id => $g->{id},
  })->status_is(201)->tx->res->json;
  is $c->{grupo_id}, $g->{id}, 'contato entra no grupo (drag-and-drop)';
  is $c->{grupo_nome}, 'Professores', 'grupo_nome resolvido';

  my $groups = $t->get_ok("/api/gestor/$INEP/grupos", $auth->())
    ->status_is(200)->tx->res->json;
  my ($professores) = grep { $_->{id} == $g->{id} } @$groups;
  is $professores->{n_contatos}, 1, 'contagem do grupo após mover contato';

  my $g2 = $t->post_ok("/api/gestor/$INEP/grupos", $auth->(), json => { nome => 'Professores' })
    ->status_is(409)->tx->res->json;
  ok $g2->{error}, 'nome duplicado na mesma escola -> 409';

  my $moved = $t->put_ok("/api/gestor/$INEP/contatos/$c->{id}", $auth->(), json => {
    nome => 'Maria Docente', email => 'maria@edu.test', grupo_id => undef,
  })->status_is(200)->tx->res->json;
  ok !$moved->{grupo_id}, 'grupo_id = null remove o contato do grupo';

  $t->delete_ok("/api/gestor/$INEP/grupos/$g->{id}", $auth->())->status_is(204);

  my $still = $t->get_ok("/api/gestor/$INEP/contatos", $auth->())
    ->status_is(200)->tx->res->json;
  ok grep({ $_->{id} == $c->{id} && !$_->{grupo_id} } @$still),
    'excluir grupo não apaga o contato (SET NULL)';
};

subtest 'import por colagem: criação de grupos no caminho + salto de duplicados' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $res = $t->post_ok("/api/gestor/$INEP/contatos/import", $auth->(), json => {
    contatos => [
      { nome => 'João Pais',   email => 'joao.home@edu.test', telefone => '+5511999990003', grupo => 'Pais' },
      { nome => 'Rita Pais',   email => 'rita.home@edu.test', grupo => 'Pais' },
      { nome => 'Cláudio Conselho', email => 'claudio@edu.test', grupo => 'Conselho Escolar' },
    ],
  })->status_is(201)->tx->res->json;
  is $res->{n_inseridos}, 3, '3 contatos inseridos';
  is $res->{n_pulados}, 0, 'nenhum pulado';

  my $groups = $t->get_ok("/api/gestor/$INEP/grupos", $auth->())
    ->status_is(200)->tx->res->json;
  my ($pais) = grep { $_->{nome} eq 'Pais' } @$groups;
  is $pais->{n_contatos}, 2, 'grupo Pais criado e preenchido no import';

  # segundo import com e-mail já existente (normalizado em minúsculas) -> pula
  my $dup = $t->post_ok("/api/gestor/$INEP/contatos/import", $auth->(), json => {
    contatos => [ { nome => 'João Pais 2', email => 'JOAO.HOME@edu.test', grupo => 'Pais' } ],
  })->status_is(201)->tx->res->json;
  is $dup->{n_inseridos}, 0, 'duplicado não re-insere';
  is $dup->{n_pulados}, 1, 'pulado';
};

subtest 'ownership: gestor de outra escola -> 403 em tudo' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $other = sub { { Authorization => "Bearer $out_token" } };
  $t->get_ok("/api/gestor/$INEP/contatos", $other->())->status_is(403)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/contatos", $other->(), json => { nome => 'Invasor' })
    ->status_is(403);
  $t->post_ok("/api/gestor/$INEP/contatos/import", $other->(), json => { contatos => [] })
    ->status_is(403);
  $t->get_ok("/api/gestor/$INEP/grupos", $other->())->status_is(403);
};

subtest 'associação gestor×escola: grava gestor_id + cod_inep de quem cria' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $me = $t->get_ok('/api/gestor/me', $auth->())->status_is(200)->tx->res->json;
  ok $me->{id} > 0, 'gestor logado identificado';

  my $c = $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Renata Vínculo', email => 'renata.vinc@edu.test',
  })->status_is(201)->tx->res->json;

  my $dbh = $t->app->schema->storage->dbh;
  my ($gid, $inep) = $dbh->selectrow_array(
    'SELECT gestor_id, cod_inep FROM clean.contatos WHERE id = ?', {}, $c->{id});
  is $gid, $me->{id}, 'contato gravado com gestor_id do criador';
  is "$inep" . '', "$INEP", 'contato gravado com cod_inep da escola';
};

subtest 'grupos da folha de pagamento: pré-listados por categoria' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $dbh = $t->app->schema->storage->dbh;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_FOLHA, nome => 'Gestor Folha', email => $FOLHA_EMAIL, senha => 'senha123',
  })->status_is(200);
  my $login = $t->post_ok('/api/gestor/login', json => {
    email => $FOLHA_EMAIL, senha => 'senha123',
  })->status_is(200)->tx->res->json;
  my $folha_token = $login->{token};
  my $folha = sub { { Authorization => "Bearer $folha_token" } };

  # Escola sem folha: nenhum grupo criado automaticamente.
  $t->get_ok("/api/gestor/$INEP/grupos", $auth->())->status_is(200)->tx->res->json;

  # Escola com folha: três categorias profissionais distintas.
  $dbh->do('INSERT INTO clean.remuneracao_municipal (cod_inep, tipo, categoria) VALUES (?,?,?)', {},
    $INEP_FOLHA, 'Profissionais do magistério', 'Docente habilitado em curso de licenciatura plena');
  $dbh->do('INSERT INTO clean.remuneracao_municipal (cod_inep, tipo, categoria) VALUES (?,?,?)', {},
    $INEP_FOLHA,
    'Outros profissionais da educação',
    'Profissionais que exercem funções de secretaria escolar, alimentação escolar (merendeiras), multimeios didáticos e infraestrutura');
  $dbh->do('INSERT INTO clean.remuneracao_municipal (cod_inep, tipo, categoria) VALUES (?,?,?)', {},
    $INEP_FOLHA, 'Outros profissionais da educação', 'Serviços de psicologia');

  my $g1 = $t->get_ok("/api/gestor/$INEP_FOLHA/grupos", $folha->())
    ->status_is(200)->tx->res->json;
  my %n1 = map { $_->{nome} => $_ } @$g1;
  is $n1{Professores}{origem}, 'folha', 'Professores pré-listado (origem folha)';
  is $n1{Administrativos}{origem}, 'folha', 'Administrativos pré-listado';
  is $n1{Outros}{origem}, 'folha', 'Outros pré-listado';
  is $n1{Professores}{n_contatos}, 0, 'sem contatos ainda';

  # gestor_id NULL em grupos da folha (não pertencem a um gestor específico)
  my $g_null = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.contato_grupos WHERE cod_inep = ? AND origem = \'folha\' AND gestor_id IS NULL',
    {}, $INEP_FOLHA);
  is $g_null, 3, '3 grupos da folha sem gestor dono';

  # Idempotente: segunda listagem não duplica nem muda os grupos.
  my $g2 = $t->get_ok("/api/gestor/$INEP_FOLHA/grupos", $folha->())
    ->status_is(200)->tx->res->json;
  my @f2 = sort map { $_->{id} } grep { $_->{origem} eq 'folha' } @$g2;
  my @f1 = sort map { $_->{id} } grep { $_->{origem} eq 'folha' } @$g1;
  is join(',', @f1), join(',', @f2), 'mesmos grupos pré-listados (sem duplicar)';

  # Grupos manuais continuam funcionando ao lado dos da folha.
  my $manual = $t->post_ok("/api/gestor/$INEP_FOLHA/grupos", $folha->(), json => { nome => 'Conselho' })
    ->status_is(201)->tx->res->json;
  is $manual->{origem}, 'manual', 'grupo criado pelo gestor tem origem manual';
};

done_testing();