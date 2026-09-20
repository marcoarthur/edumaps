# t/04-api/gestor/reunioes.t
# Testes da API de reuniões e atas do gestor (módulo Reuniões e Atas):
#   wizard de agendamento (quando/quem/aviso/onde/pauta), busca, transições
#   de status, ata e anexos (upload real em upload_dir). Exige sessão do
#   gestor da escola. Só roda onde gestor_reunioes foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use File::Glob qw(bsd_glob);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.reunioes')"
);

my $UPLOAD_DIR = "/tmp/edumaps_reunioes_test_$$";
$t->app->config->{upload_dir} = $UPLOAD_DIR;

my $INEP  = '99999999';
my $CPF   = sprintf('7654321%04d', $$ % 10000);
my $EMAIL = sprintf 'teste.reunioes.%d@edumaps.test', $$;
my $SENHA = 'senha123';

my ($token, $gestor_id);
my $auth = sub { { Authorization => "Bearer $token" } };

my $out_token;
my $OUTRA = '88888888';
my $out_email = sprintf 'outra.reunioes.%d@edumaps.test', $$;

# Self-signup governado exige escola existente; garante INEPs de teste no
# clean.escolas e remove sobras de execuções anteriores (base compartilhada).
if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da API de reuniões');
  }
}

my (%contato_ana, %contato_jao, %grupo_pais, $reuniao_id);

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $out_email);
  $dbh->do('DELETE FROM clean.gestores WHERE cpf = ?', {}, $CPF);
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
  system('rm', '-rf', $UPLOAD_DIR);
}

subtest 'setup: gestor + contatos/grupos' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $perfil = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Reuniões', email => $EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $gestor_id = $perfil->{id};

  my $login = $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $token = $login->{token};

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Outra Escola', email => $out_email, senha => $SENHA,
  })->status_is(200);
  $out_token = $t->post_ok('/api/gestor/login', json => {
    email => $out_email, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};

  %contato_ana = %{ $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'Ana Professora', email => 'ana.reuniao@edu.test', telefone => '+5511999990001',
  })->status_is(201)->tx->res->json };

  %grupo_pais = %{ $t->post_ok("/api/gestor/$INEP/grupos", $auth->(), json => { nome => 'Pais Reuniões' })
    ->status_is(201)->tx->res->json };

  %contato_jao = %{ $t->post_ok("/api/gestor/$INEP/contatos", $auth->(), json => {
    nome => 'João Pai', email => 'joao.reuniao@edu.test', grupo_id => $grupo_pais{id},
  })->status_is(201)->tx->res->json };
};

subtest 'agendamento (wizard completo): grupos expandidos + individuais' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $r = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Reunião de planejamento pedagógico',
    quando => '2026-10-10T14:30',
    duracao_min => 90,
    onde_label => 'Google Meet',
    onde_link => 'https://meet.google.com/abc-defg-hij',
    aviso_metodo => 'todos',
    pauta_texto => '1. Metas do bimestre; 2. Calendário escolar.',
    contato_ids => [ $contato_ana{id} ],
    grupo_ids   => [ $grupo_pais{id} ],
  })->status_is(201)->tx->res->json;

  $reuniao_id = $r->{id};
  ok $reuniao_id > 0, 'reunião criada com id';
  is $r->{titulo}, 'Reunião de planejamento pedagógico', 'título';
  is $r->{status}, 'agendada', 'nasce agendada';
  is $r->{aviso_metodo}, 'todos', 'método de aviso';
  is $r->{duracao_min}, 90, 'duração';
  is $r->{onde_label}, 'Google Meet', 'onde';
  is scalar(@{ $r->{participantes} }), 2, 'participantes = pessoa + grupo expandido';
  my @nomes = sort map { $_->{nome} } @{ $r->{participantes} };
  is $nomes[0], 'Ana Professora', 'primeira participante';
  is $nomes[1], 'João Pai', 'grupo expandido em contato';
  my ($pai) = grep { $_->{nome} eq 'João Pai' } @{ $r->{participantes} };
  is $pai->{via_grupo_nome}, 'Pais Reuniões', 'snapshot guarda via_grupo (origem)';
  is $r->{gestor}{nome}, 'Gestor Reuniões', 'gestor resolvido';
};

