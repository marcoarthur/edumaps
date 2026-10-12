# t/02-models/canal_email.t
# E-mail e LGPD nas listas com QR (issue #214 — Fase 2), roles
# Canal::Listas + Canal::Confirmacao:
#
#   - `coleta` por lista (criar/atualizar, campos/obrigatorios do GET público);
#   - inscrição com e-mail: obrigatoriedade por coleta, validação, `qualquer`
#     sem contato, normalização;
#   - dedupe não destrutivo por e-mail, conflito telefone × e-mail (reusa o do
#     telefone, NÃO grava o e-mail no contato), preenchimento do e-mail ausente;
#   - consentimento: versão vigente + hash gravados; versão divergente;
#   - token de exclusão (só o hash no banco);
#   - confirmação por contato: pendente -> parcial -> confirmado; ref usada só
#     no confirmado; canais por contato; e-mail disponível conforme a config.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh        = $t->app->schema->storage->dbh;
my $has        = $dbh->selectrow_array("SELECT to_regclass('clean.consentimento_versoes')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model      = $t->app->model('Canal');

my $INEP   = 99550000 + ($$ % 1000);
my $GESTOR = sprintf 'gestor.email.%d@edumaps.test', $$;
my $MASTER = 'chave-mestra-de-teste-12345';
my $P      = sprintf '%04d', $$ % 10000;
my ($gestor_id, %tk, %lista);

sub tel ($n)   { return "1195${P}0$n" }
sub mail ($n)  { return "pessoa$n.$P\@exemplo.org" }

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
             WHERE key LIKE 'canais.email.%' OR key LIKE 'canais.telegram.%'
                OR key LIKE 'canais.whatsapp.%' OR key = 'canais.inscricao.public_base_url'});
}
END { limpa_tudo(); limpa_config(); }

sub inscreve ($coleta, %p) {
  return $model->registrar_inscricao(token => $tk{$coleta}, consentimento => 1, %p);
}
sub cfg ($k, $v) {
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put("canais.$k", $v, 'teste');
}

subtest 'setup + coleta nas listas' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has && $has_config;
  limpa_tudo(); limpa_config();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola E-mail');
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor E-mail', $GESTOR);

  ok $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'X',
                         coleta => 'fax')->{error}, 'coleta inválida';

  for my $c (qw(telefone email ambos qualquer)) {
    my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id,
                                nome => "Lista $c", coleta => $c,
                                exige_confirmacao => ($c eq 'ambos' ? 1 : 0));
    is $l->{coleta}, $c, "coleta $c";
    $lista{$c} = $l->{id};
    $tk{$c} = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id},
                                   gestor_id => $gestor_id)->{token};
  }
  my $d = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Default');
  is $d->{coleta}, 'telefone', 'default telefone';
  is $model->atualizar_lista($INEP, $d->{id}, coleta => 'email')->{coleta}, 'email', 'PATCH coleta';
  is $model->atualizar_lista($INEP, $d->{id}, coleta => 'x')->{status}, 400, 'PATCH inválido';

  my %esperado = (
    telefone => [ [qw(nome telefone)], [qw(nome telefone)] ],
    email    => [ [qw(nome email)], [qw(nome email)] ],
    ambos    => [ [qw(nome telefone email)], [qw(nome telefone email)] ],
    qualquer => [ [qw(nome telefone email)], [qw(nome)] ],
  );
  for my $c (sort keys %esperado) {
    my $pub = $model->dados_publicos_token($tk{$c});
    is $pub->{campos}, $esperado{$c}[0], "campos ($c)";
    is $pub->{obrigatorios}, $esperado{$c}[1], "obrigatorios ($c)";
    is $pub->{consentimento}{versao}, $model->consentimento_vigente->{versao}, "consentimento ($c)";
    ok length $pub->{consentimento}{texto}, 'texto do consentimento';
  }
};

