# t/04-api/pesquisa.t
# Testes da API de pesquisas do gestor (fase 1):
#   POST   /api/gestor/pesquisas/perfil        (upsert gestor por e-mail)
#   GET    /api/gestor/pesquisas?inep=          (lista pesquisas da escola)
#   POST   /api/gestor/pesquisas                (cria rascunho)
#   GET    /api/gestor/pesquisas/:id            (detalhe)
#   PUT    /api/gestor/pesquisas/:id            (autosave — substitui perguntas)
#   POST   /api/gestor/pesquisas/:id/finalizar  (publica)
#   DELETE /api/gestor/pesquisas/:id            (só rascunho)
# Cadeia gestor_pesquisas só existe onde a migration sqitch foi aplicada
# (container); localmente (cluster antigo) é pulada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.gestor_pesquisas')"
);

my $INEP  = '99999999';
my $EMAIL = sprintf 'teste.pesquisa.%d@edumaps.test', $$;
my $CPF   = sprintf('1234567%04d', $$ % 10000);

sub seed_gestor {
  my $json = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Teste', email => $EMAIL,
    telefone => '(11) 99999-0000', cargo => 'Diretora', cpf => $CPF,
  })->status_is(200)->tx->res->json;
  return $json;
}

my $perguntas_validas = [
  {
    texto => 'O projeto político pedagógico atende a comunidade?',
    tipo => 'unica', obrigatoria => 1,
    opcoes => [ { id => 'a', label => 'Sim' }, { id => 'b', label => 'Não' } ],
  },
  {
    texto => 'Quais serviços você considera prioritários?',
    tipo => 'multipla', obrigatoria => 0,
    opcoes => [ { id => 'c', label => 'Biblioteca' }, { id => 'd', label => 'Internet' } ],
  },
  { texto => 'Tem alguma sugestão?', tipo => 'texto', obrigatoria => 0, opcoes => undef },
];

my $gestor_id;
my $pesquisa_id;

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do("DELETE FROM clean.gestor_pesquisas_perguntas
            WHERE pesquisa_id IN (
              SELECT id FROM clean.gestor_pesquisas
              WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email = ?)
            )", {}, $EMAIL) if defined $pesquisa_id;
  $dbh->do("DELETE FROM clean.gestor_pesquisas
            WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email = ?)",
           {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE cpf = ?', {}, $CPF);
}

subtest 'perfil: upsert do gestor por e-mail' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  my $first = seed_gestor();
  $gestor_id = $first->{id};

  ok $gestor_id > 0, 'gestor criado com id';
  is $first->{email}, $EMAIL, 'email preservado';
  is +($first->{cpf_masc} // ''), '***.***.***-' . substr($CPF, -3), 'CPF devolvido mascarado (LGPD)';
  ok !exists($first->{cpf}), 'CPF completo nunca aparece na resposta';
  is $first->{cod_inep}, $INEP, 'cod_inep vinculado';

  my $again = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Teste Atualizada', email => $EMAIL,
  })->status_is(200)->tx->res->json;
  is $again->{id}, $gestor_id, 'mesmo e-mail reutiliza o gestor (upsert)';
  is $again->{nome}, 'Gestor Teste Atualizada', 'nome atualizado';
  is +($again->{cpf_masc} // ''), '***.***.***-' . substr($CPF, -3),
    'CPF anterior preservado quando o novo cadastro não o envia';
};

subtest 'perfil: validações' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => 'abc', nome => 'G', email => 'x', cpf => '123',
  })->status_is(400)->json_has('/error');
};

subtest 'criação de pesquisa (rascunho)' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  my $survey = $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id,
    titulo => 'Pesquisa de clima escolar',
    descricao => 'Levantamento de percepção da comunidade.',
    perguntas => $perguntas_validas,
  })->status_is(201)->tx->res->json;

  $pesquisa_id = $survey->{id};
  ok $pesquisa_id > 0, 'pesquisa criada com id';
  is $survey->{status}, 'rascunho', 'nasce como rascunho';
  is $survey->{cod_inep}, $INEP, 'cod_inep herdado do gestor';
  is scalar(@{ $survey->{perguntas} }), 3, '3 perguntas persistidas';

  my ($multi) = grep { $_->{tipo} eq 'multipla' } @{ $survey->{perguntas} };
  is +($multi->{opcoes}->[0]{id}), 'c', 'opções mantêm id do cliente';
  my ($unica) = grep { $_->{tipo} eq 'unica' } @{ $survey->{perguntas} };
  is +($unica->{obrigatoria}), 1, 'pergunta obrigatória marcada';
  my ($texto) = grep { $_->{tipo} eq 'texto' } @{ $survey->{perguntas} };
  ok !defined($texto->{opcoes}), 'texto livre não tem opções';
};