subtest 'validação do wizard' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Sem quando', contato_ids => [ $contato_ana{id} ],
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Sem convidados', quando => '2026-10-10T08:00',
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Data quebrada', quando => '2026-02-30T10:00',
    contato_ids => [ $contato_ana{id} ],
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Aviso inválido', quando => '2026-10-10T08:00',
    aviso_metodo => 'telegrama', contato_ids => [ $contato_ana{id} ],
  })->status_is(400)->json_has('/error');
};

subtest 'quando: aceita o formato do wizard e erro amigável' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  # Contrato do buildReuniaoPayload do frontend: "YYYY-MM-DD HH:MM" (espaço).
  my $r = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Formato do wizard', quando => '2026-10-15 14:30',
    contato_ids => [ $contato_ana{id} ],
  })->status_is(201)->tx->res->json;
  ok $r->{id} > 0, 'aceita data com espaço (formato enviado pelo frontend)';

  # Data realmente inválida -> 400 com mensagem legível, não o nome do check.
  my $err = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Data ruim', quando => '15/10/2026 14:30',
    contato_ids => [ $contato_ana{id} ],
  })->status_is(400)->tx->res->json;
  unlike $err->{error}, qr/^(?:like|size|required|num)$/,
    'erro traz mensagem amigável, não o nome do check';

  $t->delete_ok("/api/gestor/$INEP/reunioes/$r->{id}", $auth->())->status_is(204);
};

subtest 'busca de reuniões passadas: lista com filtros' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $list = $t->get_ok("/api/gestor/$INEP/reunioes", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@$list), 1, 'só a reunião agendada';
  is $list->[0]{n_participantes}, 2, 'contagem de participantes na lista';
  is $list->[0]{tem_ata}, 0, 'sem ata ainda';

  my $q = $t->get_ok("/api/gestor/$INEP/reunioes?q=planejamento", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@$q), 1, 'busca por título encontra';

  my $none = $t->get_ok("/api/gestor/$INEP/reunioes?q=churrasco", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@$none), 0, 'busca sem resultado';

  my $status = $t->get_ok("/api/gestor/$INEP/reunioes?status=realizada", $auth->())
    ->status_is(200)->tx->res->json;
  is scalar(@$status), 0, 'filtro por status';
};

subtest 'edição (só enquanto agendada) e convite copiável' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $upd = $t->put_ok("/api/gestor/$INEP/reunioes/$reuniao_id", $auth->(), json => {
    titulo => 'Planejamento (remarcado)',
    quando => '2026-10-11T09:00',
    duracao_min => 60,
    aviso_metodo => 'whatsapp',
    onde_label => 'Sala da direção',
    pauta_texto => 'Pauta atualizada.',
    contato_ids => [ $contato_ana{id} ],
    grupo_ids   => [ $grupo_pais{id} ],
  })->status_is(200)->tx->res->json;
  is $upd->{titulo}, 'Planejamento (remarcado)', 'título atualizado';
  is $upd->{aviso_metodo}, 'whatsapp', 'método de aviso muda';

  my $bad = $t->put_ok("/api/gestor/$INEP/reunioes/999999", $auth->(), json => {
    titulo => 'Inexistente', quando => '2026-10-11T09:00',
    contato_ids => [ $contato_ana{id} ],
  })->status_is(404)->tx->res->json;
  ok $bad->{error}, 'reunião inexistente -> 404';
};

subtest 'transições: realizada (habilita ata) e cancelada' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $r = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Reunião extra do conselho', quando => '2026-11-01T10:00',
    aviso_metodo => 'email', contato_ids => [ $contato_ana{id} ],
  })->status_is(201)->tx->res->json;

  my $canc = $t->post_ok("/api/gestor/$INEP/reunioes/$r->{id}/cancelar", $auth->())
    ->status_is(200)->tx->res->json;
  is $canc->{status}, 'cancelada', 'agendada -> cancelada';

  # cancelada não recebe ata
  $t->post_ok("/api/gestor/$INEP/reunioes/$r->{id}/ata", $auth->(), json => {
    ata_texto => 'Início da ata...',
  })->status_is(409)->json_has('/error');

  my $r2 = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Conselho de classe', quando => '2026-11-05T13:00',
    contato_ids => [ $contato_ana{id} ], grupo_ids => [ $grupo_pais{id} ],
  })->status_is(201)->tx->res->json;

  my $real = $t->post_ok("/api/gestor/$INEP/reunioes/$r2->{id}/marcar-realizada", $auth->())
    ->status_is(200)->tx->res->json;
  is $real->{status}, 'realizada', 'agendada -> realizada';

  # realizada não pode ser excluída
  $t->delete_ok("/api/gestor/$INEP/reunioes/$r2->{id}", $auth->())
    ->status_is(409)->json_has('/error');

  # cancelada pode ser excluída
  $t->delete_ok("/api/gestor/$INEP/reunioes/$r->{id}", $auth->())->status_is(204);
};