subtest 'validação por coleta' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has && $has_config;
  my $erro = sub ($r) { $r->{ok} ? 'ok' : "$r->{reason}: " . ($r->{erro} // '') };

  like $erro->(inscreve('email', nome => 'A')), qr/^campos: e-mail é obrigatório/, 'email: sem e-mail';
  like $erro->(inscreve('email', nome => 'A', email => 'nao-e-email')),
    qr/^campos: e-mail inválido/, 'email: inválido';
  like $erro->(inscreve('ambos', nome => 'A', email => mail(0))),
    qr/^campos: telefone é obrigatório/, 'ambos: sem telefone';
  like $erro->(inscreve('ambos', nome => 'A', telefone => tel(0))),
    qr/^campos: e-mail é obrigatório/, 'ambos: sem e-mail';
  like $erro->(inscreve('qualquer', nome => 'A')),
    qr/^campos: Informe pelo menos um contato/, 'qualquer: nenhum contato';
  like $erro->(inscreve('qualquer', nome => 'A', telefone => '123')),
    qr/^campos: telefone precisa/, 'qualquer: telefone curto';
  like $erro->(inscreve('telefone', nome => 'A', email => mail(0))),
    qr/^campos: telefone é obrigatório/, 'telefone: e-mail não substitui';
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_inscricoes i
       JOIN clean.canal_listas l ON l.id = i.lista_id WHERE l.cod_inep = ?}, {}, $INEP),
    0, 'nada gravado';
};

