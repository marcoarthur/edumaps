# t/02-models/canal_confirmacao.t
# Regra de negócio da confirmação de posse do telefone nas listas com QR
# (issue #212 — Fase 1), role EduMaps::Roles::Business::Canal::Confirmacao.
#
# Cobre: abrir ref (hash gravado ≠ ref em claro, TTL 24h, invalidação ao
# reabrir), estado da ref (pendente/confirmado/404), concluir (por ref e por
# membro, idempotente, validado=true), conflito (não altera o membro), a
# inscrição em lista que exige confirmação e a disponibilidade dos canais
# conforme a config (canais.telegram.* / canais.whatsapp.*).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacao_refs')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model = $t->app->model('Canal');

my $INEP   = 99660000 + ($$ % 1000);
my $GESTOR = sprintf 'gestor.confirmacao.%d@edumaps.test', $$;
my $ADMIN  = 'admin@edumaps.test';

my ($gestor_id, $lista_id, $token);

sub limpa_tudo {
  return unless $has;
  $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
             WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
             WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
             WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
}

sub limpa_config {
  return unless $has_config;
  $dbh->do(q{DELETE FROM app_config.items
             WHERE key LIKE 'canais.telegram.%' OR key LIKE 'canais.whatsapp.%'});
}

END {
  limpa_tudo();
  limpa_config();
}

# Inscreve um telefone na lista de teste e devolve o resultado do modelo.
sub inscreve ($nome, $telefone) {
  return $model->registrar_inscricao(
    token => $token, nome => $nome, telefone => $telefone, consentimento => 1,
  );
}

subtest 'setup: escola, gestor, lista que exige confirmação' => sub {
  plan skip_all => 'clean.canal_confirmacao_refs ausente (migration nao aplicada)' unless $has;

  limpa_tudo();
  limpa_config();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola Confirmação');
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Confirmação', $GESTOR);

  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id,
                              nome => 'Exige', exige_confirmacao => 1);
  ok $l->{id}, 'lista criada';
  ok $l->{exige_confirmacao}, 'exige_confirmacao=true';
  is $l->{membros_pendentes}, 0, 'sem pendentes';
  $lista_id = $l->{id};
  $token = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $lista_id,
                                gestor_id => $gestor_id)->{token};
  ok $token, 'QR gerado';
};

subtest 'formato da ref e estado de ref inexistente' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  ok $model->ref_valida('0' x 32), '32 hex é válido';
  ok !$model->ref_valida('0' x 31), '31 hex é inválido';
  ok !$model->ref_valida('g' x 32), 'não-hex é inválido';
  ok !$model->ref_valida(undef), 'undef é inválido';
  ok !$model->ref_valida(('a' x 32) . "\n"), 'quebra de linha final é inválida';
  is $model->estado_ref('f' x 32), undef, 'ref inexistente -> undef';
  is $model->estado_ref('xyz'), undef, 'formato inválido -> undef';
  is $model->confirmacao_ttl_horas, 24, 'TTL default 24h';
};

my ($r1, $membro_id);

subtest 'inscrição em lista que exige: membro pendente + ref' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  $r1 = inscreve('Maria Confirma', '(11) 95555-1111');
  ok $r1->{ok}, 'inscrição registrada';
  $membro_id = $r1->{membro_id};
  ok $membro_id, 'membro_id devolvido';

  my $c = $r1->{confirmacao};
  ok $c, 'confirmacao presente';
  is $c->{estado}, 'pendente', 'estado pendente';
  like $c->{ref}, qr/^[0-9a-f]{32}$/, 'ref de 32 hex';
  like $c->{expira_em}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'expira_em ISO 8601';
  is $c->{canais}, [], 'sem canais configurados -> []';

  my $row = $dbh->selectrow_hashref(
    q{SELECT ref_hash, (expira_em - created_at) AS ttl,
             extract(epoch FROM (expira_em - created_at))::int AS ttl_s,
             usada_em, invalidada_em, inscricao_id, membro_id
      FROM clean.canal_confirmacao_refs WHERE membro_id = ?}, {}, $membro_id);
  ok $row, 'ref gravada';
  isnt $row->{ref_hash}, $c->{ref}, 'ref em claro NÃO é gravada';
  is $row->{ref_hash}, sha256_hex($c->{ref}), 'grava o sha256 da ref';
  is $row->{ttl_s}, 24 * 3600, 'validade de 24h';
  is $row->{inscricao_id}, $r1->{inscricao_id}, 'ligada à inscrição';
  ok !defined $row->{usada_em} && !defined $row->{invalidada_em}, 'pendente';

  my $e = $model->estado_ref($c->{ref});
  is $e->{estado}, 'pendente', 'estado_ref pendente';
  is $e->{membro_id}, $membro_id, 'estado_ref aponta para o membro';
  is $e->{telefone_norm}, '11955551111', 'telefone_norm para comparação';
  is $e->{expira_em}, $c->{expira_em}, 'mesmo expira_em';
  ok $model->estado_ref(uc $c->{ref}), 'ref em maiúsculas também resolve';

  my $m = $model->listar_inscricoes($INEP, $lista_id);
  is $m->[0]{estado}, 'pendente', 'membro pendente na visão do gestor';
  my $d = $model->detalhe_lista($INEP, $lista_id);
  is $d->{membros_pendentes}, 1, 'um pendente';
  is $d->{membros_confirmados}, 0, 'nenhum confirmado';
};

