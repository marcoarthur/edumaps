# t/04-api/pesquisa.t
# Testes da API de pesquisas do gestor.
#   Cadastro (/perfil): só cria conta; e-mail existente (qualquer caixa) é 409
#   e a conta fica intacta. CRUD e finalizar exigem a sessão do gestor e só
#   alcançam pesquisas da escola da sessão.
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
my $outra_token;   # sessão de gestor de outra escola
my %AUTH;          # Authorization do gestor dono
my $pesquisa_id;
my $TOKEN;
my $TOKEN_RASCUNHO;

my $SENHA  = 'senha123';
my $SENHA2 = 'senha456';

# Self-signup governado exige escola existente e bloqueia novo e-mail em escola
# com agenda (409); garante INEPs de teste e remove sobras da base compartilhada.
my $OUTRA_INEP = '11111111';
if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA_INEP) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da API de pesquisas');
  }
}

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
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, "outra.$EMAIL");
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, "admin.$EMAIL");
  $dbh->do('DELETE FROM clean.gestores WHERE cpf = ?', {}, $CPF);
  for my $inep ($INEP, $OUTRA_INEP) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

subtest 'perfil: cadastro só cria conta' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $first = seed_gestor();
  $gestor_id = $first->{id};

  ok $gestor_id > 0, 'gestor criado com id';
  is $first->{email}, $EMAIL, 'email preservado';
  is +($first->{cpf_masc} // ''), '***.***.***-' . substr($CPF, -3), 'CPF devolvido mascarado (LGPD)';
  ok !exists($first->{cpf}), 'CPF completo nunca aparece na resposta';
  is $first->{cod_inep}, $INEP, 'cod_inep vinculado';
  ok defined $first->{created_at}, 'created_at preenchido no cadastro';

  # Mesmo e-mail, outra senha e outra escola: recusado, nada muda.
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA_INEP, nome => 'Quem Não É', email => $EMAIL, senha => $SENHA2,
  })->status_is(409)->json_like('/error', qr/já tem conta/);

  # Caixa diferente é o mesmo e-mail.
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Quem Não É', email => uc $EMAIL, senha => $SENHA2,
  })->status_is(409);

  my $row = $t->app->schema->storage->dbh->selectrow_hashref(
    'SELECT nome, cod_inep, updated_at = created_at AS intacta FROM clean.gestores WHERE id = ?',
    {}, $gestor_id);
  is $row->{nome}, 'Gestor Teste', 'nome não foi sobrescrito';
  is $row->{cod_inep}, $INEP, 'escola não foi trocada';
  ok $row->{intacta}, 'conta não foi alterada';
};

subtest 'perfil: conta admin não é alcançável pelo cadastro' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do(q{INSERT INTO clean.gestores (cod_inep, nome, email, senha_hash, access_role)
             VALUES (0, 'Admin Teste', ?, 'x:y', 'admin')}, {}, "admin.$EMAIL");

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Invasor', email => "Admin.$EMAIL", senha => $SENHA2,
  })->status_is(409);

  my $adm = $dbh->selectrow_hashref(
    'SELECT cod_inep, senha_hash, access_role FROM clean.gestores WHERE email = ?', {}, "admin.$EMAIL");
  is $adm->{senha_hash}, 'x:y', 'senha do admin intacta';
  is $adm->{cod_inep}, 0, 'admin continua sem escola';
  is $adm->{access_role}, 'admin', 'papel preservado';
};

subtest 'perfil: validações' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $err1 = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => 'abc', nome => 'G', email => 'x', cpf => '123', senha => 'x',
  })->status_is(400)->tx->res->json;
  unlike $err1->{error}, qr/^(?:like|size|required|num)$/,
    'erro de validação traz mensagem amigável, não o nome do check';

  my $err2 = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Sem Senha', email => 'semsenha@edumaps.test',
  })->status_is(400)->tx->res->json;
  like $err2->{error}, qr/obrigat/i, 'campo obrigatório ausente tem mensagem clara';
};

subtest 'login do gestor' => sub {
  plan skip_all => 'clean.sessoes ausente (migration nao aplicada)'
    unless $has_tables;

  # a tentativa de recadastro com $SENHA2 não trocou a senha
  $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA2,
  })->status_is(401)->json_has('/error');

  my $ok = $t->post_ok('/api/gestor/login', json => {
    email => uc $EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;

  $gestor_token = $ok->{token};
  %AUTH = (Authorization => "Bearer $gestor_token");
  ok $gestor_token, 'login devolve token de sessão';
  is $ok->{gestor}->{email}, $EMAIL, 'login devolve o gestor';
  is $ok->{gestor}->{cod_inep}, $INEP, 'login devolve a escola do gestor';

  my $me = $t->get_ok('/api/gestor/me', { Authorization => "Bearer $gestor_token" })
    ->status_is(200)->tx->res->json;
  is $me->{email}, $EMAIL, '/me valida a sessão';

  $t->get_ok('/api/gestor/me')->status_is(401)->json_has('/error');
  $t->get_ok('/api/gestor/me', { Authorization => 'Bearer token-invalido' })
    ->status_is(401)->json_has('/error');

  # sessão de um gestor de outra escola, para os testes de escopo
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA_INEP, nome => 'Outra Escola', email => "outra.$EMAIL",
    senha => $SENHA2,
  })->status_is(200);
  $outra_token = $t->post_ok('/api/gestor/login', json => {
    email => "outra.$EMAIL", senha => $SENHA2,
  })->status_is(200)->tx->res->json->{token};
};