subtest 'inscrição com e-mail: normalização, consentimento, exclusão' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has && $has_config;
  cfg('inscricao.public_base_url', 'https://edumaps.exemplo.org/');

  my $r = inscreve('email', nome => 'Bia', email => "  Bia.$P\@Exemplo.ORG ");
  ok $r->{ok}, 'ok';
  like $r->{exclusao_url}, qr{^https://edumaps\.exemplo\.org/privacidade/exclusao/[0-9a-f]{32}$},
    'exclusao_url com a base pública';
  my ($tok) = $r->{exclusao_url} =~ m{/([0-9a-f]{32})$};

  my $i = $dbh->selectrow_hashref('SELECT * FROM clean.canal_inscricoes WHERE id = ?',
                                  {}, $r->{inscricao_id});
  is $i->{email}, "Bia.$P\@Exemplo.ORG", 'e-mail bruto (trim)';
  is $i->{email_norm}, lc("bia.$P\@exemplo.org"), 'e-mail normalizado';
  ok !defined $i->{telefone} && !defined $i->{telefone_norm}, 'sem telefone';
  my $vig = $model->consentimento_vigente;
  is $i->{consentimento_versao}, $vig->{versao}, 'versão vigente gravada';
  is $i->{consentimento_hash}, $vig->{texto_hash}, 'hash do texto gravado';
  is $i->{exclusao_hash}, sha256_hex($tok), 'só o hash do token de exclusão';
  unlike join('|', map { $_ // '' } values %$i), qr/\Q$tok\E/, 'token em claro não gravado';

  my $c = $dbh->selectrow_hashref('SELECT * FROM clean.contatos WHERE id = ?', {}, $r->{contato_id});
  is $c->{email}, "Bia.$P\@Exemplo.ORG", 'contato criado com o e-mail';
  ok !defined $c->{telefone}, 'contato sem telefone';

  # consentimento_versao: igual à vigente aceita; diferente -> recusa com o texto
  ok inscreve('email', nome => 'Bia', email => "bia.$P\@exemplo.org",
              consentimento_versao => $vig->{versao})->{ok}, 'versão vigente aceita';
  my $x = inscreve('email', nome => 'Bia', email => "bia.$P\@exemplo.org",
                   consentimento_versao => '0.9');
  is $x->{reason}, 'consentimento_versao', 'versão desatualizada recusada';
  is $x->{consentimento}, { versao => $vig->{versao}, texto => $vig->{texto} },
    'devolve a vigente';
};

subtest 'dedupe por e-mail e conflito telefone × e-mail' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has && $has_config;

  # contato A só com telefone (lista telefone); contato B só com e-mail
  my $a = inscreve('telefone', nome => 'Ana', telefone => tel(1));
  my $b = inscreve('email', nome => 'Beto', email => mail(2));
  ok $a->{ok} && $b->{ok}, 'dois contatos';
  isnt $a->{contato_id}, $b->{contato_id}, 'diferentes';

  # mesmo e-mail em outra lista (case diferente): reusa B
  my $b2 = inscreve('qualquer', nome => 'Beto', email => uc mail(2));
  is $b2->{contato_id}, $b->{contato_id}, 'dedupe por e-mail (lower)';
  is $b2->{duplicado}, 1, 'duplicado';
  is $b2->{conflito}, 0, 'sem conflito';

  # telefone de A + e-mail de B: reusa A, marca conflito, não grava o e-mail em A
  my $x = inscreve('ambos', nome => 'Ana', telefone => tel(1), email => mail(2));
  is $x->{contato_id}, $a->{contato_id}, 'reusa o contato do telefone';
  is $x->{conflito}, 1, 'conflito';
  ok !defined $dbh->selectrow_array('SELECT email FROM clean.contatos WHERE id = ?',
                                    {}, $a->{contato_id}), 'e-mail não gravado em A';
  is $dbh->selectrow_array('SELECT email FROM clean.contatos WHERE id = ?', {}, $b->{contato_id}),
    mail(2), 'B intacto';
  is $dbh->selectrow_array('SELECT email_norm FROM clean.canal_inscricoes WHERE id = ?',
                           {}, $x->{inscricao_id}), mail(2), 'e-mail fica na inscrição';

  # telefone de A + e-mail novo: reusa A e preenche o e-mail ausente
  my $y = inscreve('ambos', nome => 'Ana', telefone => tel(1), email => mail(3));
  is $y->{contato_id}, $a->{contato_id}, 'reusa A';
  is $y->{conflito}, 0, 'sem conflito';
  is $dbh->selectrow_array('SELECT email FROM clean.contatos WHERE id = ?', {}, $a->{contato_id}),
    mail(3), 'e-mail preenchido no contato sem e-mail';

  # e-mail de B + telefone novo: reusa B e preenche o telefone ausente
  my $z = inscreve('ambos', nome => 'Beto', telefone => tel(4), email => mail(2));
  is $z->{contato_id}, $b->{contato_id}, 'reusa B pelo e-mail';
  is $dbh->selectrow_array('SELECT telefone FROM clean.contatos WHERE id = ?', {}, $b->{contato_id}),
    tel(4), 'telefone preenchido no contato sem telefone';

  # contato com e-mail diferente não é sobrescrito
  my $w = inscreve('ambos', nome => 'Ana', telefone => tel(1), email => mail(5));
  is $dbh->selectrow_array('SELECT email FROM clean.contatos WHERE id = ?', {}, $a->{contato_id}),
    mail(3), 'e-mail existente não sobrescrito';
};

subtest 'confirmação por contato: pendente -> parcial -> confirmado' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has && $has_config;
  limpa_config();
  cfg('telegram.enabled', 'true');
  cfg('telegram.token', '123456:ABCDEFGHIJ');
  cfg('telegram.bot_username', 'EduMapsEmailBot');
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;

  ok !$model->email_confirmacao_disponivel, 'e-mail indisponível sem config';
  my $r = inscreve('ambos', nome => 'Caio', telefone => tel(6), email => mail(6));
  my $c = $r->{confirmacao};
  is $c->{estado}, 'pendente', 'pendente';
  is $c->{contatos}, { telefone => { estado => 'pendente', via => undef },
                       email    => { estado => 'pendente', via => undef } }, 'contatos';
  is [map { $_->{canal} } @{ $c->{canais} }], ['telegram'], 'só telegram (e-mail indisponível)';

  cfg('email.enabled', 'true');
  cfg('email.smtp_host', 'smtp.exemplo.org');
  ok !$model->email_confirmacao_disponivel, 'sem from: indisponível';
  cfg('email.from', 'nao-responda@exemplo.org');
  ok $model->email_confirmacao_disponivel, 'disponível';
  is [map { $_->{canal} } @{ $model->canais_confirmacao($c->{ref}, $model->estado_ref($c->{ref})) }],
    [qw(telegram email)], 'telegram + email';

  # telefone confirmado: parcial, ref NÃO usada, canais só do e-mail
  my $k = $model->concluir(ref => $c->{ref}, via => 'telegram', telegram_chat_id => 99);
  is $k->{estado}, 'parcial', 'concluir telefone -> parcial';
  my $e = $model->estado_ref($c->{ref});
  is $e->{estado}, 'parcial', 'estado_ref parcial';
  is $e->{contatos}{telefone}, { estado => 'confirmado', via => 'telegram' }, 'telefone confirmado';
  ok !defined $dbh->selectrow_array(
    q{SELECT usada_em FROM clean.canal_confirmacao_refs WHERE id = ?}, {}, $e->{ref_id}),
    'ref não usada';
  is [map { $_->{canal} } @{ $model->canais_confirmacao($c->{ref}, $e) }], ['email'],
    'só o canal do e-mail';
  is $model->vincular_chat_telegram($c->{ref}, 123)->{reason}, 'confirmado',
    'telegram recusa ref com telefone confirmado';

  # e-mail confirmado: confirmado, ref usada, validado
  my $k2 = $model->concluir(ref => $c->{ref}, via => 'email');
  is $k2->{estado}, 'confirmado', 'concluir e-mail -> confirmado';
  is $k2->{ja_confirmado}, 0, 'e-mail não estava confirmado';
  my $m = $dbh->selectrow_hashref(
    'SELECT * FROM clean.canal_lista_membros WHERE id = ?', {}, $r->{membro_id});
  is $m->{email_confirmado_via}, 'email', 'email_confirmado_via';
  ok $m->{email_confirmado_em}, 'email_confirmado_em';
  is $m->{confirmado_via}, 'telegram', 'telefone preservado';
  ok $m->{validado}, 'membro validado';
  ok $dbh->selectrow_array(
    q{SELECT usada_em FROM clean.canal_confirmacao_refs WHERE id = ?}, {}, $e->{ref_id}),
    'ref usada';
  is $model->estado_ref($c->{ref})->{estado}, 'confirmado', 'estado_ref confirmado';
  is $model->concluir(ref => $c->{ref}, via => 'email')->{ja_confirmado}, 1, 'idempotente';

  # só e-mail: confirmar o e-mail fecha a ref; telegram não se aplica
  my $s = inscreve('ambos', nome => 'Duda', telefone => tel(7), email => mail(7));
  is $model->concluir(ref => $s->{confirmacao}{ref}, via => 'email')->{estado}, 'parcial',
    'e-mail primeiro -> parcial';

  my $le = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id,
                               nome => 'Email Exige', coleta => 'email', exige_confirmacao => 1);
  my $te = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $le->{id},
                                gestor_id => $gestor_id)->{token};
  my $o = $model->registrar_inscricao(token => $te, nome => 'Eva', email => mail(8),
                                      consentimento => 1);
  is $o->{confirmacao}{contatos}, { email => { estado => 'pendente', via => undef } },
    'só o contato e-mail';
  is [map { $_->{canal} } @{ $o->{confirmacao}{canais} }], ['email'], 'só o canal e-mail';
  is $model->vincular_chat_telegram($o->{confirmacao}{ref}, 124)->{reason}, 'not_found',
    'telegram: inscrição sem telefone';
  is $model->concluir(ref => $o->{confirmacao}{ref}, via => 'email')->{estado}, 'confirmado',
    'e-mail confirmado -> confirmado';
  is $model->registrar_inscricao(token => $te, nome => 'Eva', email => mail(8),
                                 consentimento => 1)->{confirmacao}{estado},
    'confirmado', 'reinscrição confirmada sem ref';

  is $model->concluir(ref => $c->{ref}, via => 'sms')->{reason}, 'via', 'via inválida';
};