subtest 'reinscrição de pendente: nova ref e a anterior é invalidada' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  my $r2 = inscreve('Maria Confirma', '11955551111');
  ok $r2->{ok} && $r2->{duplicado}, 'reinscrição (duplicada)';
  is $r2->{membro_id}, $membro_id, 'mesmo membro';
  my $c2 = $r2->{confirmacao};
  is $c2->{estado}, 'pendente', 'continua pendente';
  isnt $c2->{ref}, $r1->{confirmacao}{ref}, 'ref nova';

  is $model->estado_ref($r1->{confirmacao}{ref}), undef, 'ref anterior -> não encontrada';
  my $inv = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_confirmacao_refs WHERE membro_id = ? AND invalidada_em IS NOT NULL',
    {}, $membro_id);
  is $inv, 1, 'anterior marcada invalidada_em (sem apagar)';
  my $tot = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_confirmacao_refs WHERE membro_id = ?', {}, $membro_id);
  is $tot, 2, 'histórico preservado';

  # abrir_ref direto também invalida a pendente
  my $r3 = $model->abrir_ref($membro_id, $r2->{inscricao_id});
  is $model->estado_ref($c2->{ref}), undef, 'abrir_ref invalida a anterior';
  is $model->estado_ref($r3->{ref})->{estado}, 'pendente', 'nova pendente';
  $r1 = { confirmacao => { ref => $r3->{ref} }, inscricao_id => $r2->{inscricao_id} };
};

subtest 'conflito: marca a inscrição, não altera o membro' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  my $ref = $r1->{confirmacao}{ref};
  my $c = $model->registrar_conflito($ref);
  ok $c->{ok}, 'conflito registrado';
  is $c->{inscricao_id}, $r1->{inscricao_id}, 'na inscrição da ref';
  my $conf = $dbh->selectrow_array(
    'SELECT conflito FROM clean.canal_inscricoes WHERE id = ?', {}, $r1->{inscricao_id});
  ok $conf, 'conflito=true';
  my $m = $dbh->selectrow_hashref(
    'SELECT confirmado_em, validado FROM clean.canal_lista_membros WHERE id = ?', {}, $membro_id);
  ok !defined $m->{confirmado_em} && !$m->{validado}, 'membro intacto';
  is $model->estado_ref($ref)->{estado}, 'pendente', 'ref continua pendente (pode tentar de novo)';

  ok !$model->registrar_conflito('f' x 32)->{ok}, 'ref inexistente -> not_found';
};

