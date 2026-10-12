# t/02-models/canal_envio.t
# Envio por e-mail para listas (issue #216 — Fase 3, onda 1), role
# Canal::Envios + config canais.envio.*:
#
#   - config efetiva (defaults, faixa do ritmo) e folhas do AppConfig;
#   - rascunho: validação, alvo da escola, edição/apagar só em rascunho;
#   - disparo: alvo lista e segmento, dedupe, opt-out, anonimizado, teto,
#     cota (inclusive saldo do dia), suspensão, desligado, SMTP, fotografia;
#   - lote (envio_processar_lote, chamado pelo job): rodapé + cabeçalhos
#     List-Unsubscribe, token de saída (só o hash no banco), idempotência
#     (rodar duas vezes não reenvia), ritmo, pausa por cota e retomada,
#     suspensão, falha do SMTP, cancelamento, limpeza do e-mail ao concluir;
#   - prévia, teste (limite 5), destinatários mascarados, limites.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex hmac_sha256_hex);
use Encode ();
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_envios')")
       && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migration canal_envios nao aplicada' unless $has;

my $model  = $t->app->model('Canal');
my $SECRET = $t->app->secrets->[0];
my $INEP   = 99670000 + ($$ % 1000);
my $OUTRA  = $INEP + 1000;
my $P      = sprintf '%04d', $$ % 10000;
my (%g, %l, %c, @enviados, @jobs);
my $smtp_ok = 1;
my $smtp = sub ($cfg, $to, $from, $env) {
  return { ok => 0, error => 'SMTP: falha em data' } unless $smtp_ok;
  push @enviados, { to => $to, envelope => $env };
  return { ok => 1 };
};
my $enqueue = sub ($id, $delay) { push @jobs, [ $id, $delay ]; return 4242 };

sub mail ($n) { return "env$n.$P\@exemplo.org" }

sub limpa {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE cod_inep = ?
               AND referente_tipo IN ('envio', 'envio_teste')}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.canal_envio_suspensoes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.canal_segmentos WHERE cod_inep = ?', {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
               WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.envio.%'
             OR key LIKE 'canais.email.%' OR key = 'canais.inscricao.public_base_url'});
}
END { limpa() if $has }

sub cfg ($k, $v) { $model->config_put("canais.$k", $v, 'teste') }
sub contato ($nome, $email, $inep = $INEP) {
  my ($id) = $dbh->selectrow_array(
    'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email) VALUES (?, ?, ?, ?) RETURNING id',
    {}, $inep, $g{$inep}, $nome, $email);
  return $id;
}
sub membro ($lista, $contato) {
  $dbh->do(q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem)
             VALUES (?, ?, 'manual')}, {}, $lista, $contato);
}
sub h256 ($e) { return sha256_hex($e) }
sub rascunho (%o) {
  return $model->envio_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, alvo_tipo => 'lista',
    alvo_id => $l{A}, operacao => 'aviso', assunto => 'Reunião de pais',
    corpo => "Reunião na sexta.\n", %o);
}
sub dispara ($id, %o) {
  return $model->envio_disparar(cod_inep => $INEP, id => $id, secret => $SECRET,
                                enqueue => $enqueue, %o);
}
sub lote ($id) {
  return $model->envio_processar_lote($id, secret => $SECRET, smtp_transport => $smtp);
}
sub dest ($id) {
  return $dbh->selectall_arrayref(
    'SELECT * FROM clean.canal_envio_destinatarios WHERE envio_id = ? ORDER BY id',
    { Slice => {} }, $id);
}
sub envio ($id) { return $model->envio_detalhe($INEP, $id) }

limpa();
for my $inep ($INEP, $OUTRA) {
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, "Escola $inep");
  ($g{$inep}) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $inep, 'Gestor Envio', "gestor.envio.$inep.$P\@edumaps.test");
}
for my $def ([A => $INEP], [B => $INEP], [Z => $OUTRA]) {
  $l{ $def->[0] } = $model->criar_lista(cod_inep => $def->[1], gestor_id => $g{ $def->[1] },
    nome => "Lista $def->[0]", coleta => 'email')->{id};
}
$c{$_->[0]} = contato($_->[0], $_->[1]) for [Ana => mail(1)], [Bia => mail(2)], [Caio => mail(3)],
                                            [Davi => undef];
