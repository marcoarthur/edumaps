# t/02-models/canal_exclusao.t
# Exclusão e anonimização (issue #214 — Fase 2, RF-204..206), role
# Canal::Exclusao:
#
#   - anonimizar_contato: VARREDURA de todas as colunas text do inventário de
#     PII (contatos, inscrições, membros, refs, confirmações, mensagens) e do
#     registro de auditoria — nada do titular sobra (nome, telefone em claro
#     e normalizado, e-mail, ip_anon, user agent, chat do Telegram);
#   - registro em canal_exclusoes sem PII; idempotência (zeros, sem novo
#     registro); contato em duas listas sai das duas; nova inscrição depois da
#     exclusão cria contato novo; inscrição de terceiro (conflito) perde o
#     e-mail do titular e o resto fica;
#   - token de exclusão (exclusao_por_token / excluir_por_token), idempotente;
#   - exclusão pelo gestor (membro precisa ser da lista e da escola);
#   - #216 (onda 2): a varredura cobre canal_envio_destinatarios — e-mail e
#     contato saem; pendentes viram ignorado_anonimizado (+1 em `ignorados`);
#     o opt-out (só hash) fica.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh   = $t->app->schema->storage->dbh;
my $has   = $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')");
my $model = $t->app->model('Canal');
plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;

my $INEP   = 99560000 + ($$ % 1000);
my $OUTRA  = 99570000 + ($$ % 1000);
my $P      = sprintf '%04d', $$ % 10000;
my $GESTOR = "gestor.exclusao.$$\@edumaps.test";
my ($gestor_id, $gestor_out, %tk, %lista, @msg_ids);

my $NOME  = "Zéfiro Titular $P";
my $TEL   = "(11) 96$P-1234";
my $TELN  = "1196${P}1234";
my $EMAIL = "zefiro.$P\@exemplo.org";
my $IP    = "ipanon-titular-$P";
my $UA    = "Mozilla/5.0 Titular-$P";
my $CHAT  = 8800000000 + ($$ % 1000);

my $TEM_ENVIOS = $dbh->selectrow_array("SELECT to_regclass('clean.canal_envios')");

sub limpa {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $inep) if $TEM_ENVIOS;
    $dbh->do('DELETE FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.canal_confirmacoes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.canal_mensagens WHERE cod_inep = ?', {}, $inep);
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
  $dbh->do('DELETE FROM clean.canal_mensagens WHERE id = ANY(?)', {}, [@msg_ids]) if @msg_ids;
  $dbh->do(q{DELETE FROM clean.canal_confirmacoes WHERE salt = ?}, {}, "salt-$P");
}
END { limpa() if $has }

sub inscreve ($lista, %p) {
  return $model->registrar_inscricao(token => $tk{$lista}, consentimento => 1,
                                     ip_anon => $IP, user_agent => $UA, %p);
}
sub token_de ($r) { return ($r->{exclusao_url} =~ m{/([0-9a-f]{32})$})[0] }

# colunas text/varchar das tabelas do inventário de PII + auditoria
my @TABELAS = qw(contatos canal_inscricoes canal_lista_membros canal_confirmacao_refs
                 canal_confirmacoes canal_mensagens canal_exclusoes);
push @TABELAS, qw(canal_envio_destinatarios canal_optouts) if $TEM_ENVIOS;
my %COLS;
for my $tab (@TABELAS) {
  $COLS{$tab} = $dbh->selectcol_arrayref(
    q{SELECT column_name FROM information_schema.columns
       WHERE table_schema = 'clean' AND table_name = ?
         AND data_type IN ('text', 'character varying')}, {}, $tab);
}

# Ocorrências de `$needle` (substring, sem caixa) em qualquer coluna text das
# tabelas do inventário. Devolve a lista "tabela.coluna".
sub varre ($needle) {
  my @achados;
  for my $tab (@TABELAS) {
    for my $col (@{ $COLS{$tab} }) {
      my $n = $dbh->selectrow_array(
        qq{SELECT count(*) FROM clean.$tab WHERE strpos(lower("$col"), lower(?)) > 0},
        {}, $needle);
      push @achados, "$tab.$col" if $n;
    }
  }
  return @achados;
}

limpa();

my ($tit, $tit2, $terceiro, $ref_id, $conf_email_id, $conf_wa_id, $alheia_id, %env, %dst);