subtest 'concluir por ref: confirma, idempotente' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  my $ref = $r1->{confirmacao}{ref};
  is $model->concluir(ref => $ref, via => 'sms')->{reason}, 'via', 'via inválida';
  is $model->concluir(ref => 'f' x 32, via => 'telegram')->{reason}, 'not_found', 'ref inexistente';

  my $c = $model->concluir(ref => $ref, via => 'telegram', telegram_chat_id => 424242);
  ok $c->{ok}, 'concluído';
  is $c->{estado}, 'confirmado', 'estado confirmado';
  ok !$c->{ja_confirmado}, 'primeira confirmação';

  my $m = $dbh->selectrow_hashref(
    q{SELECT confirmado_em, confirmado_via, telegram_chat_id, validado
      FROM clean.canal_lista_membros WHERE id = ?}, {}, $membro_id);
  ok defined $m->{confirmado_em}, 'confirmado_em';
  is $m->{confirmado_via}, 'telegram', 'confirmado_via';
  is $m->{telegram_chat_id}, 424242, 'telegram_chat_id';
  ok $m->{validado}, 'membro validado=true';
  my $iv = $dbh->selectrow_array(
    'SELECT validado FROM clean.canal_inscricoes WHERE id = ?', {}, $r1->{inscricao_id});
  ok $iv, 'inscrição validado=true';
  my $usada = $dbh->selectrow_array(
    'SELECT usada_em FROM clean.canal_confirmacao_refs WHERE ref_hash = ?', {}, sha256_hex($ref));
  ok defined $usada, 'ref usada_em';

  is $model->estado_ref($ref)->{estado}, 'confirmado', 'estado_ref de ref usada = confirmado';

  # idempotente: concluir de novo (até por outro canal) não muda nada
  my $c2 = $model->concluir(ref => $ref, via => 'whatsapp');
  ok $c2->{ok} && $c2->{ja_confirmado}, 'segunda chamada idempotente';
  my $m2 = $dbh->selectrow_hashref(
    q{SELECT confirmado_em, confirmado_via, telegram_chat_id
      FROM clean.canal_lista_membros WHERE id = ?}, {}, $membro_id);
  is $m2->{confirmado_em}, $m->{confirmado_em}, 'confirmado_em preservado';
  is $m2->{confirmado_via}, 'telegram', 'confirmado_via preservado';

  ok !$model->registrar_conflito($ref)->{ok}, 'conflito em ref usada -> not_found';

  # reinscrição de membro confirmado: sem ref nova
  my $r = inscreve('Maria Confirma', '11955551111');
  # #214: + contatos (acrescentado ao contrato)
  is $r->{confirmacao},
    { estado => 'confirmado',
      contatos => { telefone => { estado => 'confirmado', via => 'telegram' } } },
    'confirmado -> {estado:"confirmado", contatos}';

  my $l = $model->listar_inscricoes($INEP, $lista_id);
  is $l->[0]{estado}, 'confirmado', 'estado confirmado na gestão';
  is $l->[0]{confirmado_via}, 'telegram', 'via na gestão';
  my $d = $model->detalhe_lista($INEP, $lista_id);
  is $d->{membros_confirmados}, 1, 'contador confirmados';
  is $d->{membros_pendentes}, 0, 'contador pendentes';
};

subtest 'concluir por membro e ref expirada' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  my $r = inscreve('João Whats', '11955552222');
  my $ref = $r->{confirmacao}{ref};

  # expira a ref: vira não encontrada
  $dbh->do(q{UPDATE clean.canal_confirmacao_refs
             SET expira_em = NOW() - interval '1 minute' WHERE ref_hash = ?},
    {}, sha256_hex($ref));
  is $model->estado_ref($ref), undef, 'expirada sem uso -> undef';
  is $model->concluir(ref => $ref, via => 'whatsapp')->{reason}, 'not_found',
    'concluir por ref expirada -> not_found';

  my $c = $model->concluir(membro_id => $r->{membro_id}, via => 'whatsapp');
  ok $c->{ok}, 'concluir por membro';
  my $m = $dbh->selectrow_hashref(
    'SELECT confirmado_via, validado, telegram_chat_id FROM clean.canal_lista_membros WHERE id = ?',
    {}, $r->{membro_id});
  is $m->{confirmado_via}, 'whatsapp', 'via whatsapp';
  ok $m->{validado}, 'validado';
  ok !defined $m->{telegram_chat_id}, 'sem chat_id';
  ok $dbh->selectrow_array('SELECT validado FROM clean.canal_inscricoes WHERE id = ?',
    {}, $r->{inscricao_id}), 'última inscrição validada';
  is $model->concluir(membro_id => 999999999, via => 'whatsapp')->{reason}, 'not_found',
    'membro inexistente';
};

subtest 'lista sem exigência: sem confirmacao, estado nao_exigida' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Livre');
  ok !$l->{exige_confirmacao}, 'default false';
  my $tk = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id},
                                gestor_id => $gestor_id)->{token};
  my $r = $model->registrar_inscricao(token => $tk, nome => 'Livre', telefone => '11955553333',
                                      consentimento => 1);
  ok $r->{ok}, 'inscrito';
  ok !exists $r->{confirmacao}, 'sem confirmacao';
  my $refs = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_confirmacao_refs WHERE membro_id = ?', {}, $r->{membro_id});
  is $refs, 0, 'nenhuma ref aberta';
  is $model->listar_inscricoes($INEP, $l->{id})->[0]{estado}, 'nao_exigida', 'nao_exigida';
  is $model->detalhe_lista($INEP, $l->{id})->{membros_pendentes}, 0, 'pendentes = 0';

  # ligar a exigência depois não altera o membro existente; vira pendente na leitura
  my $u = $model->atualizar_lista($INEP, $l->{id}, exige_confirmacao => 'true');
  ok $u->{exige_confirmacao}, 'exigência ligada';
  is $u->{membros_pendentes}, 1, 'membro existente conta como pendente';
  my $m = $dbh->selectrow_hashref(
    'SELECT confirmado_em, validado FROM clean.canal_lista_membros WHERE id = ?', {}, $r->{membro_id});
  ok !defined $m->{confirmado_em} && !$m->{validado}, 'membro não foi alterado';
};

