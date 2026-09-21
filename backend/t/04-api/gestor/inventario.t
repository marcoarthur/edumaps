# t/04-api/gestor/inventario.t
# Testes do Painel de Inventário Escolar (recursos e serviços):
#   baseline do Censo (somente leitura), semeadura da taxonomia, importação
#   idempotente, CRUD de categorias/itens/fornecedores, atributos JSONB e
#   anexos. Exige sessão do gestor da escola. Só roda onde inventario_escolar
#   foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.inventario_itens')"
);

my $UPLOAD_DIR = "/tmp/edumaps_inventario_test_$$";
$t->app->config->{upload_dir} = $UPLOAD_DIR;

my $INEP   = '77777770';
my $OUTRA  = '66666660';
my $SENHA  = 'senha123';
my $EMAIL  = sprintf 'inv.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'inv.b.%d@edumaps.test', $$;

my ($token, $out_token);

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
    $dbh->do('INSERT INTO clean.censo_escolas
                (nu_ano_censo, co_entidade, no_entidade, no_municipio, sg_uf,
                 in_computador, qt_desktop_aluno, qt_tablet_aluno,
                 in_agua_potavel, in_internet, in_banda_larga, in_energia_rede_publica)
              VALUES (2025, ?, ?, ?, ?, 1, 12, 5, 1, 1, 1, 1)',
      {}, $inep, "Escola Inventario $inep", 'Cidade Teste', 'SP');
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  for my $email ($EMAIL, $OEMAIL) {
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $email);
  }
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.inventario_anexos a USING clean.inventario_itens i
              WHERE a.item_id = i.id AND i.cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.inventario_itens WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.inventario_fornecedores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.inventario_categorias WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
  system('rm', '-rf', $UPLOAD_DIR);
}

my $auth = sub { { Authorization => "Bearer $token" } };

subtest 'setup: gestor da escola + outra escola' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Inventário', email => $EMAIL, senha => $SENHA,
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

subtest 'index: baseline do Censo + taxonomia semeada' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  my $data = $t->get_ok("/api/gestor/$INEP/inventario", $auth->())
    ->status_is(200)->tx->res->json;

  is $data->{ano}, 2025, 'ano do censo';
  is $data->{censo}{escola}{nome}, "Escola Inventario $INEP", 'escola do censo';

  my %grupos = map { $_->{key} => $_ } @{ $data->{censo}{grupos} };
  ok $grupos{dispositivos}, 'grupo dispositivos presente';
  ok $grupos{servicos_basicos}, 'grupo serviços básicos presente';

  my %disp = map { $_->{key} => $_ } @{ $grupos{dispositivos}{itens} };
  is $disp{desktop_aluno}{qtd}, 12, 'quantidade de computadores (aluno) do censo';
  is $disp{tablet_aluno}{qtd}, 5, 'quantidade de tablets do censo';

  # 9 categorias semeadas do censo, nenhuma manual ainda
  is scalar(@{ $data->{categorias} }), 9, 'taxonomia do censo semeada';
  is scalar(grep { $_->{origem} eq 'censo' } @{ $data->{categorias} }), 9, 'todas origem censo';
  is scalar(@{ $data->{itens} }), 0, 'sem itens ainda';
  is scalar(@{ $data->{fornecedores} }), 0, 'sem fornecedores ainda';
};

subtest 'importar-censo: cria itens idempotentes a partir do baseline' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  my $imp = $t->post_ok("/api/gestor/$INEP/inventario/importar-censo", $auth->())
    ->status_is(200)->tx->res->json;
  cmp_ok $imp->{importados}, '>', 0, 'importou itens do censo';

  my $again = $t->post_ok("/api/gestor/$INEP/inventario/importar-censo", $auth->())
    ->status_is(200)->tx->res->json;
  is $again->{importados}, 0, 'reimportação é idempotente';

  my $itens = $t->get_ok("/api/gestor/$INEP/inventario/itens", $auth->())
    ->status_is(200)->tx->res->json;
  my ($desktop) = grep { $_->{censo_ref} eq 'desktop_aluno' } @$itens;
  ok $desktop, 'item importado tem censo_ref';
  is $desktop->{quantidade}, 12, 'quantidade copiada do censo';
  is $desktop->{categoria_tipo}, 'recurso', 'item importado é recurso';
};