subtest 'senha: Argon2id e conversão do formato antigo (#334)' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $dbh  = $t->app->schema->storage->dbh;
  my $hash = sub { $dbh->selectrow_array('SELECT senha_hash FROM clean.gestores WHERE id = ?', {}, $gestor_id) };

  like $hash->(), qr/^\$argon2id\$v=19\$m=65536,t=3,p=1\$/, 'cadastro grava Argon2id';
  unlike $hash->(), qr/\Q$SENHA\E/, 'hash não contém a senha';

  # Simula uma conta do formato antigo: salt:HMAC-SHA256(senha, salt)
  require Digest::SHA;
  my $salt = 'a' x 32;
  my $antigo = $salt . ':' . Digest::SHA::hmac_sha256_hex($SENHA, $salt);
  $dbh->do('UPDATE clean.gestores SET senha_hash = ? WHERE id = ?', {}, $antigo, $gestor_id);

  # senha errada: recusa e NÃO converte
  $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA2 })->status_is(401);
  is $hash->(), $antigo, 'senha errada não regrava o hash';

  # senha certa: entra e o hash vira Argon2id
  $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })->status_is(200);
  my $novo = $hash->();
  like $novo, qr/^\$argon2id\$/, 'login com hash antigo regrava em Argon2id';

  # o login seguinte usa o hash novo e não regrava de novo
  $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })->status_is(200);
  is $hash->(), $novo, 'hash atual não é regravado sem necessidade';

  # parâmetros mais fracos que os atuais também são regravados
  require Crypt::Argon2;
  my $fraco = Crypt::Argon2::argon2id_pass($SENHA, 'b' x 16, 1, '8M', 1, 32);
  $dbh->do('UPDATE clean.gestores SET senha_hash = ? WHERE id = ?', {}, $fraco, $gestor_id);
  $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })->status_is(200);
  like $hash->(), qr/m=65536,t=3,p=1/, 'Argon2id com custo abaixo do atual é regravado';

  # formato desconhecido nunca entra
  $dbh->do('UPDATE clean.gestores SET senha_hash = ? WHERE id = ?', {}, 'qualquer-coisa', $gestor_id);
  $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })->status_is(401);
  $dbh->do('UPDATE clean.gestores SET senha_hash = ? WHERE id = ?', {}, $novo, $gestor_id);
};

subtest 'gestão de pesquisas exige sessão' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  $t->get_ok("/api/gestor/pesquisas?inep=$INEP")->status_is(401);
  $t->post_ok('/api/gestor/pesquisas', json => {
    gestor_id => $gestor_id, titulo => 'Sem sessão', perguntas => [],
  })->status_is(401);
  $t->get_ok('/api/gestor/pesquisas/1')->status_is(401);
  $t->put_ok('/api/gestor/pesquisas/1', json => { titulo => 'x' })->status_is(401);
  $t->post_ok('/api/gestor/pesquisas/1/finalizar')->status_is(401);
  $t->delete_ok('/api/gestor/pesquisas/1')->status_is(401);
};

subtest 'criação de pesquisa (rascunho)' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $survey = $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
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
  my $empty = $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
    gestor_id => $gestor_id, titulo => 'Rascunho sem perguntas',
    perguntas => [],
  })->status_is(201)->tx->res->json;
  $TOKEN_RASCUNHO = $empty->{token};
};

subtest 'criação: validações de perguntas' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
    gestor_id => $gestor_id, titulo => 'Sem opções',
    perguntas => [ { texto => 'Q?', tipo => 'unica', opcoes => [] } ],
  })->status_is(400)->json_has('/error');

  $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
    gestor_id => $gestor_id, titulo => 'Tipo inválido',
    perguntas => [ { texto => 'Q?', tipo => 'radio_livre', opcoes => ['A', 'B'] } ],
  })->status_is(400)->json_has('/error');

  $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
    gestor_id => $gestor_id, titulo => 'Sem texto',
    perguntas => [ { texto => '', tipo => 'texto' } ],
  })->status_is(400)->json_has('/error');

  # gestor_id do corpo é ignorado: o autor é sempre o gestor da sessão
  my $alheio = $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
    gestor_id => 999999, titulo => 'Autor vem da sessão',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(201)->tx->res->json;
  is $alheio->{gestor_id}, $gestor_id, 'autor = gestor da sessão';
  is $alheio->{cod_inep}, $INEP, 'escola = escola da sessão';
  $t->delete_ok("/api/gestor/pesquisas/$alheio->{id}", \%AUTH)->status_is(204);
};