subtest 'atualizar_lista: validações' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;

  is $model->atualizar_lista($INEP, 999999999, nome => 'X'), undef, 'lista alheia -> undef';
  is $model->atualizar_lista($INEP, $lista_id)->{status}, 400, 'nada a alterar -> 400';
  is $model->atualizar_lista($INEP, $lista_id, exige_confirmacao => 'talvez')->{status}, 400,
    'booleano inválido -> 400';
  is $model->atualizar_lista($INEP, $lista_id, nome => '  ')->{status}, 400, 'nome vazio -> 400';
  is $model->atualizar_lista($INEP, $lista_id, nome => 'Livre')->{status}, 409, 'nome duplicado -> 409';
  my $u = $model->atualizar_lista($INEP, $lista_id, nome => 'Exige 2', descricao => 'nova',
                                  exige_confirmacao => 0);
  is $u->{nome}, 'Exige 2', 'nome alterado';
  is $u->{descricao}, 'nova', 'descricao alterada';
  ok !$u->{exige_confirmacao}, 'exigência desligada';
  is $u->{membros_pendentes}, 0, 'sem exigência -> pendentes 0';
  my $u2 = $model->atualizar_lista($INEP, $lista_id, descricao => '');
  ok !defined $u2->{descricao}, 'descricao vazia -> NULL';

  is $model->parse_bool('TRUE'), 1, 'parse_bool TRUE';
  is $model->parse_bool('0'), 0, 'parse_bool 0';
  is $model->parse_bool(JSON::PP::true()), 1, 'parse_bool JSON true';
  is $model->parse_bool('sim'), undef, 'parse_bool inválido';
};

subtest 'canais disponíveis conforme a config' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  plan skip_all => 'app_config.items ausente' unless $has_config;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';

  limpa_config();
  is $model->canais_confirmacao_disponiveis, [], 'nada configurado -> []';

  # telegram: precisa de enabled + token + bot_username
  $model->config_put('canais.telegram.enabled', 'true', $ADMIN);
  $model->config_put('canais.telegram.bot_username', '@EduMapsTesteBot', $ADMIN);
  is $model->canais_confirmacao_disponiveis, [], 'sem token -> telegram indisponível';
  $model->config_put('canais.telegram.token', '123456:ABCDEFGHIJ', $ADMIN);
  is $model->canais_confirmacao_disponiveis,
    [{ canal => 'telegram', bot_username => 'EduMapsTesteBot' }], 'telegram disponível (sem @)';

  my $tg = $model->telegram_publico_config;
  is $tg->{recebimento}, 'polling', 'recebimento default polling';
  is $tg->{token}, '123456:ABCDEFGHIJ', 'token decifrado';

  # whatsapp: enabled + cloud + token + phone_number_id + template
  $model->config_put('canais.whatsapp.enabled', 'true', $ADMIN);
  $model->config_put('canais.whatsapp.provider', 'cloud', $ADMIN);
  $model->config_put('canais.whatsapp.token', 'EAAG-token-teste', $ADMIN);
  $model->config_put('canais.whatsapp.phone_number_id', '123456789012345', $ADMIN);
  is scalar(@{ $model->canais_confirmacao_disponiveis }), 1, 'sem template -> whatsapp indisponível';
  is $model->whatsapp_config->{template_idioma}, 'pt_BR', 'idioma default pt_BR';
  $model->config_put('canais.whatsapp.template_confirmacao', 'edumaps_codigo', $ADMIN);
  is [map { $_->{canal} } @{ $model->canais_confirmacao_disponiveis }],
    [qw(telegram whatsapp)], 'ordem: telegram, whatsapp';

  my $canais = $model->canais_confirmacao('a' x 32);
  is $canais, [
    { canal => 'telegram', url => 'https://t.me/EduMapsTesteBot?start=' . ('a' x 32) },
    { canal => 'whatsapp' },
  ], 'canais no formato do contrato';

  $model->config_put('canais.telegram.enabled', 'false', $ADMIN);
  is [map { $_->{canal} } @{ $model->canais_confirmacao_disponiveis }],
    ['whatsapp'], 'telegram desligado some';
  $model->config_put('canais.whatsapp.provider', 'link', $ADMIN);
  is $model->canais_confirmacao_disponiveis, [], 'provider link -> whatsapp indisponível';

  limpa_config();
};

done_testing;