subtest 'categorias: CRUD, duplicidade e bloqueio com itens' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  my $cat = $t->post_ok("/api/gestor/$INEP/inventario/categorias", $auth->(), json => {
    tipo => 'recurso', nome => 'Meus recursos',
  })->status_is(201)->tx->res->json;
  ok $cat->{id} > 0, 'categoria criada';
  is $cat->{origem}, 'manual', 'origem manual';

  $t->post_ok("/api/gestor/$INEP/inventario/categorias", $auth->(), json => {
    tipo => 'recurso', nome => 'Meus recursos',
  })->status_is(409)->json_has('/error');

  my $upd = $t->put_ok("/api/gestor/$INEP/inventario/categorias/$cat->{id}", $auth->(), json => {
    tipo => 'recurso', nome => 'Recursos da escola',
  })->status_is(200)->tx->res->json;
  is $upd->{nome}, 'Recursos da escola', 'categoria atualizada';

  # item vinculado bloqueia exclusão
  my $item = $t->post_ok("/api/gestor/$INEP/inventario/itens", $auth->(), json => {
    categoria_id => $cat->{id}, nome => 'Lousa', quantidade => 2,
  })->status_is(201)->tx->res->json;

  $t->delete_ok("/api/gestor/$INEP/inventario/categorias/$cat->{id}", $auth->())
    ->status_is(409)->json_has('/error');

  $t->delete_ok("/api/gestor/$INEP/inventario/itens/$item->{id}", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/inventario/categorias/$cat->{id}", $auth->())->status_is(204);
};

subtest 'itens: JSONB livre, valor e fornecedor' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  my $forn = $t->post_ok("/api/gestor/$INEP/inventario/fornecedores", $auth->(), json => {
    nome => 'Águas do Teste', tipo_servico => 'água', email => 'contato@agua.test',
    atributos => { conta => '123-4' },
  })->status_is(201)->tx->res->json;
  is $forn->{atributos}{conta}, '123-4', 'atributos do fornecedor (JSONB)';

  $t->post_ok("/api/gestor/$INEP/inventario/fornecedores", $auth->(), json => {
    nome => 'Águas do Teste',
  })->status_is(409)->json_has('/error');

  my $cats = $t->get_ok("/api/gestor/$INEP/inventario", $auth->())->tx->res->json->{categorias};
  my ($serv) = grep { $_->{tipo} eq 'servico' } @$cats;

  my $item = $t->post_ok("/api/gestor/$INEP/inventario/itens", $auth->(), json => {
    categoria_id  => $serv->{id},
    fornecedor_id => $forn->{id},
    nome          => 'Conta de água',
    identificador => 'HID-001',
    periodicidade => 'mensal',
    valor         => 187.45,
    atributos     => { vencimento => 10 },
  })->status_is(201)->tx->res->json;
  is $item->{valor}, 187.45, 'valor monetário';
  is $item->{categoria_tipo}, 'servico', 'item de serviço';
  is $item->{fornecedor_nome}, 'Águas do Teste', 'fornecedor vinculado';
  is $item->{atributos}{vencimento}, 10, 'atributos livres (JSONB)';

  my $show = $t->get_ok("/api/gestor/$INEP/inventario/itens/$item->{id}", $auth->())
    ->status_is(200)->tx->res->json;
  is $show->{identificador}, 'HID-001', 'detalhe do item';

  my $upd = $t->put_ok("/api/gestor/$INEP/inventario/itens/$item->{id}", $auth->(), json => {
    categoria_id => $serv->{id}, nome => 'Conta de água (reajuste)', valor => 199.9,
  })->status_is(200)->tx->res->json;
  is $upd->{valor}, 199.9, 'item atualizado';

  # filtro por tipo
  my $servs = $t->get_ok("/api/gestor/$INEP/inventario/itens?tipo=servico", $auth->())
    ->status_is(200)->tx->res->json;
  ok scalar(grep { $_->{categoria_tipo} eq 'servico' } @$servs), 'filtro por tipo=servico';

  # validação: atributos deve ser objeto
  $t->post_ok("/api/gestor/$INEP/inventario/itens", $auth->(), json => {
    categoria_id => $serv->{id}, nome => 'X', atributos => [1, 2],
  })->status_is(400)->json_has('/error');

  $t->delete_ok("/api/gestor/$INEP/inventario/itens/$item->{id}", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/inventario/fornecedores/$forn->{id}", $auth->())->status_is(204);
};

