# t/04-api/gestor/documentos.t
# Testes da API de documentos e planos escolares:
#   pastas/subpastas, upload com versionamento (sobrescrita = nova versão),
#   tags livres, movimentação/renomeação com auditoria e feed de atividade.
# Exige sessão do gestor da escola (Bearer). Só roda onde a migration
# gestor_documentos foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use File::Path qw(rmtree);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT (to_regclass('clean.pastas_escolares') IS NOT NULL)
     AND (to_regclass('clean.escola_documentos') IS NOT NULL)
     AND (to_regclass('clean.escola_documentos_versoes') IS NOT NULL)
     AND (to_regclass('clean.escola_documentos_auditoria') IS NOT NULL)"
);

my $UPLOAD_DIR = "/tmp/edumaps_documentos_test_$$";
$t->app->config->{upload_dir} = $UPLOAD_DIR;

my $INEP  = '99999999';
my $CPF   = sprintf('1122334%04d', $$ % 10000);
my $EMAIL = sprintf 'teste.documentos.%d@edumaps.test', $$;
my $SENHA = 'senha123';

my ($token, $gestor_id);
my $auth = sub { { Authorization => "Bearer $token" } };

my $out_token;
my $OUTRA = '88888888';
my $out_email = sprintf 'outra.documentos.%d@edumaps.test', $$;

# Self-signup governado exige escola existente; garante INEPs de teste no
# clean.escolas e remove sobras de execuções anteriores (base compartilhada).
if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.escola_documentos_auditoria WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escola_documentos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.pastas_escolares WHERE cod_inep = ?', {}, $inep);
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da API de documentos');
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $out_email);
  $dbh->do('DELETE FROM clean.gestores WHERE cpf = ?', {}, $CPF);
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.escola_documentos_auditoria WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escola_documentos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.pastas_escolares WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
  rmtree($UPLOAD_DIR) if -d $UPLOAD_DIR;
}

subtest 'setup: gestor da escola + sessão' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Documentos', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  my $login = $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $token     = $login->{token};
  $gestor_id = $login->{gestor}{id};

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Outra Escola', email => $out_email, senha => $SENHA,
  })->status_is(200);
  my $out_log = $t->post_ok('/api/gestor/login', json => {
    email => $out_email, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $out_token = $out_log->{token};
};

subtest 'sem sessão: 401 e outra escola: 403' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  $t->get_ok("/api/gestor/$INEP/documentos")->status_is(401);
  $t->post_ok("/api/gestor/$INEP/documentos/pastas", json => { nome => 'X' })->status_is(401);

  $t->get_ok("/api/gestor/$INEP/documentos", { Authorization => "Bearer $out_token" })->status_is(403);

  my $arvore = $t->get_ok("/api/gestor/$INEP/documentos", $auth->())->status_is(200)->tx->res->json;
  is scalar(@{ $arvore->{pastas} }), 0, 'escola sem pastas ainda';
  is scalar(@{ $arvore->{documentos} }), 0, 'escola sem documentos ainda';
  is scalar(@{ $arvore->{tags} }), 0, 'escola sem tags ainda';
};