subtest 'criação: validações de perguntas' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Sem opções',
    perguntas => [ { texto => 'Q?', tipo => 'unica', opcoes => [] } ],
  })->status_is(400)->json_has('/error');

  $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Tipo inválido',
    perguntas => [ { texto => 'Q?', tipo => 'radio_livre', opcoes => ['A', 'B'] } ],
  })->status_is(400)->json_has('/error');

  $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Sem texto',
    perguntas => [ { texto => '', tipo => 'texto' } ],
  })->status_is(400)->json_has('/error');

  $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => 999999, titulo => 'Gestor inexistente',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(404)->json_has('/error');
};

subtest 'lista por escola (?inep=)' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  my $list = $t->get_ok("/api/gestor/pesquisas?inep=$INEP")
    ->status_is(200)->tx->res->json;
  ok ref($list) eq 'ARRAY', 'lista é array';
  my ($mine) = grep { $_->{id} == $pesquisa_id } @$list;
  ok $mine, 'pesquisa aparece na lista da escola';
  is +($mine->{gestor}->{nome} // ''), 'Gestor Teste Atualizada', 'lista traz nome do gestor';
  is $mine->{n_perguntas}, 3, 'contagem de perguntas na lista';

  $t->get_ok('/api/gestor/pesquisas')->status_is(400);
};

subtest 'detalhe, edição (autosave) e finalização' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  my $detail = $t->get_ok("/api/gestor/pesquisas/$pesquisa_id")
    ->status_is(200)->tx->res->json;
  is $detail->{titulo}, 'Pesquisa de clima escolar', 'detalhe traz título';
  is +($detail->{gestor}->{email}), $EMAIL, 'detalhe traz gestor';

  my $updated = $t->put_ok("/api/gestor/pesquisas/$pesquisa_id", json => {
    titulo => 'Pesquisa de clima escolar (2026)',
    descricao => 'Revisada.',
    perguntas => [ {
      texto => 'O projeto político pedagógico atende a comunidade?',
      tipo => 'unica', obrigatoria => 1,
      opcoes => [ { id => 'a', label => 'Sim' }, { id => 'b', label => 'Não' } ],
    } ],
  })->status_is(200)->tx->res->json;
  is $updated->{titulo}, 'Pesquisa de clima escolar (2026)', 'título editado';
  is scalar(@{ $updated->{perguntas} }), 1, 'autosave substitui as perguntas';

  my $finalized = $t->post_ok("/api/gestor/pesquisas/$pesquisa_id/finalizar")
    ->status_is(200)->tx->res->json;
  is $finalized->{status}, 'publicada', 'finalizar publica a pesquisa';
};

subtest 'pesquisa publicada é read-only' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  $t->put_ok("/api/gestor/pesquisas/$pesquisa_id", json => {
    titulo => 'Tentar editar', descricao => 'x',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(409)->json_has('/error');

  $t->post_ok("/api/gestor/pesquisas/$pesquisa_id/finalizar")
    ->status_is(409)->json_has('/error');

  $t->delete_ok("/api/gestor/pesquisas/$pesquisa_id")->status_is(409)->json_has('/error');

  $t->get_ok("/api/gestor/pesquisas/$pesquisa_id")
    ->status_is(200)->json_has('/perguntas/0/texto');
};

subtest 'exclusão de rascunho' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration gestor_pesquisas nao aplicada)'
    unless $has_tables;

  my $draft = $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Rascunho para excluir',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(201)->tx->res->json;

  $t->delete_ok("/api/gestor/pesquisas/$draft->{id}")->status_is(204);
  $t->get_ok("/api/gestor/pesquisas/$draft->{id}")->status_is(404);
};

done_testing();