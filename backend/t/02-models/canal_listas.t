# t/02-models/canal_listas.t
# Testes da regra de negócio do módulo Canal (issue #208 — Fase 0, canal
# telefone, sem validação): listas nomeadas com QR para autoinscrição.
#
# Cobre: normalização de telefone, ciclo de vida do token (gerar / rotacionar /
# revogar / expirar / max_usos), gestão de listas (criar/detalhar/listar/
# desativar) e a submissão pública com dedupe NÃO DESTRUTIVO (reuso do contato +
# marcação duplicado_de/conflito, sem apagar nada), além da config
# `canais.inscricao.*`.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;

my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_listas')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model = $t->app->model('Canal');

my $INEP     = 99770000 + ($$ % 1000);
my $INEP_2   = 99880000 + ($$ % 1000);   # outro gestor/outra escola (posse)
my $GESTOR   = sprintf 'gestor.listas.%d@edumaps.test', $$;
my $GESTOR_2 = sprintf 'gestor2.listas.%d@edumaps.test', $$;

my ($gestor_id, $gestor2_id, $lista_id, $token, $contato_primeiro);

# Sempre que o teste toca nas tabelas novas, limpa o que criou — ordem de
# dependência reversa (inscricoes -> qrcodes/membros -> listas -> contatos ->
# gestores -> escolas).
sub limpa_tudo {
  return unless $has;
  for my $inep ($INEP, $INEP_2) {
    $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
               WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
               WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
               WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

END {
  limpa_tudo();
  if ($has_config) {
    $dbh->do('DELETE FROM app_config.items WHERE key LIKE $1', {}, 'canais.inscricao.%');
  }
}

subtest 'normalização de telefone' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  is $model->normalize_phone('(11) 99999-0001'), '11999990001', 'só dígitos';
  is $model->normalize_phone('  +55 11 99999-0001 '), '5511999990001', 'espaços e + removidos';
  is $model->normalize_phone(''), '', 'vazio';
  is $model->normalize_phone(undef), '', 'undef -> vazio';
  is $model->normalize_phone(12345), '12345', 'número é convertido';
  is $model->telefone_min_digits, 8, 'mínimo de dígitos do MVP';
};

subtest 'setup: escolas + gestores de teste' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  limpa_tudo();
  for my $inep ($INEP, $INEP_2) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, "Escola de teste listas $inep");
  }
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?)
     RETURNING id', {}, $INEP, 'Gestor Listas', $GESTOR);
  ($gestor2_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?)
     RETURNING id', {}, $INEP_2, 'Outra Escola', $GESTOR_2);
  ok $gestor_id > 0 && $gestor2_id > 0, 'gestores criados';
};

subtest 'criar_lista' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $model->criar_lista(
    cod_inep => $INEP, gestor_id => $gestor_id,
    nome => 'Alunos 6ºA', descricao => 'Responsáveis da turma',
  );
  ok $l->{id} > 0, 'lista criada';
  is $l->{nome}, 'Alunos 6ºA', 'nome';
  is $l->{canal}, 'telefone', 'canal default telefone';
  is $l->{ativo}, 1, 'ativa';
  is $l->{n_membros}, 0, 'sem membros ainda';
  $lista_id = $l->{id};

  my $dup = $model->criar_lista(
    cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Alunos 6ºA',
  );
  is $dup->{error}, 'Já existe uma lista com este nome nesta escola.',
    'nome duplicado na escola -> erro';

  my $vazio = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => '   ');
  is $vazio->{error}, 'nome é obrigatório (1..120 caracteres).', 'nome vazio -> erro';

  my $canal = $model->criar_lista(
    cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Via SMS', canal => 'sms',
  );
  is $canal->{error}, 'canal inválido (MVP: apenas telefone).', 'canal fora do MVP -> erro';

  # outro gestor, outra escola: mesmos nomes permitidos (UNIQUE por escola)
  my $l2 = $model->criar_lista(
    cod_inep => $INEP_2, gestor_id => $gestor2_id, nome => 'Alunos 6ºA',
  );
  ok $l2->{id} > 0, 'mesmo nome em outra escola é permitido';
};

