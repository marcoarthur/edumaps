# t/04-api/pesquisa.t
# Testes da API de pesquisas do gestor.
#   Fase 1: perfil (upsert gestor por e-mail), CRUD, finalizar.
#   Fase 2: login do gestor (sessão), link público de resposta (token) e
#           resultados (somente gestor da escola).
# A cadeia só existe onde a migration sqitch foi aplicada (container);
# localmente (cluster antigo, sem pgvector) ela é pulada.
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
my $CPF   = sprintf('1234567%04d', $$ % 10000);
my $EMAIL = sprintf 'teste.pesquisa.%d@edumaps.test', $$;

my $gestor_id;
my $gestor_token;
my $pesquisa_id;
my $TOKEN;
my $TOKEN_RASCUNHO;

my $SENHA  = 'senha123';
my $SENHA2 = 'senha456';

sub seed_gestor {
  my $json = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Teste', email => $EMAIL,
    telefone => '(11) 99999-0000', cargo => 'Diretora', cpf => $CPF,
    senha => $SENHA,
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
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $first = seed_gestor();
  $gestor_id = $first->{id};

  ok $gestor_id > 0, 'gestor criado com id';
  is $first->{email}, $EMAIL, 'email preservado';
  is +($first->{cpf_masc} // ''), '***.***.***-' . substr($CPF, -3), 'CPF devolvido mascarado (LGPD)';
  ok !exists($first->{cpf}), 'CPF completo nunca aparece na resposta';
  is $first->{cod_inep}, $INEP, 'cod_inep vinculado';

  my $again = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Teste Atualizada', email => $EMAIL, senha => $SENHA2,
  })->status_is(200)->tx->res->json;
  is $again->{id}, $gestor_id, 'mesmo e-mail reutiliza o gestor (upsert)';
  is $again->{nome}, 'Gestor Teste Atualizada', 'nome atualizado';
  is +($again->{cpf_masc} // ''), '***.***.***-' . substr($CPF, -3),
    'CPF anterior preservado quando o novo cadastro não o envia';
};

subtest 'perfil: validações' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => 'abc', nome => 'G', email => 'x', cpf => '123', senha => 'x',
  })->status_is(400)->json_has('/error');

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Sem Senha', email => 'semsenha@edumaps.test',
  })->status_is(400)->json_has('/error');
};

subtest 'login do gestor' => sub {
  plan skip_all => 'clean.sessoes ausente (migration nao aplicada)'
    unless $has_tables;

  # senha alterada para $SENHA2 no upsert — testa as duas credenciais.
  $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA,
  })->status_is(401)->json_has('/error');

  my $ok = $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA2,
  })->status_is(200)->tx->res->json;

  $gestor_token = $ok->{token};
  ok $gestor_token, 'login devolve token de sessão';
  is $ok->{gestor}->{email}, $EMAIL, 'login devolve o gestor';
  is $ok->{gestor}->{cod_inep}, $INEP, 'login devolve a escola do gestor';

  my $me = $t->get_ok('/api/gestor/me', { Authorization => "Bearer $gestor_token" })
    ->status_is(200)->tx->res->json;
  is $me->{email}, $EMAIL, '/me valida a sessão';

  $t->get_ok('/api/gestor/me')->status_is(401)->json_has('/error');
  $t->get_ok('/api/gestor/me', { Authorization => 'Bearer token-invalido' })
    ->status_is(401)->json_has('/error');
};

subtest 'criação de pesquisa (rascunho)' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
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
  ok $survey->{token}, 'pesquisa ganha token público ao nascer';

  my ($multi) = grep { $_->{tipo} eq 'multipla' } @{ $survey->{perguntas} };
  is +($multi->{opcoes}->[0]{id}), 'c', 'opções mantêm id do cliente';
  my ($unica) = grep { $_->{tipo} eq 'unica' } @{ $survey->{perguntas} };
  is +($unica->{obrigatoria}), 1, 'pergunta obrigatória marcada';
  my ($texto) = grep { $_->{tipo} eq 'texto' } @{ $survey->{perguntas} };
  ok !defined($texto->{opcoes}), 'texto livre não tem opções';

  # rascunho de 0 perguntas (autosave) continua aceito
  my $empty = $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Rascunho sem perguntas',
    perguntas => [],
  })->status_is(201)->tx->res->json;
  $TOKEN_RASCUNHO = $empty->{token};
};