membro($l{A}, $c{$_}) for qw(Ana Bia Davi);
membro($l{B}, $c{$_}) for qw(Ana Caio);
membro($l{Z}, contato('Zeca', mail(9), $OUTRA));

subtest 'config canais.envio.*' => sub {
  is $model->envio_config, { enabled => 1, ritmo_por_minuto => 60, cota_diaria_escola => 500,
                             max_destinatarios => 2000 }, 'defaults';
  ok $model->is_config_key("canais.envio.$_"), "folha $_"
    for qw(enabled ritmo_por_minuto cota_diaria_escola max_destinatarios);
  cfg('envio.ritmo_por_minuto', '5000');
  cfg('envio.cota_diaria_escola', '0');
  cfg('envio.enabled', 'false');
  my $c = $model->envio_config;
  is [ @$c{qw(enabled ritmo_por_minuto cota_diaria_escola)} ], [0, 600, 500],
    'desligado; ritmo cortado em 600; cota 0 → default';
  my ($grupo) = grep { $_->{key} eq 'canais_envio' }
                map { @{ $_->{children} } } grep { $_->{key} eq 'canais' }
                @{ $model->config_tree->{categories} };
  is $grupo->{label}, 'Envios', 'grupo Envios na categoria Canais';
  is scalar @{ $grupo->{children} }, 4, 'quatro folhas';
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.envio.%'});
};

subtest 'rascunho: validação, isolamento, edição' => sub {
  my %base = (cod_inep => $INEP, gestor_id => $g{$INEP}, alvo_tipo => 'lista', alvo_id => $l{A},
              operacao => 'aviso', assunto => 'A', corpo => 'B');
  is $model->envio_criar(%base, alvo_tipo => 'grupo')->{status}, 400, 'alvo_tipo';
  is $model->envio_criar(%base, operacao => 'confirmacao')->{status}, 400, 'operacao confirmacao';
  is $model->envio_criar(%base, assunto => ' ')->{status}, 400, 'assunto vazio';
  is $model->envio_criar(%base, assunto => 'x' x 201)->{status}, 400, 'assunto > 200';
  is $model->envio_criar(%base, corpo => 'x' x 20001)->{status}, 400, 'corpo > 20000';
  is $model->envio_criar(%base, alvo_id => $l{Z})->{status}, 404, 'lista de outra escola → 404';
  is $model->envio_criar(%base, alvo_tipo => 'segmento', alvo_id => 999999999)->{status}, 404,
    'segmento inexistente → 404';

  my $e = rascunho();
  is $e->{status}, 'rascunho', 'rascunho';
  is $e->{alvo}, { tipo => 'lista', id => $l{A}, nome => 'Lista A' }, 'alvo com nome atual';
  is $e->{autor}{id}, $g{$INEP}, 'autor';
  is $e->{contadores}{destinatarios}, 0, 'contadores zerados';
  like $e->{created_at}, qr/Z$/, 'datas ISO UTC';

  my $u = $model->envio_atualizar($INEP, $e->{id}, assunto => 'Novo', alvo_id => $l{B});
  is [ $u->{assunto}, $u->{alvo}{nome} ], ['Novo', 'Lista B'], 'PATCH';
  is $model->envio_atualizar($INEP, $e->{id}, operacao => 'x')->{status}, 400, 'PATCH inválido';
  ok !$model->envio_atualizar($OUTRA, $e->{id}, assunto => 'x'), 'PATCH de outra escola: undef';
  ok !$model->envio_detalhe($OUTRA, $e->{id}), 'detalhe isolado';

  my $lst = $model->envio_listar($INEP, per_page => 500);
  is $lst->{per_page}, 100, 'per_page máximo 100';
  ok !exists $lst->{items}[0]{corpo}, 'listagem sem corpo';
  ok $model->envio_listar($INEP, status => 'x')->{error}, 'status inválido';
  is $model->envio_apagar($INEP, $e->{id}), { ok => 1 }, 'apaga rascunho';
};