subtest 'detalhe_lista / listar_listas / posse' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $d = $model->detalhe_lista($INEP, $lista_id);
  ok $d, 'detalhe encontrado';
  is $d->{nome}, 'Alunos 6ºA', 'nome no detalhe';
  is $d->{gestor_nome}, 'Gestor Listas', 'gestor_nome';
  is $d->{n_inscricoes}, 0, 'sem inscrições';

  ok !$model->detalhe_lista($INEP, 999999999), 'lista inexistente -> undef';
  my $outra = $model->criar_lista(
    cod_inep => $INEP_2, gestor_id => $gestor2_id, nome => 'Turma de tarde',
  );
  ok !$model->detalhe_lista($INEP, $outra->{id}), 'detalhe de outra escola -> undef (posse)';

  my $list = $model->listar_listas($INEP);
  ok ref($list) eq 'ARRAY', 'listar_listas retorna array';
  my ($achou) = grep { $_->{id} == $lista_id } @$list;
  ok $achou, 'lista aparece';
  is $achou->{nome}, 'Alunos 6ºA', 'nome na listagem';
  is $achou->{n_membros}, 0, 'contagem de membros';
  ok !defined $achou->{qrcode}, 'sem QR gerado ainda';

  my $list2 = $model->listar_listas($INEP_2);
  ok !grep({ $_->{id} == $lista_id } @$list2), 'listas de outra escola não vazam';
};

subtest 'gerar_qrcode + rotação + url' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $qr1 = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $lista_id, gestor_id => $gestor_id,
  );
  ok $qr1->{token} =~ /^[0-9a-fA-F-]{36}$/, 'token UUID de 36 chars';
  is $qr1->{status}, 'ativo', 'status ativo';
  is $qr1->{usos}, 0, 'usos zerados';
  like $qr1->{url}, qr{/inscricao/\Q$qr1->{token}\E$}, 'QR traz a url de inscrição';
  $token = $qr1->{token};

  my $url = $model->url_inscricao('http://edumaps.test/', $token);
  is $url, "http://edumaps.test/inscricao/$token", 'url montada (trailing slash limpo)';
  is $model->url_inscricao(undef, $token), "/inscricao/$token", 'sem base -> caminho relativo';

  # rotação: token anterior é revogado, novo nasce ativo
  my $qr2 = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $lista_id, gestor_id => $gestor_id,
  );
  ok $qr2->{token} ne $qr1->{token}, 'token rotacionado é novo';
  is $qr2->{status}, 'ativo', 'novo QR ativo';

  my $antigo = $dbh->selectrow_hashref(
    'SELECT status, revogado_em FROM clean.canal_qrcodes WHERE token = ?::uuid',
    {}, $qr1->{token});
  is $antigo->{status}, 'revogado', 'QR anterior revogado';
  ok defined $antigo->{revogado_em}, 'revogado_em marcado';

  my $erro_lista = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => 999999999, gestor_id => $gestor_id,
  );
  is $erro_lista->{error}, 'not_found', 'QR em lista inexistente -> not_found';
};

subtest 'revogar_qrcode' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $qr = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $lista_id, gestor_id => $gestor_id,
  );
  my $rev = $model->revogar_qrcode($INEP, $lista_id);
  is $rev->{token}, $qr->{token}, 'revoga o ativo';
  is $rev->{status}, 'revogado', 'status revogado';

  my $de_novo = $model->revogar_qrcode($INEP, $lista_id);
  is $de_novo->{error}, 'sem_qr_ativo', 'sem QR ativo para revogar';

  # novo QR gerado depois da revogação
  $qr = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $lista_id, gestor_id => $gestor_id,
  );
  $token = $qr->{token};
};