subtest 'ata (texto) e download do convite' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $aks = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Reunião para ata', quando => '2026-11-10T09:30',
    contato_ids => [ $contato_ana{id} ],
  })->status_is(201)->tx->res->json;

  my $with_ata = $t->post_ok("/api/gestor/$INEP/reunioes/$aks->{id}/ata", $auth->(), json => {
    ata_texto => "Ata do dia...\n- ponto 1\n- ponto 2",
  })->status_is(200)->tx->res->json;
  is $with_ata->{ata_texto}, "Ata do dia...\n- ponto 1\n- ponto 2", 'ata salva';

  my $detail = $t->get_ok("/api/gestor/$INEP/reunioes/$aks->{id}", $auth->())
    ->status_is(200)->tx->res->json;
  is $detail->{ata_texto}, $with_ata->{ata_texto}, 'detalhe traz a ata';
  is scalar(@{ $detail->{anexos} }), 0, 'sem anexos ainda';
};

subtest 'anexos: upload real (pauta e ata) + download' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $r = $t->post_ok("/api/gestor/$INEP/reunioes", $auth->(), json => {
    titulo => 'Reunião com anexos', quando => '2026-11-20T15:00',
    contato_ids => [ $contato_ana{id} ],
  })->status_is(201)->tx->res->json;

  # pauta.pdf
  my $pauta = $t->post_ok("/api/gestor/$INEP/reunioes/$r->{id}/anexos/pauta",
    { Authorization => "Bearer $token" },
    form => { arquivo => { content => '%PDF-1.4 demo', filename => 'pauta.pdf' } })
    ->status_is(201)->tx->res->json;
  my ($pa) = grep { $_->{tipo} eq 'pauta' } @{ $pauta->{anexos} };
  is $pa->{nome_original}, 'pauta.pdf', 'anexo pauta registrado';
  is $pa->{mime}, 'application/pdf', 'mime pelo tipo MIME';
  ok $pa->{tamanho} > 0, 'tamanho em bytes';

  # sobrescreve pauta (um por tipo)
  $t->post_ok("/api/gestor/$INEP/reunioes/$r->{id}/anexos/pauta",
    { Authorization => "Bearer $token" },
    form => { arquivo => { content => '%PDF-1.4 novo', filename => 'pauta2.pdf' } })
    ->status_is(201);
  my $detail = $t->get_ok("/api/gestor/$INEP/reunioes/$r->{id}", $auth->())
    ->status_is(200)->tx->res->json;
  my (@pautas) = grep { $_->{tipo} eq 'pauta' } @{ $detail->{anexos} };
  is scalar(@pautas), 1, 'uma única pauta por reunião (sobrescreve)';
  is $pautas[0]->{nome_original}, 'pauta2.pdf', 'a mais recente vence';

  # download legítimo (com sessão)
  $t->get_ok("/api/gestor/$INEP/reunioes/$r->{id}/anexos/pauta", $auth->())
    ->status_is(200)->content_is('%PDF-1.4 novo');

  # download fora do escopo (outra escola) -> 403
  $t->get_ok("/api/gestor/$INEP/reunioes/$r->{id}/anexos/pauta",
    { Authorization => "Bearer $out_token" })->status_is(403);

  # download sem sessão -> 401
  $t->get_ok("/api/gestor/$INEP/reunioes/$r->{id}/anexos/pauta")->status_is(401);

  # extensão não permitida
  $t->post_ok("/api/gestor/$INEP/reunioes/$r->{id}/anexos/ata",
    { Authorization => "Bearer $token" },
    form => { arquivo => { content => 'MZ...', filename => 'ata.exe' } })
    ->status_is(400)->json_has('/error');
};

subtest 'ownership: gestor de outra escola não vê reuniões' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $other = sub { { Authorization => "Bearer $out_token" } };
  $t->get_ok("/api/gestor/$INEP/reunioes", $other->())->status_is(403)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/reunioes", $other->(), json => {
    titulo => 'Invasão', quando => '2026-12-01T10:00', contato_ids => [ $contato_ana{id} ],
  })->status_is(403);
  $t->get_ok("/api/gestor/$INEP/reunioes/$reuniao_id", $other->())->status_is(403);
};

done_testing();