subtest 'setup: titular em duas listas + rastros em todas as tabelas' => sub {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, "Escola Exclusão $inep");
  }
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Exclusão', $GESTOR);
  ($gestor_out) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $OUTRA, 'Gestor Outra', "outra.$GESTOR");

  for my $def ([A => 'ambos', 1], [B => 'telefone', 0], [C => 'ambos', 0]) {
    my ($k, $coleta, $exige) = @$def;
    my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id,
      nome => "Lista $k", coleta => $coleta, exige_confirmacao => $exige);
    $lista{$k} = $l->{id};
    $tk{$k} = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id},
                                   gestor_id => $gestor_id)->{token};
  }

  $tit = inscreve('A', nome => $NOME, telefone => $TEL, email => $EMAIL);
  ok $tit->{ok}, 'titular inscrito na lista A';
  ok $tit->{confirmacao}{ref}, 'ref aberta (lista exige)';
  $tit2 = inscreve('B', nome => $NOME, telefone => $TEL);
  is $tit2->{contato_id}, $tit->{contato_id}, 'mesmo contato na lista B';

  # terceiro (já na agenda pelo telefone) cita o e-mail do titular: conflito
  ok inscreve('B', nome => "Outra Pessoa $P", telefone => "2197${P}0000",
                   ip_anon => "ipanon-terceiro-$P", user_agent => "UA-terceiro-$P")->{ok}, 'terceiro na B';
  $terceiro = inscreve('C', nome => "Outra Pessoa $P", telefone => "2197${P}0000",
                       email => $EMAIL, ip_anon => "ipanon-terceiro-$P",
                       user_agent => "UA-terceiro-$P");
  ok $terceiro->{ok} && $terceiro->{contato_id} != $tit->{contato_id}, 'terceiro (outro contato)';
  is $terceiro->{conflito}, 1, 'conflito marcado';

  # chat do Telegram no membro e na ref pendente
  $dbh->do(q{UPDATE clean.canal_lista_membros SET telegram_chat_id = ?
              WHERE contato_id = ? AND lista_id = ?}, {}, $CHAT, $tit->{contato_id}, $lista{B});
  ($ref_id) = $dbh->selectrow_array(q{SELECT id FROM clean.canal_confirmacao_refs
     WHERE inscricao_id = ?}, {}, $tit->{inscricao_id});
  $dbh->do('UPDATE clean.canal_confirmacao_refs SET telegram_chat_pendente = ? WHERE id = ?',
           {}, $CHAT, $ref_id);

  # códigos de confirmação pendentes (e-mail sem escola; WhatsApp no formato 55…)
  ($conf_email_id) = $dbh->selectrow_array(q{INSERT INTO clean.canal_confirmacoes
     (canal, endereco, codigo_hash, salt, expira_em) VALUES ('email', ?, 'h', ?, NOW() + interval '10 min')
     RETURNING id}, {}, $EMAIL, "salt-$P");
  ($conf_wa_id) = $dbh->selectrow_array(q{INSERT INTO clean.canal_confirmacoes
     (canal, endereco, codigo_hash, salt, expira_em) VALUES ('whatsapp', ?, 'h', ?, NOW() + interval '10 min')
     RETURNING id}, {}, "55$TELN", "salt-$P");
  ($alheia_id) = $dbh->selectrow_array(q{INSERT INTO clean.canal_confirmacoes
     (canal, endereco, codigo_hash, salt, expira_em) VALUES ('email', ?, 'h', ?, NOW() + interval '10 min')
     RETURNING id}, {}, "alheio.$P\@exemplo.org", "salt-$P");

  # mensagens: por contato_id, por endereço (sem contato), por código, por ref
  my $msg = sub (%m) {
    my ($id) = $dbh->selectrow_array(q{INSERT INTO clean.canal_mensagens
       (canal, operacao, destinatario, assunto, corpo, erro, referente_tipo, referente_id,
        contato_id, cod_inep, status)
       VALUES (?, 'confirmacao', ?, 'Confirmação de contato', ?, ?, ?, ?, ?, ?, 'sent')
       RETURNING id}, {}, @m{qw(canal dest corpo erro rtipo rid contato cod)});
    push @msg_ids, $id;
    return $id;
  };
  $msg->(canal => 'email', dest => $EMAIL, corpo => "Olá $NOME", contato => $tit->{contato_id},
         cod => $INEP);
  $msg->(canal => 'email', dest => $EMAIL, corpo => "código ******",
         erro => "550 <$EMAIL> rejected", rtipo => 'confirmacao', rid => $conf_email_id);
  $msg->(canal => 'whatsapp', dest => "55$TELN", corpo => 'código ******');
  $msg->(canal => 'telegram', dest => "$CHAT", corpo => "Oi $NOME",
         rtipo => 'confirmacao_ref', rid => $ref_id);
  $msg->(canal => 'email', dest => "alheio.$P\@exemplo.org", corpo => 'mensagem de outra pessoa');

  # envios por e-mail (#216): titular pendente num envio em curso, já
  # enviado noutro (e-mail em claro até concluir), e um terceiro pendente
  if ($TEM_ENVIOS) {
    for my $k (qw(curso outro)) {
      ($env{$k}) = $dbh->selectrow_array(q{INSERT INTO clean.canal_envios
          (cod_inep, gestor_id, alvo_tipo, alvo_id, alvo_nome, operacao, assunto, corpo,
           status, destinatarios, ignorados)
          VALUES (?, ?, 'lista', ?, 'Lista A', 'aviso', 'A', 'B', 'enviando', 2, 0) RETURNING id},
        {}, $INEP, $gestor_id, $lista{A});
    }
    my $d = sub ($envio, $contato, $email, $status) {
      my ($id) = $dbh->selectrow_array(q{INSERT INTO clean.canal_envio_destinatarios
          (envio_id, contato_id, lista_id, email, email_hash, status, processado_em)
          VALUES (?, ?, ?, ?, encode(digest(?::text, 'sha256'), 'hex'), ?,
                  CASE WHEN ? = 'pendente' THEN NULL ELSE NOW() END) RETURNING id},
        {}, $envio, $contato, $lista{A}, $email, $email, $status, $status);
      return $id;
    };
    $dst{pend}     = $d->($env{curso}, $tit->{contato_id}, $EMAIL, 'pendente');
    $dst{terceiro} = $d->($env{curso}, $terceiro->{contato_id}, "terceiro.$P\@exemplo.org", 'pendente');
    $dst{enviado}  = $d->($env{outro}, $tit->{contato_id}, $EMAIL, 'enviado');
    $dbh->do(q{INSERT INTO clean.canal_optouts (lista_id, email_hash, envio_id)
               VALUES (?, encode(digest(?::text, 'sha256'), 'hex'), ?)}, {}, $lista{A}, $EMAIL, $env{outro});
  }

  for my $needle ($NOME, $TELN, $EMAIL, $IP, $UA, "$CHAT") {
    ok scalar(varre($needle)), "rastro presente antes: $needle";
  }
};