subtest 'anexos: upload, download e extensão inválida' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  my $cats = $t->get_ok("/api/gestor/$INEP/inventario", $auth->())->tx->res->json->{categorias};
  my ($cat) = grep { $_->{tipo} eq 'recurso' } @$cats;

  my $item = $t->post_ok("/api/gestor/$INEP/inventario/itens", $auth->(), json => {
    categoria_id => $cat->{id}, nome => 'Item com anexo',
  })->status_is(201)->tx->res->json;

  my $up = $t->post_ok("/api/gestor/$INEP/inventario/itens/$item->{id}/anexos",
    { Authorization => "Bearer $token" },
    form => { arquivo => { content => '%PDF-1.4 nota', filename => 'nota.pdf' } })
    ->status_is(201)->tx->res->json;
  my ($anexo) = @{ $up->{anexos} };
  is $anexo->{nome_original}, 'nota.pdf', 'anexo registrado';
  is $anexo->{mime}, 'application/pdf', 'mime inferido';

  $t->get_ok("/api/gestor/$INEP/inventario/itens/$item->{id}", $auth->())
    ->status_is(200)->json_has('/anexos/0/nome_original');

  $t->get_ok("/api/gestor/$INEP/inventario/itens/$item->{id}/anexos/$anexo->{id}", $auth->())
    ->status_is(200)->content_is('%PDF-1.4 nota');

  $t->post_ok("/api/gestor/$INEP/inventario/itens/$item->{id}/anexos",
    { Authorization => "Bearer $token" },
    form => { arquivo => { content => 'MZ', filename => 'malicioso.exe' } })
    ->status_is(400)->json_has('/error');

  $t->delete_ok("/api/gestor/$INEP/inventario/itens/$item->{id}/anexos/$anexo->{id}", $auth->())
    ->status_is(204);

  $t->delete_ok("/api/gestor/$INEP/inventario/itens/$item->{id}", $auth->())->status_is(204);
};

subtest 'ownership e validações' => sub {
  plan skip_all => 'clean.inventario_itens ausente (migration nao aplicada)'
    unless $has_tables;

  my $other = sub { { Authorization => "Bearer $out_token" } };

  $t->get_ok("/api/gestor/$INEP/inventario", $other->())->status_is(403)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/inventario/categorias", $other->(), json => {
    tipo => 'recurso', nome => 'Invasão',
  })->status_is(403);

  # sem sessão
  $t->get_ok("/api/gestor/$INEP/inventario")->status_is(401)->json_has('/error');

  # validação: tipo inválido e nome vazio
  $t->post_ok("/api/gestor/$INEP/inventario/categorias", $auth->(), json => {
    tipo => 'outro', nome => 'X',
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/gestor/$INEP/inventario/itens", $auth->(), json => {
    nome => 'Sem categoria',
  })->status_is(400)->json_has('/error');
};

done_testing;
