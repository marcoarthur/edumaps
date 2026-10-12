# t/04-api/canais/email.t
# E-mail e LGPD nas listas com QR (#214, onda 1 — contrato congelado), face
# pública:
#   GET  /api/canais/inscricao/:token   + campos/obrigatorios/consentimento
#   POST /api/canais/inscricao/:token   + email, consentimento_versao (409),
#                                        exclusao_url; 400 por coleta
#   GET  /api/canais/confirmacao/:ref   estado pendente|parcial|confirmado + contatos
#   POST /api/canais/confirmacao/:ref/email            202 · 404 · 409 · 429 · 502
#   POST /api/canais/confirmacao/:ref/email/verificar  200 · 400 · 404 · 410
#   GET  /api/canais/consentimento      200 {versao, texto, publicada_em}
# SMTP simulado (helper canais_smtp → coderef que captura o envelope).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my @enviados;
my $smtp_ok = 1;
$t->app->helper(canais_smtp => sub {
  sub ($cfg, $to, $from, $envelope) {
    return { ok => 0, error => 'SMTP: falha em data' } unless $smtp_ok;
    push @enviados, { to => $to, envelope => $envelope };
    return { ok => 1 };
  };
});

my $dbh        = $t->app->schema->storage->dbh;
my $has        = $dbh->selectrow_array("SELECT to_regclass('clean.consentimento_versoes')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model  = $t->app->model('Canal');
my $INEP   = 99440000 + ($$ % 999);
my $EMAIL  = sprintf 'gestor.email.api.%d@edumaps.test', $$;
my $MASTER = 'chave-mestra-de-teste-12345';
my $P      = sprintf '%04d', $$ % 10000;
my %tk;

sub tel ($n)  { return "1193${P}0$n" }
sub mail ($n) { return "insc$n.$P\@exemplo.org" }

sub limpa {
  return unless $has;
  my @m = map { mail($_) } 0 .. 9;
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'email'
             AND destinatario = ANY(?::text[])}, {}, \@m);
  $dbh->do(q{DELETE FROM clean.canal_confirmacoes WHERE canal = 'email'
             AND endereco = ANY(?::text[])}, {}, \@m);
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
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.inscricao.%'
             OR key LIKE 'canais.email.%' OR key LIKE 'canais.telegram.%'
             OR key LIKE 'canais.whatsapp.%'});
}
END { limpa(); limpa_config(); }

sub cfg ($k, $v) {
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put("canais.$k", $v, $EMAIL);
}
sub flag {
  cfg('inscricao.enabled', 'true');
  cfg('inscricao.rate_max', '1000');
  cfg('inscricao.public_base_url', 'https://edumaps.exemplo.org');
}
sub liga_email {
  cfg('email.enabled', 'true');
  cfg('email.smtp_host', 'smtp.exemplo.org');
  cfg('email.from', 'nao-responda@exemplo.org');
}
sub post_insc ($c, %b) {
  return $t->post_ok("/api/canais/inscricao/$tk{$c}",
    json => { consentimento => JSON::PP::true, %b });
}
sub ref_de ($c, %b) {
  return post_insc($c, %b)->status_is(201)->tx->res->json->{confirmacao}{ref};
}
sub envia ($ref) { return $t->post_ok("/api/canais/confirmacao/$ref/email") }
sub verifica ($ref, $codigo) {
  return $t->post_ok("/api/canais/confirmacao/$ref/email/verificar", json => { codigo => $codigo });
}
sub ultimo_codigo { ($enviados[-1]{envelope} // '') =~ /e-mail é: (\d{6})/; return $1 }

if ($has && $has_config) {
  limpa(); limpa_config();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola E-mail API');
  my ($gid) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor E-mail', $EMAIL);
  for my $c (qw(telefone email ambos qualquer)) {
    my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => "L $c",
                                coleta => $c, exige_confirmacao => ($c eq 'telefone' ? 0 : 1));
    $tk{$c} = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id},
                                   gestor_id => $gid)->{token};
  }
}