subtest 'lista por escola (?inep=)' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  my $list = $t->get_ok("/api/gestor/pesquisas?inep=$INEP", \%AUTH)
    ->status_is(200)->tx->res->json;
  ok ref($list) eq 'ARRAY', 'lista é array';
  my ($mine) = grep { $_->{id} == $pesquisa_id } @$list;
  ok $mine, 'pesquisa aparece na lista da escola';
  is +($mine->{gestor}->{nome} // ''), 'Gestor Teste', 'lista traz nome do gestor';
  is $mine->{n_perguntas}, 3, 'contagem de perguntas na lista';
  ok $mine->{token}, 'lista também traz o token público';

  # sem ?inep= lista a escola da sessão
  my $sem = $t->get_ok('/api/gestor/pesquisas', \%AUTH)->status_is(200)->tx->res->json;
  ok +(grep { $_->{id} == $pesquisa_id } @$sem), 'sem inep: escola da sessão';
  # outra escola (ou lixo) não é listada
  $t->get_ok("/api/gestor/pesquisas?inep=$OUTRA_INEP", \%AUTH)->status_is(403)->json_has('/error');
  $t->get_ok('/api/gestor/pesquisas?inep=abc', \%AUTH)->status_is(403);
  my $da_outra = $t->get_ok('/api/gestor/pesquisas', { Authorization => "Bearer $outra_token" })
    ->status_is(200)->tx->res->json;
  ok !(grep { $_->{id} == $pesquisa_id } @$da_outra), 'outra escola não vê a pesquisa';
};

subtest 'detalhe, edição (autosave) e finalização' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  # gestor de outra escola: a pesquisa "não existe" para ele
  my %OUTRA = (Authorization => "Bearer $outra_token");
  $t->get_ok("/api/gestor/pesquisas/$pesquisa_id", \%OUTRA)->status_is(404);
  $t->put_ok("/api/gestor/pesquisas/$pesquisa_id", \%OUTRA, json => {
    titulo => 'Sequestro', perguntas => [],
  })->status_is(404);
  $t->post_ok("/api/gestor/pesquisas/$pesquisa_id/finalizar", \%OUTRA)->status_is(404);
  $t->delete_ok("/api/gestor/pesquisas/$pesquisa_id", \%OUTRA)->status_is(404);

  my $detail = $t->get_ok("/api/gestor/pesquisas/$pesquisa_id", \%AUTH)
    ->status_is(200)->tx->res->json;
  is $detail->{titulo}, 'Pesquisa de clima escolar', 'detalhe traz título';
  is +($detail->{gestor}->{email}), $EMAIL, 'detalhe traz gestor';

  my $updated = $t->put_ok("/api/gestor/pesquisas/$pesquisa_id", \%AUTH, json => {
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

  my $finalized = $t->post_ok("/api/gestor/pesquisas/$pesquisa_id/finalizar", \%AUTH)
    ->status_is(200)->tx->res->json;
  is $finalized->{status}, 'publicada', 'finalizar publica a pesquisa';
  $TOKEN = $finalized->{token};
  ok $TOKEN, 'publicada mantém o token para o link de resposta';
};

subtest 'pesquisa publicada é read-only' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  $t->put_ok("/api/gestor/pesquisas/$pesquisa_id", \%AUTH, json => {
    titulo => 'Tentar editar', descricao => 'x',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(409)->json_has('/error');

  $t->post_ok("/api/gestor/pesquisas/$pesquisa_id/finalizar", \%AUTH)
    ->status_is(409)->json_has('/error');

  $t->delete_ok("/api/gestor/pesquisas/$pesquisa_id", \%AUTH)->status_is(409)->json_has('/error');

  $t->get_ok("/api/gestor/pesquisas/$pesquisa_id", \%AUTH)
    ->status_is(200)->json_has('/perguntas/0/texto');
};

subtest 'exclusão de rascunho' => sub {
  plan skip_all => 'clean.gestor_pesquisas ausente (migration nao aplicada)'
    unless $has_tables;

  $t->delete_ok("/api/gestor/pesquisas/$pesquisa_id", \%AUTH)->status_is(409); # já publicada

  my $draft = $t->post_ok('/api/gestor/pesquisas', \%AUTH, json => {
    gestor_id => $gestor_id, titulo => 'Rascunho para excluir',
    perguntas => [ { texto => 'Q?', tipo => 'texto' } ],
  })->status_is(201)->tx->res->json;

  $t->delete_ok("/api/gestor/pesquisas/$draft->{id}", \%AUTH)->status_is(204);
  $t->get_ok("/api/gestor/pesquisas/$draft->{id}", \%AUTH)->status_is(404);
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
  # segmento vazio não pode estourar 500 (Mojolicious injeta o qr no capture)
  $t->get_ok('/api/gestor/pesquisas/publica/')->status_is(404)->json_has('/error');
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
  $t->get_ok("/api/gestor/pesquisas/$pesquisa_id/resultados",
      { Authorization => "Bearer $outra_token" })
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