subtest 'pastas: criar, duplicata (409), renomear, mover, ciclo (409), excluir conteúdo (409)' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  my $raiz = $t->post_ok("/api/gestor/$INEP/documentos/pastas", $auth->(), json => {
    nome => 'PPP',
  })->status_is(201)->tx->res->json;
  ok $raiz->{id} > 0, 'pasta criada';
  ok !defined $raiz->{pasta_pai_id}, 'pasta na raiz';

  # regressão: criar na raiz com pasta_pai_id '' (o frontend envia vazio)
  my $raiz_vazia = $t->post_ok("/api/gestor/$INEP/documentos/pastas", $auth->(), json => {
    nome => 'Raiz explicita', pasta_pai_id => '',
  })->status_is(201)->tx->res->json;
  ok !defined $raiz_vazia->{pasta_pai_id}, 'pasta_pai_id vazio = raiz';

  # irmãos
  my $externo = $t->post_ok("/api/gestor/$INEP/documentos/pastas", $auth->(), json => {
    nome => 'Geral',
  })->status_is(201)->tx->res->json;

  my $sub = $t->post_ok("/api/gestor/$INEP/documentos/pastas", $auth->(), json => {
    nome => '2026', pasta_pai_id => $raiz->{id},
  })->status_is(201)->tx->res->json;
  is $sub->{pasta_pai_id}, $raiz->{id}, 'subpasta aponta para o pai';

  # nome duplicado na mesma pasta -> 409 (constraint única)
  $t->post_ok("/api/gestor/$INEP/documentos/pastas", $auth->(), json => {
    nome => 'PPP',
  })->status_is(409);

  my $renomeada = $t->patch_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->(), json => {
    nome => 'PPP da escola',
  })->status_is(200)->tx->res->json;
  is $renomeada->{nome}, 'PPP da escola', 'pasta renomeada';

  # mover para um irmão (raiz -> externo)
  my $movida = $t->patch_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->(), json => {
    pasta_pai_id => $externo->{id},
  })->status_is(200)->tx->res->json;
  is $movida->{pasta_pai_id}, $externo->{id}, 'pasta movida';

  # mover para si mesma -> ciclo (409)
  $t->patch_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->(), json => {
    pasta_pai_id => $raiz->{id},
  })->status_is(409);

  # mover para dentro do próprio descendente -> ciclo (409)
  $t->patch_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->(), json => {
    pasta_pai_id => $sub->{id},
  })->status_is(409);

  # pasta com conteúdo não pode ser excluída
  $t->delete_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->())->status_is(409);

  # volta para a raiz (pasta_pai_id vazio = mover para a raiz)
  my $de_volta = $t->patch_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->(), json => {
    pasta_pai_id => '',
  })->status_is(200)->tx->res->json;
  ok !defined $de_volta->{pasta_pai_id}, 'pasta voltou para a raiz';

  # exclui filhas/subpastas vazias primeiro, depois a raiz e o irmão
  $t->delete_ok("/api/gestor/$INEP/documentos/pastas/$sub->{id}", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/documentos/pastas/$raiz->{id}", $auth->())->status_is(204);
  $t->delete_ok("/api/gestor/$INEP/documentos/pastas/$externo->{id}", $auth->())->status_is(204);
};

my ($doc_id, $pasta_id);

subtest 'documentos: upload cria versão 1; mesmo nome = nova versão (v2)' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  $pasta_id = $t->post_ok("/api/gestor/$INEP/documentos/pastas", $auth->(), json => {
    nome => 'Planejamentos',
  })->status_is(201)->tx->res->json->{id};

  my $v1 = $t->post_ok("/api/gestor/$INEP/documentos", $auth->(),
    form => {
      arquivo  => { content => '%PDF-1.4 PPP v1', filename => 'ppp.pdf' },
      pasta_id => $pasta_id,
    },
  )->status_is(201)->tx->res->json;
  $doc_id = $v1->{documento_id};
  is $v1->{versao}, 1, 'primeiro upload = versao 1';
  is $v1->{novo},  1, 'marca novo documento';
  is $v1->{nome}, 'ppp.pdf', 'nome = nome do arquivo';
  is $v1->{pasta_id}, $pasta_id, 'documento dentro da pasta';

  my $v2 = $t->post_ok("/api/gestor/$INEP/documentos", $auth->(),
    form => {
      arquivo => { content => '%PDF-1.4 PPP v2', filename => 'ppp.pdf' },
      pasta_id => $pasta_id,
      tags => ['PPP', '2026'],
    },
  )->status_is(201)->tx->res->json;
  is $v2->{documento_id}, $doc_id, 'mesmo documento (sobrescrita)';
  is $v2->{versao}, 2, 'nova versao';
  is $v2->{novo},  0, 'marca sobrescrita';

  my $arvore = $t->get_ok("/api/gestor/$INEP/documentos", $auth->())->status_is(200)->tx->res->json;
  my ($d) = grep { $_->{id} == $doc_id } @{ $arvore->{documentos} };
  ok $d, 'documento na árvore';
  is $d->{versao_atual}, 2, 'versão atual = 2';
  is $d->{pasta_id}, $pasta_id, 'documento dentro da pasta';
  ok scalar(@{ $d->{tags} }) >= 2, 'tags gravadas no upload';
  ok scalar(grep { $_ eq 'PPP' } @{ $arvore->{tags} }), 'tag agregada na árvore';
};