my $exclusao;
subtest 'anonimizar_contato: varredura do inventário de PII' => sub {
  my $antes_terceiro = $dbh->selectrow_hashref(
    'SELECT * FROM clean.canal_inscricoes WHERE id = ?', {}, $terceiro->{inscricao_id});

  $exclusao = $model->anonimizar_contato($INEP, $tit->{contato_id},
    origem => 'gestor', gestor_id => $gestor_id, motivo => 'pedido feito à secretaria');
  is $exclusao->{contatos}, 1, '1 contato';
  is $exclusao->{inscricoes}, 2, '2 inscrições';
  is $exclusao->{membros}, 2, 'saiu das duas listas';
  ok $exclusao->{exclusao_id}, 'registro de auditoria';

  for my $needle ($NOME, $TEL, $TELN, "55$TELN", $EMAIL, $IP, $UA, "$CHAT") {
    is [ varre($needle) ], [], "nada sobrou: $needle";
  }

  my $c = $dbh->selectrow_hashref('SELECT * FROM clean.contatos WHERE id = ?', {}, $tit->{contato_id});
  is [ @$c{qw(nome telefone email)} ], ['[removido]', undef, undef], 'contato anonimizado (não apagado)';

  my $ins = $dbh->selectall_arrayref(
    'SELECT * FROM clean.canal_inscricoes WHERE contato_id = ? ORDER BY id', { Slice => {} },
    $tit->{contato_id});
  is scalar @$ins, 2, 'inscrições preservadas';
  for my $i (@$ins) {
    is $i->{nome}, '[removido]', 'inscrição: nome';
    ok !defined($i->{$_}), "inscrição: $_ NULL"
      for qw(telefone telefone_norm email email_norm ip_anon user_agent);
    ok defined $i->{anonimizado_em}, 'anonimizado_em';
    ok defined $i->{consentimento_versao} && defined $i->{consentimento_em}, 'consentimento fica';
    ok defined $i->{exclusao_hash}, 'hash do token fica (idempotência do link)';
  }

  is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_lista_membros WHERE contato_id = ?',
                           {}, $tit->{contato_id}), 0, 'sem membros';
  is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_lista_membros WHERE telegram_chat_id = ?',
                           {}, $CHAT), 0, 'chat do Telegram não sobra em membros';
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_confirmacao_refs
       WHERE telegram_chat_pendente = ? OR inscricao_id = ?}, {}, $CHAT, $tit->{inscricao_id}),
    0, 'refs sem chat / removidas';

  my $conf = $dbh->selectall_hashref(
    'SELECT id, endereco, (expira_em <= NOW()) AS expirada FROM clean.canal_confirmacoes WHERE id = ANY(?)',
    'id', {}, [$conf_email_id, $conf_wa_id, $alheia_id]);
  for my $id ($conf_email_id, $conf_wa_id) {
    like $conf->{$id}{endereco}, qr/^sha256:[0-9a-f]{64}$/, "confirmação $id: endereço em hash";
    ok $conf->{$id}{expirada}, "confirmação $id: pendente expirada";
  }
  is $conf->{$alheia_id}{endereco}, "alheio.$P\@exemplo.org", 'confirmação alheia intacta';
  ok !$conf->{$alheia_id}{expirada}, 'confirmação alheia ainda válida';

  my $msgs = $dbh->selectall_arrayref(
    'SELECT destinatario, corpo FROM clean.canal_mensagens WHERE id = ANY(?) ORDER BY id',
    { Slice => {} }, [@msg_ids]);
  is [ map { $_->{destinatario} } @$msgs[0..3] ], [('[removido]') x 4], 'destinatários apagados';
  is [ map { $_->{corpo} } @$msgs[0..3] ], [(undef) x 4], 'corpos apagados';
  is $msgs->[4], { destinatario => "alheio.$P\@exemplo.org", corpo => 'mensagem de outra pessoa' },
    'mensagem alheia intacta';

  # terceiro: só o e-mail do titular sai da inscrição dele
  my $ter = $dbh->selectrow_hashref('SELECT * FROM clean.canal_inscricoes WHERE id = ?',
                                    {}, $terceiro->{inscricao_id});
  ok !defined $ter->{email} && !defined $ter->{email_norm}, 'terceiro: e-mail do titular removido';
  is [ @$ter{qw(nome telefone_norm ip_anon user_agent)} ],
     [ @$antes_terceiro{qw(nome telefone_norm ip_anon user_agent)} ], 'terceiro: resto intacto';
  ok !defined $ter->{anonimizado_em}, 'terceiro não anonimizado';
  is $dbh->selectrow_array('SELECT nome FROM clean.contatos WHERE id = ?', {}, $terceiro->{contato_id}),
    "Outra Pessoa $P", 'contato do terceiro intacto';

  # auditoria sem PII
  my $ex = $dbh->selectrow_hashref('SELECT * FROM clean.canal_exclusoes WHERE id = ?',
                                   {}, $exclusao->{exclusao_id});
  is [ @$ex{qw(cod_inep origem gestor_id contatos inscricoes membros motivo)} ],
     [ $INEP, 'gestor', $gestor_id, 1, 2, 2, 'pedido feito à secretaria' ], 'registro de auditoria';
  ok !defined $ex->{regra}, 'sem regra (não é retenção)';

  # destinatários de envio (#216, onda 2)
  if ($TEM_ENVIOS) {
    my $rows = $dbh->selectall_hashref(
      q{SELECT id, contato_id, email, status, (processado_em IS NOT NULL) AS processado
        FROM clean.canal_envio_destinatarios WHERE id = ANY(?)}, 'id', {}, [values %dst]);
    is [ @{ $rows->{ $dst{pend} } }{qw(contato_id email status processado)} ],
       [ undef, undef, 'ignorado_anonimizado', 1 ], 'pendente → ignorado_anonimizado, sem PII';
    is [ @{ $rows->{ $dst{enviado} } }{qw(contato_id email status)} ],
       [ undef, undef, 'enviado' ], 'enviado fica enviado, sem PII';
    is [ @{ $rows->{ $dst{terceiro} } }{qw(contato_id email status)} ],
       [ $terceiro->{contato_id}, "terceiro.$P\@exemplo.org", 'pendente' ], 'terceiro intacto';
    my $ign = $dbh->selectall_hashref('SELECT id, ignorados FROM clean.canal_envios WHERE id = ANY(?)',
                                      'id', {}, [values %env]);
    is $ign->{ $env{curso} }{ignorados}, 1, '+1 em ignorados do envio em curso';
    is $ign->{ $env{outro} }{ignorados}, 0, 'envio sem pendente do titular: ignorados intacto';
    is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_optouts WHERE envio_id = ?', {}, $env{outro}),
      1, 'opt-out (só hash) fica';
  }
};