subtest 'criação: validações de perguntas' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
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
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $list = $t->get_ok("/api/gestor/pesquisas?inep=$INEP")
    ->status_is(200)->tx->res->json;
  ok ref($list) eq 'ARRAY', 'lista é array';
  my ($mine) = grep { $_->{id} == $pesquisa_id } @$list;
  ok $mine, 'pesquisa aparece na lista da escola';
  is +($mine->{gestor}->{nome} // ''), 'Gestor Teste Atualizada', 'lista traz nome do gestor';
  is $mine->{n_perguntas}, 3, 'contagem de perguntas na lista';
  ok $mine->{token}, 'lista também traz o token público';

  $t->get_ok('/api/gestor/pesquisas')->status_is(400);
};

subtest 'detalhe, edição (autosave) e finalização' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $detail = $t->get_ok("/api/gestor/pesquisas/$pesquisa_id")
    ->status_is(200)->tx->res->json;
  is $detail->{titulo}, 'Pesquisa de clima escolar', 'detalhe traz título';
  is +($detail->{gestor}->{email}), $EMAIL, 'detalhe traz gestor';

  my $updated = $t->put_ok("/api/gestor/pesquisas/$pesquisa_id", json => {
    titulo => 'Pesquisa de clima escolar (2026)',
    descricao => 'Revisada.',
    perguntas => [
      {
        texto => 'O projeto político pedagógico atende a comunidade?',
        tipo => 'unica', obrigatoria => 1,
        opcoes => [ { id => 'a', label => 'Sim' }, { id => 'b', label => 'Não' } ],
      },
      { texto => 'Tem alguma sugestão?', tipo => 'texto', obrigatoria => 0, opcoes => undef },
    ],
  })->status_is(200)->tx->res->json;
  is $updated->{titulo}, 'Pesquisa de clima escolar (2026)', 'título editado';
  is scalar(@{ $updated->{perguntas} }), 2, 'autosave substitui as perguntas';

  my $finalized = $t->post_ok("/api/gestor/pesquisas/$pesquisa_id/finalizar")
    ->status_is(200)->tx->res->json;
  is $finalized->{status}, 'publicada', 'finalizar publica a pesquisa';
  $TOKEN = $finalized->{token};
  ok $TOKEN, 'publicada mantém o token para o link de resposta';
};

subtest 'pesquisa publicada é read-only' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
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
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  $t->delete_ok("/api/gestor/pesquisas/$pesquisa_id")->status_is(409); # já publicada

  my $draft = $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Rascunho para excluir',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(201)->tx->res->json;

  $t->delete_ok("/api/gestor/pesquisas/$draft->{id}")->status_is(204);
  $t->get_ok("/api/gestor/pesquisas/$draft->{id}")->status_is(404);
};

subtest 'link público: formulário' => sub {
  plan skip_all => 'clean.gestor_pesquisas_respostas ausente (migration nao aplicada)'
    unless $t->app->schema->storage->dbh->selectrow_array("SELECT to_regclass('clean.gestor_pesquisas_respostas')");

  # rascunho não abre para a comunidade
  $t->get_ok("/api/gestor/pesquisas/publica/$TOKEN_RASCUNHO")
    ->status_is(404)->json_has('/error');

  # publicada sim
  my $form = $t->get_ok("/api/gestor/pesquisas/publica/$TOKEN")
    ->status_is(200)->tx->res->json;
  is $form->{titulo}, 'Pesquisa de clima escolar (2026)', 'form traz o título';
  is scalar(@{ $form->{perguntas} }), 2, 'form traz as perguntas';
  ok !exists($form->{gestor}), 'form não expõe o gestor';
  ok !exists($form->{token}), 'form não devolve o token no corpo';
  my ($opcoes) = grep { ref $_->{opcoes} eq 'ARRAY' } @{ $form->{perguntas} };
  is scalar(@{ $opcoes->{opcoes} }), 2, 'opções disponíveis no form';

  # token inexistente/malformado
  $t->get_ok('/api/gestor/pesquisas/publica/nao-existe-um-token-uuid')->status_is(404);
};