subtest 'documentos: download da última versão e de versões antigas' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  my $novo_doc = $t->post_ok("/api/gestor/$INEP/documentos", $auth->(),
    form => { arquivo => { content => 'AAA versao antiga', filename => 'relatorio.txt' } },
  )->status_is(201)->tx->res->json;
  my $novo_id = $novo_doc->{documento_id};

  $t->post_ok("/api/gestor/$INEP/documentos", $auth->(),
    form => { arquivo => { content => 'BBB versao nova', filename => 'relatorio.txt' } },
  )->status_is(201);

  $t->get_ok("/api/gestor/$INEP/documentos/$novo_id/download", $auth->())
    ->status_is(200)->content_is('BBB versao nova');
  $t->get_ok("/api/gestor/$INEP/documentos/$novo_id/download?versao=1", $auth->())
    ->status_is(200)->content_is('AAA versao antiga');

  # extensão não permitida -> 400
  $t->post_ok("/api/gestor/$INEP/documentos", $auth->(),
    form => { arquivo => { content => 'MZ', filename => 'malicioso.exe' } },
  )->status_is(400);
};

subtest 'documentos: renomear, mover, tags (com auditoria), versões e histórico' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  my $renomeado = $t->patch_ok("/api/gestor/$INEP/documentos/$doc_id", $auth->(), json => {
    nome => 'PPP da escola.pdf',
  })->status_is(200)->tx->res->json;
  is $renomeado->{nome}, 'PPP da escola.pdf', 'documento renomeado';

  my $tags = $t->put_ok("/api/gestor/$INEP/documentos/$doc_id/tags", $auth->(), json => {
    tags => ['PPP', 'Ensino Médio'],
  })->status_is(200)->tx->res->json;
  ok scalar(grep { $_ eq 'Ensino Médio' } @{ $tags->{tags} }), 'tags substituídas';

  my $versoes = $t->get_ok("/api/gestor/$INEP/documentos/$doc_id/versoes", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@{ $versoes->{versoes} }), 2, 'histórico de versões (2)';
  is $versoes->{versoes}[0]{versao}, 2, 'versões ordenadas (recente primeiro)';

  my $historico = $t->get_ok("/api/gestor/$INEP/documentos/$doc_id/historico", $auth->())
    ->status_is(200)->tx->res->json;
  my %acoes = map { $_->{acao} => 1 } @{ $historico->{historico} };
  ok $acoes{criado},      'auditoria: criado';
  ok $acoes{sobrescrito}, 'auditoria: sobrescrito';
  ok $acoes{tags},        'auditoria: tags';
  ok $acoes{renomeado},   'auditoria: renomeado';
};

subtest 'documentos: feed de atividade da escola' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  my $feed = $t->get_ok("/api/gestor/$INEP/documentos/auditoria", $auth->())
    ->status_is(200)->tx->res->json;
  ok scalar(@{ $feed->{auditoria} }) >= 4, 'feed de atividade com eventos';
  my $primeiro = $feed->{auditoria}[0];
  ok $primeiro->{acao}, 'evento com ação';
  ok $primeiro->{gestor}, 'evento com autor (nome do gestor)';
  is ref($primeiro->{detalhes}), 'HASH', 'detalhes JSONB presentes';
};

subtest 'documentos: exclusão remove arquivo físico' => sub {
  plan skip_all => 'gestor_documentos ausente (migration nao aplicada)'
    unless $has_tables;

  my $del_id = $t->post_ok("/api/gestor/$INEP/documentos", $auth->(),
    form => { arquivo => { content => 'vou sumir', filename => 'temporario.txt' } },
  )->status_is(201)->tx->res->json->{documento_id};

  $t->get_ok("/api/gestor/$INEP/documentos/$del_id/download", $auth->())
    ->status_is(200)->content_is('vou sumir');

  $t->delete_ok("/api/gestor/$INEP/documentos/$del_id", $auth->())->status_is(204);
  $t->get_ok("/api/gestor/$INEP/documentos/$del_id/download", $auth->())->status_is(404);

  ok !-d $UPLOAD_DIR || !grep({ -f "$UPLOAD_DIR/$_" } @{ $t->app->schema->storage->dbh->selectall_arrayref(
    'SELECT caminho FROM clean.escola_documentos_versoes WHERE documento_id = ?', { Slice => {} }, $del_id,
  ) }), 'nenhum arquivo da versão sobrevive';
};

done_testing;