subtest 'GET público: campos, obrigatorios e consentimento por coleta' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag();
  my $vig = $model->consentimento_vigente;
  $t->get_ok("/api/canais/inscricao/$tk{telefone}")->status_is(200)
    ->json_is('/campos', [qw(nome telefone)])->json_is('/obrigatorios', [qw(nome telefone)])
    ->json_is('/consentimento/versao', $vig->{versao})
    ->json_is('/consentimento/texto', $vig->{texto});
  $t->get_ok("/api/canais/inscricao/$tk{email}")->status_is(200)
    ->json_is('/campos', [qw(nome email)])->json_is('/obrigatorios', [qw(nome email)]);
  $t->get_ok("/api/canais/inscricao/$tk{ambos}")->status_is(200)
    ->json_is('/campos', [qw(nome telefone email)])
    ->json_is('/obrigatorios', [qw(nome telefone email)]);
  $t->get_ok("/api/canais/inscricao/$tk{qualquer}")->status_is(200)
    ->json_is('/campos', [qw(nome telefone email)])->json_is('/obrigatorios', [qw(nome)]);

  $t->get_ok('/api/canais/consentimento')->status_is(200)
    ->json_is('/versao', $vig->{versao})->json_is('/texto', $vig->{texto})
    ->json_is('/publicada_em', $vig->{publicada_em});
};

subtest 'POST: 400 por coleta, 409 de versão, exclusao_url' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag();
  post_insc('email', nome => 'A')->status_is(400)->json_like('/error', qr/e-mail é obrigatório/);
  post_insc('email', nome => 'A', email => 'x@y')->status_is(400)->json_is('/error', 'e-mail inválido.');
  post_insc('ambos', nome => 'A', email => mail(0))->status_is(400)
    ->json_like('/error', qr/telefone é obrigatório/);
  post_insc('qualquer', nome => 'A')->status_is(400)->json_like('/error', qr/pelo menos um contato/);

  my $vig = $model->consentimento_vigente;
  post_insc('email', nome => 'A', email => mail(0), consentimento_versao => '0.1')
    ->status_is(409)->json_has('/error')
    ->json_is('/consentimento/versao', $vig->{versao})
    ->json_is('/consentimento/texto', $vig->{texto});

  my $r = post_insc('qualquer', nome => 'A', email => mail(0), consentimento_versao => $vig->{versao})
    ->status_is(201)->tx->res->json;
  like $r->{exclusao_url}, qr{^https://edumaps\.exemplo\.org/privacidade/exclusao/[0-9a-f]{32}$},
    'exclusao_url';
  is $r->{confirmacao}{contatos}, { email => { estado => 'pendente', via => undef } },
    'confirmação só do e-mail';
  is $r->{confirmacao}{canais}, [], 'e-mail indisponível -> sem canais';

  my $hp = post_insc('email', nome => 'Bot', email => mail(0), _hp => 'x')
    ->status_is(201)->tx->res->json;
  is $hp, { ok => 1 }, 'honeypot sem exclusao_url';
};