subtest 'link público: registro de resposta' => sub {
  plan skip_all => 'clean.gestor_pesquisas_respostas ausente (migration nao aplicada)'
    unless $t->app->schema->storage->dbh->selectrow_array("SELECT to_regclass('clean.gestor_pesquisas_respostas')");

  my ($unica, $texto) = @{ $t->get_ok("/api/gestor/pesquisas/publica/$TOKEN")->status_is(200)->tx->res->json->{perguntas} };
  $unica = $unica // $texto; # segurança

  # resposta completa válida (2 perguntas → 3 itens: unica=1 + texto=1)
  my $resp = $t->post_ok("/api/gestor/pesquisas/publica/$TOKEN/resposta", json => {
    identificador_dispositivo => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    respostas => [
      { pergunta_id => $unica->{id}, opcao_id => ['b'] },
      { pergunta_id => $texto->{id}, valor_texto => 'Gostaria de mais oficinas.' },
    ],
  })->status_is(201)->tx->res->json;
  ok $resp->{ok}, 'resposta registrada';

  # mesmo dispositivo não responde de novo
  $t->post_ok("/api/gestor/pesquisas/publica/$TOKEN/resposta", json => {
    identificador_dispositivo => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    respostas => [ { pergunta_id => $unica->{id}, opcao_id => ['a'] } ],
  })->status_is(409)->json_has('/error');

  # opção inexistente
  my $outro = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  $t->post_ok("/api/gestor/pesquisas/publica/$TOKEN/resposta", json => {
    identificador_dispositivo => $outro,
    respostas => [
      { pergunta_id => $unica->{id}, opcao_id => ['opcao_nao_existe'] },
      { pergunta_id => $texto->{id}, valor_texto => 'x' },
    ],
  })->status_is(400)->json_has('/error');

  # pergunta obrigatória sem resposta
  $t->post_ok("/api/gestor/pesquisas/publica/$TOKEN/resposta", json => {
    identificador_dispositivo => $outro,
    respostas => [ { pergunta_id => $texto->{id}, valor_texto => 'só a livre' } ],
  })->status_is(400)->json_has('/error');

  # texto muito longo
  $t->post_ok("/api/gestor/pesquisas/publica/$TOKEN/resposta", json => {
    identificador_dispositivo => $outro,
    respostas => [
      { pergunta_id => $unica->{id}, opcao_id => ['a'] },
      { pergunta_id => $texto->{id}, valor_texto => 'x' x 501 },
    ],
  })->status_is(400)->json_has('/error');

  # unica com múltiplas opções
  $t->post_ok("/api/gestor/pesquisas/publica/$TOKEN/resposta", json => {
    identificador_dispositivo => $outro,
    respostas => [
      { pergunta_id => $unica->{id}, opcao_id => ['a', 'b'] },
      { pergunta_id => $texto->{id}, valor_texto => 'x' },
    ],
  })->status_is(400)->json_has('/error');
};

subtest 'resultados: exigem login do gestor da escola' => sub {
  plan skip_all => 'clean.gestor_pesquisas_respostas ausente (migration nao aplicada)'
    unless $t->app->schema->storage->dbh->selectrow_array("SELECT to_regclass('clean.gestor_pesquisas_respostas')");

  # sem sessão
  $t->get_ok("/api/gestor/pesquisas/$pesquisa_id/resultados")->status_is(401)->json_has('/error');

  # gestor de outra escola não vê
  my $outra = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => '11111111', nome => 'Outra Escola', email => "outra.$EMAIL",
    senha => $SENHA2,
  })->status_is(200)->tx->res->json;
  my $outra_login = $t->post_ok('/api/gestor/login', json => {
    email => "outra.$EMAIL", senha => $SENHA2,
  })->status_is(200)->tx->res->json;
  $t->get_ok("/api/gestor/pesquisas/$pesquisa_id/resultados",
      { Authorization => "Bearer $outra_login->{token}" })
    ->status_is(403)->json_has('/error');

  # gestor dono da escola
  my $res = $t->get_ok("/api/gestor/pesquisas/$pesquisa_id/resultados",
      { Authorization => "Bearer $gestor_token" })
    ->status_is(200)->tx->res->json;
  is $res->{n_respostas}, 1, 'conta as respostas válidas';
  my ($u) = grep { $_->{tipo} eq 'unica' } @{ $res->{perguntas} };
  my ($b) = grep { $_->{id} eq 'b' } @{ $u->{opcoes} };
  is $b->{count}, 1, 'agrega por opção';
  my ($tx) = grep { $_->{tipo} eq 'texto' } @{ $res->{perguntas} };
  is scalar(@{ $tx->{respostas_texto} }), 1, 'respostas livres listadas';
  is $tx->{respostas_texto}->[0]{texto}, 'Gostaria de mais oficinas.', 'texto preservado';
};

done_testing();