subtest 'disparo bloqueado: smtp, desligado, suspensa, alvo, vazio' => sub {
  my $e = rascunho();
  is dispara($e->{id})->{motivo}, 'smtp_indisponivel', 'sem SMTP';
  cfg('email.enabled', 'true');
  cfg('email.smtp_host', 'smtp.exemplo.org');
  cfg('email.from', 'nao-responda@exemplo.org');
  cfg('inscricao.public_base_url', 'https://edumaps.exemplo.org/');

  cfg('envio.enabled', 'false');
  is dispara($e->{id})->{motivo}, 'envio_desligado', 'desligado';
  cfg('envio.enabled', 'true');

  $dbh->do(q{INSERT INTO clean.canal_envio_suspensoes (cod_inep, motivo) VALUES (?, 'abuso')},
           {}, $INEP);
  is dispara($e->{id})->{motivo}, 'escola_suspensa', 'suspensa';
  is $model->envio_limites($INEP)->{suspensao}{motivo}, 'abuso', 'limites mostram a suspensão';
  $dbh->do('UPDATE clean.canal_envio_suspensoes SET reativado_em = NOW() WHERE cod_inep = ?',
           {}, $INEP);

  is dispara($e->{id}, agendado_para => '2020-01-01T10:00:00Z')->{status}, 400, 'data passada';
  is dispara($e->{id}, agendado_para => '2999-01-01T10:00:00Z')->{status}, 400, '> 90 dias';
  is dispara($e->{id}, agendado_para => 'amanhã')->{status}, 400, 'formato';

  my $vazia = $model->criar_lista(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'Vazia')->{id};
  my $v = rascunho(alvo_id => $vazia);
  is dispara($v->{id})->{motivo}, 'sem_destinatarios', 'sem destinatários';
  $model->excluir_lista($INEP, $vazia);
  is dispara($v->{id})->{motivo}, 'alvo_inexistente', 'alvo excluído';
  is envio($v->{id})->{alvo}{nome}, undef, 'rascunho com alvo excluído: nome null';
  $model->envio_apagar($INEP, $v->{id});
  $model->envio_apagar($INEP, $e->{id});
  is scalar @jobs, 0, 'nada enfileirado';
};