subtest 'histórico: e-mail de confirmação sem o código' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has && $has_config;
  my $capt;
  my $mail = EduMaps::Channel::Email->new(
    config => { smtp_host => 'smtp.exemplo.org', from => 'nao-responda@exemplo.org' },
    schema => $model->schema,
    smtp_transport => sub ($cfg, $to, $from, $env) { $capt = $env; { ok => 1 } },
  );
  my $r = $mail->confirm_start(mail(9), cod_inep => $INEP, lista_nome => 'Lista X',
                               exclusao_info => 'Para remover seus dados: link.');
  ok $r->{ok}, 'enviado';
  my ($codigo) = $capt =~ /código de confirmação de e-mail é: (\d{6})/;
  ok $codigo, 'código no e-mail entregue';
  like $capt, qr/Lista X/, 'contexto da lista';
  like $capt, qr/Para remover seus dados/, 'orientação de exclusão';
  my $corpo = $dbh->selectrow_array(
    q{SELECT corpo FROM clean.canal_mensagens WHERE canal = 'email' AND destinatario = ?
      ORDER BY id DESC LIMIT 1}, {}, mail(9));
  ok $corpo, 'histórico gravado';
  unlike $corpo, qr/\Q$codigo\E/, 'histórico sem o código';
  like $corpo, qr/\*{6}/, 'código mascarado';
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'email' AND destinatario = ?},
           {}, mail(9));
  $dbh->do(q{DELETE FROM clean.canal_confirmacoes WHERE canal = 'email' AND endereco = ?},
           {}, mail(9));
};

done_testing;