subtest 'idempotência' => sub {
  if ($TEM_ENVIOS) {
    $model->anonimizar_contato($INEP, $tit->{contato_id}, origem => 'gestor');
    is $dbh->selectrow_array('SELECT ignorados FROM clean.canal_envios WHERE id = ?', {}, $env{curso}),
      1, 'envio: sem novo +1 em ignorados';
  }
  my $n = $dbh->selectrow_array('SELECT count(*) FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $INEP);
  my $r = $model->anonimizar_contato($INEP, $tit->{contato_id}, origem => 'gestor');
  is [ @$r{qw(contatos inscricoes membros)} ], [0, 0, 0], 'zeros na repetição';
  ok !$r->{exclusao_id}, 'sem novo registro';
  is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $INEP),
    $n, 'canal_exclusoes inalterada';

  ok !defined $model->anonimizar_contato($OUTRA, $tit->{contato_id}, origem => 'gestor'),
    'contato de outra escola → undef';
  ok dies { $model->anonimizar_contato($INEP, $tit->{contato_id}, origem => 'x') }, 'origem inválida';
};

subtest 'token: ja_excluido e idempotente' => sub {
  my $tok = token_de($tit);
  my $e = $model->exclusao_por_token($tok);
  is $e->{ja_excluido}, 1, 'inscrição do token já anonimizada';
  is $e->{escola_nome}, "Escola Exclusão $INEP", 'escola';
  is $e->{lista_nome}, 'Lista A', 'lista';
  is $model->excluir_por_token($tok), { ok => 1, ja_excluido => 1 }, 'POST repetido idempotente';
  ok !defined $model->exclusao_por_token('0' x 32), 'inexistente';
  ok !defined $model->exclusao_por_token('xyz'), 'formato inválido';
};

