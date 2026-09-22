# t/04-api/gestor/contatos_folha.t
# Importação dos profissionais da folha de pagamento como contatos da escola
# (nome + cargo), vinculados aos grupos pré-listados da folha. Exige sessão do
# gestor; idempotente.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.remuneracao_municipal')"
);

my $INEP  = '77777740';
my $SENHA = 'senha123';
my $EMAIL = sprintf 'folha.%d@edumaps.test', $$;
my $token;

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia)
            VALUES (2025, ?, ?, 3)', {}, $INEP, 'Escola Folha Contatos');
  # folha: um docente, um administrativo e um "outros" (nomes distintos)
  my @folha = (
    ['Profissionais do magistério', 'Docente habilitado em curso de pedagogia', 'Professora Ana'],
    ['Profissionais do magistério', 'Docente habilitado em curso de pedagogia', 'Professor Beto'],
    ['Outros profissionais da educação', 'Auxiliar/Assistente Educacional', 'Auxiliar Carla'],
  );
  for my $f (@folha) {
    $dbh->do('INSERT INTO clean.remuneracao_municipal
                (ano, mes, nome_profissional, cod_inep, cod_municipio, rede, tipo, categoria, salario_total)
              VALUES (2024, ?, ?, ?, ?, ?, ?, ?, 1000)',
      {}, 'Janeiro', $f->[2], $INEP, '777777', 'Municipal', $f->[0], $f->[1]);
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
}

my $auth = sub { { Authorization => "Bearer $token" } };

subtest 'setup: gestor da escola' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Folha', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  ok $token, 'token de sessão';
};

subtest 'importar-folha: cria contatos (nome + cargo) nos grupos da folha' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok("/api/gestor/$INEP/contatos/importar-folha")->status_is(401);

  my $res = $t->post_ok("/api/gestor/$INEP/contatos/importar-folha", $auth->())
    ->status_is(201)->tx->res->json;
  is $res->{n_inseridos}, 3, 'três profissionais importados';

  my $contatos = $t->get_ok("/api/gestor/$INEP/contatos", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@$contatos), 3, 'agenda passa a ter os contatos';
  my ($ana) = grep { $_->{nome} eq 'Professora Ana' } @$contatos;
  ok $ana, 'docente importado';
  like $ana->{cargo} // '', qr/Docente/, 'cargo vem da categoria da folha';
  is $ana->{grupo_nome}, 'Professores', 'vinculado ao grupo Professores';

  my ($aux) = grep { $_->{nome} eq 'Auxiliar Carla' } @$contatos;
  is $aux->{grupo_nome}, 'Outros', 'auxiliar no grupo Outros';

  my $grupos = $t->get_ok("/api/gestor/$INEP/grupos", $auth->())
    ->status_is(200)->tx->res->json;
  my ($prof) = grep { $_->{nome} eq 'Professores' } @$grupos;
  is $prof->{n_contatos}, 2, 'grupo Professores com 2 contatos';
};

subtest 'importar-folha: idempotente (não duplica)' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  my $res = $t->post_ok("/api/gestor/$INEP/contatos/importar-folha", $auth->())
    ->status_is(201)->tx->res->json;
  is $res->{n_inseridos}, 0, 'segunda rodada não insere nada';

  my $contatos = $t->get_ok("/api/gestor/$INEP/contatos", $auth->())->tx->res->json;
  is scalar(@$contatos), 3, 'agenda continua com 3 contatos';
};

done_testing;