subtest 'confirmação por e-mail: 409, 202, 400, parcial, confirmado' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag();
  my $ref = ref_de('ambos', nome => 'Clara', telefone => tel(1), email => mail(1));
  envia($ref)->status_is(409, 'e-mail indisponível');

  liga_email();
  my $g = $t->get_ok("/api/canais/confirmacao/$ref")->status_is(200)->tx->res->json;
  is $g->{estado}, 'pendente', 'pendente';
  is $g->{canais}, [ { canal => 'email' } ], 'canal email (telegram/whatsapp desligados)';
  is $g->{contatos}, { telefone => { estado => 'pendente', via => undef },
                       email    => { estado => 'pendente', via => undef } }, 'contatos';

  verifica($ref, '123456')->status_is(410, 'sem pedido');
  @enviados = ();
  my $r = envia($ref)->status_is(202)->json_is('/enviado', 1)->tx->res->json;
  like $r->{expira_em}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'expira_em ISO';
  is [sort keys %$r], [qw(enviado expira_em)], 'sem código na resposta';
  is $enviados[-1]{to}, mail(1), 'enviado ao e-mail da inscrição';
  my $codigo = ultimo_codigo();
  like $codigo, qr/^\d{6}$/, 'código no e-mail';
  like $enviados[-1]{envelope}, qr/L ambos/, 'nome da lista no e-mail';
  like $enviados[-1]{envelope}, qr/Remover meus dados/, 'orientação de exclusão no e-mail';
  ok !$dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_mensagens
      WHERE destinatario = ? AND corpo LIKE ?}, {}, mail(1), "%$codigo%"),
    'código não gravado no histórico';

  verifica($ref, 'abc')->status_is(400);
  my $errado = $codigo eq '000000' ? '111111' : '000000';
  verifica($ref, $errado)->status_is(400)->json_is('/error', 'Código inválido.');
  my $ok = verifica($ref, $codigo)->status_is(200)->tx->res->json;
  is $ok->{estado}, 'parcial', 'e-mail confirmado, telefone pendente -> parcial';
  is $ok->{contatos}{email}, { estado => 'confirmado', via => 'email' }, 'e-mail confirmado';
  is $ok->{contatos}{telefone}{estado}, 'pendente', 'telefone pendente';

  $t->get_ok("/api/canais/confirmacao/$ref")->status_is(200)
    ->json_is('/estado', 'parcial')->json_is('/canais', []);
  envia($ref)->status_is(409, 'e-mail já confirmado');
  verifica($ref, '999999')->status_is(200, 'idempotente')->json_is('/estado', 'parcial');

  # telefone confirmado por outro caminho: ref fecha
  ok $model->concluir(ref => $ref, via => 'whatsapp')->{ok}, 'telefone confirmado';
  $t->get_ok("/api/canais/confirmacao/$ref")->status_is(200)
    ->json_is('/estado', 'confirmado')->json_is('/canais', [])
    ->json_is('/contatos/telefone', { estado => 'confirmado', via => 'whatsapp' });
  envia($ref)->status_is(404, 'ref confirmada não recebe código');
  verifica($ref, '999999')->status_is(200)->json_is('/estado', 'confirmado');

  # inscrição sem e-mail (qualquer, só telefone) -> 409
  my $sem = ref_de('qualquer', nome => 'Sem Mail', telefone => tel(2));
  envia($sem)->status_is(409, 'inscrição sem e-mail');

  envia('nao-e-ref')->status_is(404);
  envia('f' x 32)->status_is(404);
  verifica('f' x 32, '123456')->status_is(404);
};

subtest '410 expirado/tentativas; 429 limites; 502 SMTP' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag(); liga_email();

  my $ref = ref_de('email', nome => 'Duda', email => mail(3));
  envia($ref)->status_is(202);
  my $codigo = ultimo_codigo();
  my $errado = $codigo eq '000000' ? '111111' : '000000';
  verifica($ref, $errado)->status_is(400) for 1 .. 5;
  verifica($ref, $codigo)->status_is(410, 'tentativas excedidas');
  envia($ref)->status_is(202);
  $codigo = ultimo_codigo();
  $dbh->do(q{UPDATE clean.canal_confirmacoes SET expira_em = NOW() - interval '1 second'
             WHERE canal = 'email' AND endereco = ?}, {}, mail(3));
  verifica($ref, $codigo)->status_is(410, 'expirado');
  envia($ref)->status_is(202, 'terceiro envio');
  envia($ref)->status_is(429, 'quarto envio da ref');

  my $ref2 = ref_de('email', nome => 'Duda', email => mail(3));
  isnt $ref2, $ref, 'ref nova';
  envia($ref2)->status_is(429, 'limite por e-mail/hora');

  my $ref3 = ref_de('email', nome => 'Eli', email => mail(4));
  $smtp_ok = 0;
  envia($ref3)->status_is(502)->json_has('/error');
  $smtp_ok = 1;
  is $dbh->selectrow_array(q{SELECT status FROM clean.canal_mensagens
      WHERE canal = 'email' AND destinatario = ? ORDER BY id DESC LIMIT 1}, {}, mail(4)),
    'failed', 'falha registrada em canal_mensagens';
  my $ok = envia($ref3)->status_is(202, 'falha não consome o limite')->tx->res->json;
  my $v = verifica($ref3, ultimo_codigo())->status_is(200)->tx->res->json;
  is $v->{estado}, 'confirmado', 'lista só de e-mail: confirmado';
  is $v->{contatos}, { email => { estado => 'confirmado', via => 'email' } }, 'contatos';
};

subtest '404 com a feature desligada' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag(); liga_email();
  my $ref = ref_de('email', nome => 'Fil', email => mail(5));
  $dbh->do(q{DELETE FROM app_config.items WHERE key = 'canais.inscricao.enabled'});
  envia($ref)->status_is(404);
  verifica($ref, '123456')->status_is(404);
  $t->get_ok('/api/canais/consentimento')->status_is(200, 'consentimento é público');
};

done_testing;