subtest 'nova inscrição depois da exclusão cria contato novo; titular pelo token' => sub {
  my $novo = inscreve('B', nome => $NOME, telefone => $TEL);
  ok $novo->{ok}, 'reinscrição';
  isnt $novo->{contato_id}, $tit->{contato_id}, 'contato novo';
  ok !$novo->{duplicado}, 'não é duplicado';
  # inscreve também na A (mesmo contato novo) e exclui pelo token da B
  my $na = inscreve('A', nome => $NOME, telefone => $TEL, email => $EMAIL);
  is $na->{contato_id}, $novo->{contato_id}, 'mesmo contato novo na lista A';

  my $r = $model->excluir_por_token(token_de($novo));
  is [ @$r{qw(ok contatos inscricoes membros ja_excluido)} ], [1, 1, 2, 2, 0], 'excluído pelo titular';
  my $ex = $dbh->selectrow_hashref('SELECT * FROM clean.canal_exclusoes WHERE id = ?', {}, $r->{exclusao_id});
  is [ @$ex{qw(origem gestor_id motivo)} ], ['titular', undef, undef], 'origem titular';
  is [ varre($TELN) ], [], 'telefone não sobra';
  is [ varre($EMAIL) ], [], 'e-mail não sobra';
  is $model->exclusao_por_token(token_de($na))->{ja_excluido}, 1, 'token da outra inscrição: já excluído';
};

subtest 'excluir_membro: posse (lista e escola)' => sub {
  my $p = inscreve('B', nome => "Pessoa B $P", telefone => "3198${P}5555");
  my $m = $p->{membro_id};
  ok !defined $model->excluir_membro($INEP, $lista{A}, $m), 'membro de outra lista → undef';
  ok !defined $model->excluir_membro($OUTRA, $lista{B}, $m), 'outra escola → undef';
  ok !defined $model->excluir_membro($INEP, $lista{B}, 999999999), 'inexistente → undef';
  my $r = $model->excluir_membro($INEP, $lista{B}, $m, gestor_id => $gestor_id, motivo => '  ');
  is [ @$r{qw(contatos inscricoes membros)} ], [1, 1, 1], 'removido';
  ok !defined $dbh->selectrow_array('SELECT motivo FROM clean.canal_exclusoes WHERE id = ?',
                                    {}, $r->{exclusao_id}), 'motivo vazio vira NULL';

  my $h = $model->listar_exclusoes($INEP);
  is scalar @$h, 3, 'histórico da escola';
  is $h->[0]{id}, $r->{exclusao_id}, 'mais recente primeiro';
  like $h->[0]{created_at}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'created_at ISO';
  is [ sort keys %{ $h->[0] } ],
     [ sort qw(id origem regra motivo gestor_id contatos inscricoes membros created_at) ], 'campos';
  is $model->listar_exclusoes($OUTRA), [], 'outra escola sem histórico';
};

done_testing;