subtest 'teto e cota (inclusive saldo do dia)' => sub {
  my $e = rascunho();
  cfg('envio.max_destinatarios', '1');
  my $r = dispara($e->{id});
  is [ @$r{qw(status motivo teto)} ], [409, 'acima_do_teto', 1], 'acima do teto';
  cfg('envio.max_destinatarios', '2000');

  # outro envio da escola já enviou 4 hoje (e 10 ontem, que não contam)
  my $velho = rascunho();
  $dbh->do(q{UPDATE clean.canal_envios SET status = 'concluido' WHERE id = ?}, {}, $velho->{id});
  for my $i (1 .. 14) {
    $dbh->do(q{INSERT INTO clean.canal_envio_destinatarios
                 (envio_id, email_hash, status, processado_em)
               VALUES (?, ?, 'enviado', CASE WHEN ? <= 4 THEN NOW()
                                             ELSE NOW() - interval '2 days' END)},
             {}, $velho->{id}, h256("velho$i"), $i);
  }
  cfg('envio.cota_diaria_escola', '5');
  is $model->envio_enviados_hoje($INEP), 4, 'enviados hoje (só o dia corrente)';
  my $lim = $model->envio_limites($INEP);
  is [ @$lim{qw(cota_diaria enviados_hoje saldo_hoje)} ], [5, 4, 1], 'limites';
  ok $lim->{smtp_disponivel} && $lim->{enabled}, 'smtp e enabled';
  $r = dispara($e->{id});
  is [ @$r{qw(status motivo saldo)} ], [409, 'cota_insuficiente', 1], 'saldo insuficiente (2 > 1)';

  my $amanha = $dbh->selectrow_array(
    q{SELECT to_char((NOW() + interval '1 day') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')});
  $r = dispara($e->{id}, agendado_para => $amanha);
  is $r->{status}, 'agendado', 'agendado: compara com a cota diária, não com o saldo';
  is $r->{agendado_para}, $amanha, 'agendado_para';
  ok $jobs[-1][1] > 86000 && $jobs[-1][1] <= 86400, 'delay até o agendamento';
  is $dbh->selectrow_array('SELECT minion_job_id FROM clean.canal_envios WHERE id = ?', {}, $e->{id}),
    4242, 'minion_job_id guardado';
  is lote($e->{id})->{motivo}, 'agendado', 'job adiantado: reagenda para a hora';
  is envio($e->{id})->{status}, 'agendado', 'continua agendado';
  is $model->envio_cancelar($INEP, $e->{id})->{status}, 'cancelado', 'cancela o agendado';
  $dbh->do('DELETE FROM clean.canal_envios WHERE id = ?', {}, $velho->{id});
  cfg('envio.cota_diaria_escola', '500');
};

subtest 'disparo para lista: fotografia, lote, rodapé, cabeçalhos, idempotência' => sub {
  @enviados = ();
  my $e = rascunho();
  my $r = dispara($e->{id});
  is $r->{status}, 'enviando', 'imediato → enviando';
  ok $r->{iniciado_em}, 'iniciado_em';
  is $jobs[-1], [ $e->{id}, 0 ], 'enfileirado sem delay';
  is $r->{contadores}{destinatarios}, 2, 'Ana e Bia (Davi sem e-mail)';
  is $r->{contadores}{pendentes}, 2, 'pendentes';
  is $r->{alvo}{nome}, 'Lista A', 'fotografia do nome';
  is $model->envio_atualizar($INEP, $e->{id}, assunto => 'x')->{status}, 409, 'PATCH fora de rascunho';
  is $model->envio_apagar($INEP, $e->{id})->{status}, 409, 'DELETE fora de rascunho';
  is dispara($e->{id})->{motivo}, 'status', 'disparar de novo → 409 status';

  my $d = dest($e->{id});
  for my $x (@$d) {
    my $tok = substr(hmac_sha256_hex("saida:$x->{id}", $SECRET), 0, 32);
    is $x->{saida_hash}, sha256_hex($tok), "saida_hash = sha256(token) ($x->{id})";
    is $x->{email_hash}, h256($x->{email}), 'email_hash';
  }

  # fotografia: quem entra depois do disparo não recebe; renomear não muda
  membro($l{A}, $c{Caio});
  $dbh->do(q{UPDATE clean.canal_listas SET nome = 'Lista A renomeada' WHERE id = ?}, {}, $l{A});
  is envio($e->{id})->{alvo}{nome}, 'Lista A', 'alvo.nome é a fotografia';

  my $res = lote($e->{id});
  is $res, { fim => 'concluido', processados => 2 }, 'concluído num lote';
  is scalar @enviados, 2, 'dois e-mails';
  is [ sort map { $_->{to} } @enviados ], [ mail(1), mail(2) ], 'só a fotografia';

  my ($ana) = grep { $_->{to} eq mail(1) } @enviados;
  my $d_ana = (grep { $_->{email_hash} eq h256(mail(1)) } @$d)[0];
  my $tok = substr(hmac_sha256_hex("saida:$d_ana->{id}", $SECRET), 0, 32);
  my $link = "https://edumaps.exemplo.org/privacidade/sair/$tok";
  like $ana->{envelope}, qr{^List-Unsubscribe: <\Q$link\E>\r$}m, 'List-Unsubscribe com o link';
  like $ana->{envelope}, qr{^List-Unsubscribe-Post: List-Unsubscribe=One-Click\r$}m, 'One-Click';
  like $ana->{envelope}, qr{^Precedence: bulk\r$}m, 'Precedence';
  like $ana->{envelope}, qr/Reunião na sexta\.\n\n--\n/, 'corpo + separador';
  like $ana->{envelope}, qr/Você recebe este e-mail porque se inscreveu na lista "Lista A renomeada" da escola Escola $INEP\./,
    'rodapé com lista e escola';
  like $ana->{envelope}, qr/Motivo: Aviso\./, 'motivo';
  like $ana->{envelope}, qr/Não quer mais receber mensagens desta lista\? \Q$link\E/, 'link de saída';
  like $ana->{envelope}, qr{Privacidade e remoção dos seus dados: https://edumaps\.exemplo\.org/privacidade\r?$}m,
    'link de privacidade';

  my $f = envio($e->{id});
  is $f->{status}, 'concluido', 'concluido';
  ok $f->{concluido_em}, 'concluido_em';
  is [ @{ $f->{contadores} }{qw(destinatarios enviados falhas ignorados pendentes)} ], [2, 2, 0, 0, 0],
    'contadores';
  $d = dest($e->{id});
  ok !(grep { defined $_->{email} } @$d), 'email zerado ao concluir';
  ok !(grep { !$_->{mensagem_id} || !$_->{processado_em} } @$d), 'mensagem_id e processado_em';
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_mensagens
       WHERE referente_tipo = 'envio' AND referente_id = ? AND status = 'sent'
         AND operacao = 'aviso' AND contato_id IS NOT NULL}, {}, $e->{id}), 2, 'histórico';

  @enviados = ();
  is lote($e->{id}), { fim => 'concluido' }, 'segundo lote: sai';
  $dbh->do(q{UPDATE clean.canal_envios SET status = 'enviando' WHERE id = ?}, {}, $e->{id});
  lote($e->{id});
  is scalar @enviados, 0, 'reprocessar não reenvia (só pendente é processado)';
  $dbh->do(q{UPDATE clean.canal_listas SET nome = 'Lista A' WHERE id = ?}, {}, $l{A});
};

subtest 'segmento: dedupe, opt-out, anonimizado, falha, ritmo' => sub {
  @enviados = ();
  my $s = $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'A e B',
    criterios => { listas => [ $l{A}, $l{B} ] });
  # Bia saiu da lista A
  $dbh->do(q{INSERT INTO clean.canal_optouts (lista_id, email_hash) VALUES (?, ?)},
           {}, $l{A}, h256(mail(2)));
  my $e = rascunho(alvo_tipo => 'segmento', alvo_id => $s->{id}, operacao => 'convite');

  my $p = $model->envio_previa($INEP, $e->{id});
  is $p->{estimativa}, { destinatarios => 2, ignorados_optout => 1, ignorados_duplicado => 2 },
    'estimativa (Ana e Caio duplicados em A e B)';
  like $p->{texto}, qr{/privacidade/sair/EXEMPLO}, 'prévia com link EXEMPLO';
  like $p->{texto}, qr/lista "A e B"/, 'prévia com o nome do alvo';
  like $p->{texto}, qr/Motivo: Convite\./, 'motivo';

  my $r = dispara($e->{id});
  is [ @{ $r->{contadores} }{qw(destinatarios ignorados pendentes)} ], [3, 3, 2],
    '3 linhas (1 opt-out), ignorados = 2 duplicados + 1 opt-out';
  my $d = dest($e->{id});
  my ($bia) = grep { $_->{email_hash} eq h256(mail(2)) } @$d;
  is [ $bia->{status}, $bia->{email}, $bia->{saida_hash} ], ['ignorado_optout', undef, undef],
    'opt-out sem e-mail nem token';
  my ($caio) = grep { $_->{email_hash} eq h256(mail(3)) } @$d;
  is $caio->{lista_id}, $l{A}, 'Caio: lista de origem = menor id (A)';

  # Ana anonimizada no meio do envio; ritmo 1 por lote; SMTP falha no Caio
  my ($ana) = grep { $_->{email_hash} eq h256(mail(1)) } @$d;
  $dbh->do('UPDATE clean.canal_envio_destinatarios SET email = NULL WHERE id = ?', {}, $ana->{id});
  cfg('envio.ritmo_por_minuto', '1');
  is lote($e->{id}), { reagendar => 60, processados => 1 }, 'lote de 1, reagenda em 60 s';
  is((grep { $_->{id} == $ana->{id} } @{ dest($e->{id}) })[0]{status}, 'ignorado_anonimizado',
     'anonimizado no meio → ignorado_anonimizado');
  $smtp_ok = 0;
  is lote($e->{id}), { fim => 'concluido', processados => 1 }, 'último lote';
  $smtp_ok = 1;
  my ($caio2) = grep { $_->{id} == $caio->{id} } @{ dest($e->{id}) };
  is [ $caio2->{status}, $caio2->{erro} ], ['falhou', 'SMTP: falha em data'], 'falha registrada';
  my $f = envio($e->{id});
  is [ @{ $f->{contadores} }{qw(destinatarios enviados falhas ignorados)} ], [3, 0, 1, 4],
    'concluído mesmo com falha';
  is scalar @enviados, 0, 'nada entregue';
  cfg('envio.ritmo_por_minuto', '60');
  $dbh->do('DELETE FROM clean.canal_optouts WHERE lista_id = ?', {}, $l{A});
};

subtest 'pausa por cota e retomada' => sub {
  @enviados = ();
  my $e = rascunho(alvo_id => $l{B});    # Ana e Caio
  is dispara($e->{id})->{status}, 'enviando', 'disparado';
  my $hoje = $model->envio_enviados_hoje($INEP);
  cfg('envio.cota_diaria_escola', $hoje + 1);
  my $r = lote($e->{id});
  is $r->{status}, 'pausado_cota', 'pausado_cota';
  is $r->{processados}, 1, 'enviou o saldo';
  ok $r->{reagendar} > 0 && $r->{reagendar} <= 86_400 + 300, 'reagenda para 00:05';
  is $r->{reagendar}, $model->envio_segundos_ate_retomada, 'até 00:05 (São Paulo)';
  is envio($e->{id})->{status}, 'pausado_cota', 'estado';
  is $model->envio_limites($INEP)->{saldo_hoje}, 0, 'saldo zerado';

  cfg('envio.cota_diaria_escola', '500');
  is lote($e->{id}), { fim => 'concluido', processados => 1 }, 'retomada: conclui';
  is scalar @enviados, 2, 'cada um recebeu uma vez';
};

subtest 'suspensão durante o envio; desligado/SMTP reagendam' => sub {
  @enviados = ();
  my $e = rascunho();
  dispara($e->{id});
  cfg('envio.enabled', 'false');
  is lote($e->{id}), { reagendar => 300, motivo => 'envio_desligado' }, 'desligado: 300 s';
  cfg('envio.enabled', 'true');
  cfg('email.enabled', 'false');
  is lote($e->{id}), { reagendar => 300, motivo => 'smtp_indisponivel' }, 'SMTP: 300 s';
  cfg('email.enabled', 'true');
  is envio($e->{id})->{status}, 'enviando', 'estado inalterado';

  $dbh->do(q{INSERT INTO clean.canal_envio_suspensoes (cod_inep, motivo) VALUES (?, 'teste')},
           {}, $INEP);
  is lote($e->{id}), { fim => 'suspenso' }, 'suspensa: para';
  is envio($e->{id})->{status}, 'suspenso', 'suspenso';
  is scalar @enviados, 0, 'nada enviado';
  $dbh->do('UPDATE clean.canal_envio_suspensoes SET reativado_em = NOW() WHERE cod_inep = ?',
           {}, $INEP);
  is lote($e->{id})->{fim}, 'concluido', 'reativada: o job retoma';
  is scalar @enviados, 3, 'Ana, Bia e Caio (Caio entrou na lista A antes deste disparo)';
};

subtest 'cancelamento' => sub {
  @enviados = ();
  my $e = rascunho();
  dispara($e->{id});
  cfg('envio.ritmo_por_minuto', '1');
  lote($e->{id});
  my $c = $model->envio_cancelar($INEP, $e->{id});
  is $c->{status}, 'cancelado', 'cancelado';
  ok $c->{cancelado_em}, 'cancelado_em';
  is [ @{ $c->{contadores} }{qw(enviados pendentes cancelados)} ], [1, 0, 2], 'pendentes → cancelado';
  ok !(grep { defined $_->{email} } @{ dest($e->{id}) }), 'e-mails zerados';
  is lote($e->{id}), { fim => 'cancelado' }, 'job sai';
  is scalar @enviados, 1, 'só o primeiro saiu';
  is $model->envio_cancelar($INEP, $e->{id})->{status}, 409, 'cancelar de novo → 409';
  ok !$model->envio_cancelar($OUTRA, $e->{id}), 'outra escola: undef';
  cfg('envio.ritmo_por_minuto', '60');
};

subtest 'teste para o gestor' => sub {
  @enviados = ();
  my $e = rascunho();
  my $hoje = $model->envio_enviados_hoje($INEP);
  my $r = $model->envio_teste(cod_inep => $INEP, id => $e->{id}, gestor_id => $g{$INEP},
                              smtp_transport => $smtp);
  is $r, { enviado => 1, para => 'g***@e***.test' }, '202 com e-mail mascarado';
  my ($subj) = $enviados[0]{envelope} =~ /^Subject: =\?UTF-8\?B\?(\S+)\?=/m;
  require MIME::Base64;
  like Encode::decode('UTF-8', MIME::Base64::decode_base64($subj // '')), qr/^\[Teste\] Reunião/,
    'assunto de teste';
  like $enviados[0]{envelope}, qr{/privacidade/sair/EXEMPLO}, 'link EXEMPLO';
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_mensagens
       WHERE referente_tipo = 'envio_teste' AND referente_id = ?}, {}, $e->{id}), 1, 'histórico de teste';
  is $model->envio_enviados_hoje($INEP), $hoje, 'não conta na cota';
  $model->envio_teste(cod_inep => $INEP, id => $e->{id}, gestor_id => $g{$INEP},
                      smtp_transport => $smtp) for 2 .. 5;
  is $model->envio_teste(cod_inep => $INEP, id => $e->{id}, gestor_id => $g{$INEP},
                         smtp_transport => $smtp)->{status}, 429, '6º teste → 429';

  my $e2 = rascunho();
  $smtp_ok = 0;
  is $model->envio_teste(cod_inep => $INEP, id => $e2->{id}, gestor_id => $g{$INEP},
                         smtp_transport => $smtp)->{status}, 502, 'SMTP falha → 502';
  $smtp_ok = 1;
  cfg('email.enabled', 'false');
  is $model->envio_teste(cod_inep => $INEP, id => $e2->{id}, gestor_id => $g{$INEP},
                         smtp_transport => $smtp)->{motivo}, 'smtp_indisponivel', 'sem SMTP → 409';
  cfg('email.enabled', 'true');
};

subtest 'destinatários mascarados' => sub {
  my ($e) = grep { $_->{status} eq 'concluido' } @{ $model->envio_listar($INEP)->{items} };
  my $r = $model->envio_destinatarios($INEP, $e->{id}, per_page => 2);
  is $r->{per_page}, 2, 'paginado';
  ok $r->{total} >= 2, 'total';
  for my $i (@{ $r->{items} }) {
    like $i->{email}, qr/^\w\*\*\*\@\w\*\*\*\.\w+$/, 'e-mail mascarado (mesmo depois de zerado)';
    ok defined $i->{nome}, 'nome do contato';
  }
  is $model->envio_destinatarios($INEP, $e->{id}, status => 'falhou')->{total}, 0, 'filtro por estado';
  ok $model->envio_destinatarios($INEP, $e->{id}, status => 'x')->{error}, 'estado inválido';
  ok !$model->envio_destinatarios($OUTRA, $e->{id}), 'outra escola: undef';
};

done_testing;