subtest 'validar_token: ok / not_found / revogado / expirado / esgotado' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $v = $model->validar_token($token);
  ok $v->{ok}, 'token ativo -> ok';
  is $v->{lista_nome}, 'Alunos 6ºA', 'lista_nome resolvido';
  is $v->{canal}, 'telefone', 'canal resolvido';
  ok $v->{escola_nome}, 'escola_nome preenchido';
  ok !exists $v->{inscricoes}, 'sem PII/histórico no envelope';

  is $model->validar_token('xyz')->{reason}, 'not_found', 'formato inválido -> not_found';
  is $model->validar_token(undef)->{reason}, 'not_found', 'undef -> not_found';

  # revogado (o token antigo da rotação)
  my $rev = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $lista_id, gestor_id => $gestor_id,
  );
  my $antigo_token = $token;
  $token = $rev->{token};
  is $model->validar_token($antigo_token)->{reason}, 'revogado', 'token revogado';

  # QR direto no banco: vencido e esgotado
  my $tok_exp = $dbh->selectrow_array('SELECT gen_random_uuid()::text');
  $dbh->do(
    'INSERT INTO clean.canal_qrcodes (lista_id, token, status, expira_em, criado_por)
     VALUES (?, ?::uuid, \'ativo\', NOW() - interval \'1 hour\', ?)',
    {}, $lista_id, $tok_exp, $gestor_id);
  is $model->validar_token($tok_exp)->{reason}, 'expirado', 'token vencido -> expirado';
  my $status_exp = $dbh->selectrow_array(
    'SELECT status FROM clean.canal_qrcodes WHERE token = ?::uuid', {}, $tok_exp);
  is $status_exp, 'expirado', 'status marcado como expirado no banco';

  my $tok_uso = $dbh->selectrow_array('SELECT gen_random_uuid()::text');
  $dbh->do(
    'INSERT INTO clean.canal_qrcodes (lista_id, token, status, max_usos, usos, criado_por)
     VALUES (?, ?::uuid, \'ativo\', 1, 1, ?)',
    {}, $lista_id, $tok_uso, $gestor_id);
  is $model->validar_token($tok_uso)->{reason}, 'esgotado', 'max_usos atingido -> esgotado';
};

subtest 'lista desativada -> lista_inativa (soft delete)' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $model->criar_lista(
    cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Turma a desativar',
  );
  my $qr = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id,
  );

  my $del = $model->excluir_lista($INEP, $l->{id});
  is $del->{ativo}, 0, 'desativação retorna ativo=0';
  is $model->detalhe_lista($INEP, $l->{id})->{ativo}, 0, 'detalhe mostra desativada';
  ok !$model->excluir_lista($INEP, 999999999), 'excluir lista inexistente -> undef';
  my $outra = $model->criar_lista(
    cod_inep => $INEP_2, gestor_id => $gestor2_id, nome => 'Posse alheia',
  );
  ok !$model->excluir_lista($INEP, $outra->{id}), 'excluir lista de outra escola -> undef';

  is $model->validar_token($qr->{token})->{reason}, 'lista_inativa',
    'token de lista desativada -> lista_inativa';

  # a linha NÃO foi apagada (princípio "sem descarte")
  my $sobrevive = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_listas WHERE id = ?', {}, $l->{id});
  is $sobrevive, 1, 'lista permanece no banco (soft delete)';

  # some da listagem de gestão (só ativas) ...
  ok !grep({ $_->{id} == $l->{id} } @{ $model->listar_listas($INEP) }),
    'lista desativada some da listagem';

  # ... mas recriar o mesmo nome reativa a MESMA linha (histórico preservado)
  my $re = $model->criar_lista(
    cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Turma a desativar');
  is $re->{id}, $l->{id}, 'recriar reativa a mesma linha';
  is $re->{ativo}, 1, 'reativada';
  ok grep({ $_->{id} == $l->{id} } @{ $model->listar_listas($INEP) }),
    'volta à listagem após reativar';
  is $model->validar_token($qr->{token})->{ok}, 1,
    'token volta a valer quando a lista é reativada';
};

subtest 'registrar_inscricao: validações e consentimento' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  is $model->registrar_inscricao(token => $token, nome => '', telefone => '11999990000')
    ->{reason}, 'campos', 'nome obrigatório';
  is $model->registrar_inscricao(token => $token, nome => 'Ana', telefone => '')
    ->{reason}, 'campos', 'telefone obrigatório';
  is $model->registrar_inscricao(token => $token, nome => 'Ana', telefone => '123')
    ->{reason}, 'campos', 'telefone com menos de 8 dígitos';
  is $model->registrar_inscricao(token => $token, nome => 'Ana', telefone => '11999990000')
    ->{reason}, 'consentimento', 'sem consentimento -> barrado';
};

