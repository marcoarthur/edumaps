# t/04-api/admin/bootstrap.t
# Teste do login admin via config (PROVISÓRIO) — credenciais plain text no
# edu_maps.conf para bootstrap do operador. INEP reservado 0 + access_role='admin'.
# Planejar substituição por gestão própria de administradores.

use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

# Injeta credenciais admin de teste no config da app (simula edu_maps.conf)
my $admin_email = sprintf('admin.bootstrap.%d@edumaps.test', $$);
my $admin_senha = 'admin-bootstrap-senha-123';
$t->app->config->{admin} = {
  email => $admin_email,
  senha => $admin_senha,
};

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('clean.gestores')");

END {
  return if !$has_tables;
  # limpa gestor admin de bootstrap + sessões
  $dbh->do('DELETE FROM clean.sessoes WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email = ?)', {}, $admin_email);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $admin_email);
}

subtest 'login admin via config (provisório) — 200 + access_role=admin' => sub {
  plan skip_all => 'tabela gestores ausente' unless $has_tables;

  my $ok = $t->post_ok('/api/gestor/login', json => {
    email => $admin_email, senha => $admin_senha,
  })->status_is(200);

  my $json = $ok->tx->res->json;
  ok $json->{token}, 'token de sessão';
  ok $json->{expira_em}, 'expiração';
  ok $json->{gestor}, 'objeto gestor';
  is $json->{gestor}->{access_role}, 'admin', 'papel admin materializado';
  is $json->{gestor}->{cod_inep}, 0, 'INEP reservado 0';
  is $json->{gestor}->{email}, $admin_email, 'email confere';
};

subtest 'login admin via config — falha com senha errada (401)' => sub {
  plan skip_all => 'tabela gestores ausente' unless $has_tables;

  $t->post_ok('/api/gestor/login', json => {
    email => $admin_email, senha => 'senha-errada',
  })->status_is(401);
};

subtest 'login admin via config — sessão válida expõe access_role no /me' => sub {
  plan skip_all => 'tabela gestores ausente' unless $has_tables;

  my $token = $t->post_ok('/api/gestor/login', json => {
    email => $admin_email, senha => $admin_senha,
  })->tx->res->json->{token};

  my $me = $t->get_ok('/api/gestor/me', { Authorization => "Bearer $token" })
    ->status_is(200)->tx->res->json;
  is $me->{access_role}, 'admin', '/me expõe access_role do admin de config';
};

subtest 'login admin via config — acesso ao painel /api/admin/config/tree (200)' => sub {
  plan skip_all => 'tabela gestores ausente' unless $has_tables;

  my $token = $t->post_ok('/api/gestor/login', json => {
    email => $admin_email, senha => $admin_senha,
  })->tx->res->json->{token};

  $t->get_ok('/api/admin/config/tree', { Authorization => "Bearer $token" })
    ->status_is(200);
};

done_testing();