subtest 'registrar_inscricao: primeira submissão cria contato' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $r = $model->registrar_inscricao(
    token         => $token,
    nome          => 'Maria Professora',
    telefone      => '(11) 98888-5555',
    consentimento => 1,
    ip_anon       => 'hmac:abc123',
    user_agent    => 'Mozilla/5.0 (teste)',
  );
  ok $r->{ok}, 'inscrição aceita';
  ok $r->{inscricao_id} > 0, 'id da inscrição';
  ok $r->{contato_id} > 0, 'contato criado';
  is $r->{duplicado}, 0, 'não é duplicada';
  is $r->{conflito}, 0, 'sem conflito';
  $contato_primeiro = $r->{contato_id};

  my $contato = $dbh->selectrow_hashref(
    'SELECT nome, telefone, cod_inep FROM clean.contatos WHERE id = ?',
    {}, $r->{contato_id});
  is $contato->{telefone}, '(11) 98888-5555', 'telefone bruto preservado';
  is $contato->{cod_inep}+0, $INEP, 'contato pertence à escola da lista';

  my $membros = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_lista_membros WHERE lista_id = ?', {}, $lista_id);
  is $membros, 1, 'um membro na lista';

  my $qr = $dbh->selectrow_array(
    'SELECT usos FROM clean.canal_qrcodes WHERE token = ?::uuid', {}, $token);
  is $qr, 1, 'usos incrementado';

  my $insc = $dbh->selectrow_hashref(
    'SELECT telefone_norm, validado, consentimento_versao, ip_anon
     FROM clean.canal_inscricoes WHERE id = ?', {}, $r->{inscricao_id});
  is $insc->{telefone_norm}, '11988885555', 'telefone normalizado na inscrição';
  is $insc->{validado}+0, 0, 'validado=false (MVP)';
  is $insc->{consentimento_versao}, '1.0',
    'versão de consentimento registrada';
  is $insc->{ip_anon}, 'hmac:abc123', 'ip anonimizado registrado (nunca o IP puro)';
};

subtest 'registrar_inscricao: dedupe NÃO destrutivo (reuso + marcação)' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $antes = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);

  # mesmo telefone normalizado, nome diferente -> duplicado + conflito
  my $r2 = $model->registrar_inscricao(
    token         => $token,
    nome          => 'Maria Silva',          # muda o nome
    telefone      => '(11) 98888-5555',
    consentimento => 1,
  );
  ok $r2->{ok}, 'segunda submissão aceita (virou histórico)';
  is $r2->{duplicado}, 1, 'duplicado=1';
  is $r2->{conflito}, 1, 'conflito=1 (nome diverge do armazenado)';
  is $r2->{contato_id}, $contato_primeiro, 'contato é REUSADO (mesmo id da 1ª submissão)';

  # mesmo telefone e mesmo nome -> duplicado, sem conflito
  my $r3 = $model->registrar_inscricao(
    token         => $token,
    nome          => 'Maria Professora',
    telefone      => '(11) 98888-5555',
    consentimento => 1,
  );
  is $r3->{duplicado}, 1, 'terceira submissão duplicado=1';
  is $r3->{conflito}, 0, 'sem conflito quando nome bate';

  my $depois = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  is $depois, $antes, 'NENHUM contato novo criado (reuso, não duplica)';

  my $membros = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_lista_membros WHERE lista_id = ?', {}, $lista_id);
  is $membros, 1, 'pertencimento idempotente (ON CONFLICT DO NOTHING)';

  my $inscricoes = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_inscricoes WHERE lista_id = ?', {}, $lista_id);
  is $inscricoes, 3, 'três submissões no histórico (append-only, sem descarte)';

  my ($dup_row) = $dbh->selectrow_array(
    'SELECT duplicado_de IS NOT NULL FROM clean.canal_inscricoes
     WHERE lista_id = ? ORDER BY id DESC LIMIT 1', {}, $lista_id);
  ok $dup_row, 'duplicado_de marcado na inscrição';

  my $registro_antigo = $dbh->selectrow_array(
    'SELECT nome FROM clean.contatos WHERE cod_inep = ? AND telefone IS NOT NULL
     AND regexp_replace(telefone, \'\D\', \'\', \'g\') = \'11988885555\'', {}, $INEP);
  is $registro_antigo, 'Maria Professora', 'dado original NÃO sobrescrito (sem descarte)';
};

subtest 'listar_inscricoes (visão do gestor)' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $rows = $model->listar_inscricoes($INEP, $lista_id);
  is ref($rows), 'ARRAY', 'array';
  is scalar(@$rows), 1, 'um membro (idempotência: 3 submissões, 1 membro)';
  is $rows->[0]{nome}, 'Maria Professora', 'nome do membro';
  is $rows->[0]{telefone}, '(11) 98888-5555', 'telefone visível ao gestor (PII restrita)';
  is $rows->[0]{origem}, 'qrcode', 'origem qrcode';
  ok !defined $rows->[0]{duplicado_de} || $rows->[0]{duplicado_de} > 0, 'duplicado_de opcional';

  ok !$model->listar_inscricoes($INEP, 999999999), 'lista inexistente -> undef';
  my $outra = $model->criar_lista(
    cod_inep => $INEP_2, gestor_id => $gestor2_id, nome => 'Agenda de posse',
  );
  my $empty = $model->listar_inscricoes($INEP_2, $outra->{id});
  is ref($empty), 'ARRAY', 'lista de outra escola com 0 membros';
};

subtest 'fluxo completo: nova lista + submissão pública' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $model->criar_lista(
    cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Responsáveis 9ºB',
    descricao => 'Comunicação de urgência',
  );
  my $qr = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id,
    max_usos => 5,
  );
  is $qr->{max_usos}, 5, 'max_usos gravado';

  my $pub = $model->dados_publicos_token($qr->{token});
  is $pub->{ok}, 1, 'dados públicos ok';
  is $pub->{lista_nome}, 'Responsáveis 9ºB', 'nome da lista';
  ok $pub->{escola_nome}, 'nome da escola';
  is join(',', @{ $pub->{campos} }), 'nome,telefone', 'campos do formulário';
  ok !exists $pub->{cod_inep}, 'dados públicos não vazam cod_inep';
  ok !exists $pub->{gestor_id}, 'dados públicos não vazam gestor';
  ok !exists $pub->{inscricoes}, 'dados públicos não vazam inscrições';

  my $r = $model->registrar_inscricao(
    token => $qr->{token}, nome => 'Pai do 9ºB', telefone => '11977776666',
    consentimento => 1,
  );
  ok $r->{ok}, 'inscrição via QR nova aceita';

  my $d = $model->detalhe_lista($INEP, $l->{id});
  is $d->{n_membros}, 1, 'contagem de membros no detalhe';
  is $d->{n_inscricoes}, 1, 'contagem de inscrições no detalhe';
  is $d->{n_qrcodes_ativos}, 1, 'contagem de QRs ativos';

  # esgotado via max_usos: simula o limite no banco (já testado acima)
  ok $model->dados_publicos_token('token-inexistente')->{reason} eq 'not_found',
    'token inexistente nos dados públicos';
};

subtest 'rate_limit_check (antiabuso)' => sub {
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  $model->config_put('canais.inscricao.rate_max', '1', 'test@edumaps.test');

  is $model->rate_limit_check(token => $token, ip => '10.0.0.1')->{ok}, 1,
    'primeira chamada passa';
  is $model->rate_limit_check(token => $token, ip => '10.0.0.1')->{reason}, 'rate_limited',
    'segunda chamada na mesma janela bloqueada';
  is $model->rate_limit_check(token => $token, ip => '10.0.0.2')->{ok}, 1,
    'outro IP não é bloqueado';
  is $model->rate_limit_check(token => $token, ip => '10.0.0.2')->{reason}, 'rate_limited',
    'mesmo IP+token bloqueado de novo';
  is $model->rate_limit_check(token => undef, ip => 'x')->{ok}, 1,
    'sem token/IP identificáveis não bloqueia (degrada graciosamente)';
};

subtest 'config canais.inscricao.* (AppConfig)' => sub {
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $tree = $model->config_tree;
  my ($canais) = grep { $_->{key} eq 'canais' } @{ $tree->{categories} };
  ok $canais, 'categoria canais';
  my ($grp) = grep { $_->{key} eq 'canais_inscricao' } @{ $canais->{children} };
  ok $grp, 'grupo canais_inscricao na árvore';
  my @keys = map { $_->{key} } @{ $grp->{children} };
  is join(',', @keys),
    'canais.inscricao.enabled,canais.inscricao.public_base_url,canais.inscricao.rate_max,canais.inscricao.rate_window_seconds',
    'folhas da autoinscrição';
  my ($enabled) = grep { $_->{key} eq 'canais.inscricao.enabled' } @{ $grp->{children} };
  is $enabled->{type}, 'boolean', 'enabled é boolean';

  # defaults sem nada gravado (limpa o rate_max deixado pelo teste de rate limit)
  $dbh->do('DELETE FROM app_config.items WHERE key = ?', {}, 'canais.inscricao.rate_max');
  my $cfg = $model->inscricao_config;
  is $cfg->{enabled}, 0, 'desligado por omissão (endpoint público 404)';
  is $cfg->{rate_max}, 10, 'rate_max default 10';
  is $cfg->{rate_window_seconds}, 60, 'janela default 60s';
  ok !defined $cfg->{public_base_url}, 'base url vazia por omissão';

  # gravando: lê de volta
  $model->config_put('canais.inscricao.public_base_url', 'https://edumaps.exemplo.org', 'test@edumaps.test');
  $model->config_put('canais.inscricao.enabled', 'true', 'test@edumaps.test');
  my $cfg2 = $model->inscricao_config;
  is $cfg2->{enabled}, 1, 'ligado após gravação';
  is $cfg2->{public_base_url}, 'https://edumaps.exemplo.org', 'base url lida';
};

done_testing;