# t/04-api/canais/whatsapp.t
# Confirmação de posse pelo WhatsApp (#212, onda 2 — contrato congelado):
#   POST /api/canais/confirmacao/:ref/whatsapp            202 · 404 · 409 · 429 (· 502)
#   POST /api/canais/confirmacao/:ref/whatsapp/verificar  200 · 400 · 404 · 410 · 429
# WhatsApp Cloud mockado (helper canais_ua → FakeUA, sem rede).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use FakeUA;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $ua = FakeUA->new(responder => sub { (200, { messages => [ { id => 'wamid.1' } ] }) });
$t->app->helper(canais_ua => sub { $ua });

my $dbh        = $t->app->schema->storage->dbh;
my $has        = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacao_refs')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model  = $t->app->model('Canal');
my $INEP   = 99880000 + ($$ % 999);
my $EMAIL  = sprintf 'gestor.whatsapp.api.%d@edumaps.test', $$;
my $MASTER = 'chave-mestra-de-teste-12345';
my $P      = sprintf '%04d', $$ % 10000;   # sufixo dos telefones do teste
my $tk;

sub tel ($n) { return "1197${P}00$n" }     # 11 dígitos
sub tel_wa ($n) { return '55' . tel($n) }

sub limpa {
  return unless $has;
  my @t = map { tel_wa($_) } 0 .. 9;
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'whatsapp'
             AND destinatario = ANY(?::text[])}, {}, \@t);
  $dbh->do(q{DELETE FROM clean.canal_confirmacoes WHERE canal = 'whatsapp'
             AND endereco = ANY(?::text[])}, {}, \@t);
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
             OR key LIKE 'canais.whatsapp.%' OR key LIKE 'canais.telegram.%'});
}
END { limpa(); limpa_config(); }

sub flag {
  $model->config_put('canais.inscricao.enabled', 'true', $EMAIL);
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
}
sub liga_whatsapp {
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put('canais.whatsapp.enabled', 'true', $EMAIL);
  $model->config_put('canais.whatsapp.provider', 'cloud', $EMAIL);
  $model->config_put('canais.whatsapp.token', 'EAAG-token-teste', $EMAIL);
  $model->config_put('canais.whatsapp.phone_number_id', '123456789012345', $EMAIL);
  $model->config_put('canais.whatsapp.template_confirmacao', 'edumaps_codigo', $EMAIL);
}
sub ref_de ($telefone) {
  my $r = $t->post_ok("/api/canais/inscricao/$tk", json => {
    nome => 'Pessoa', telefone => $telefone, consentimento => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  return $r->{confirmacao}{ref};
}
sub envia ($ref)            { return $t->post_ok("/api/canais/confirmacao/$ref/whatsapp") }
sub verifica ($ref, $codigo) {
  return $t->post_ok("/api/canais/confirmacao/$ref/whatsapp/verificar", json => { codigo => $codigo });
}
sub ultimo_codigo { return $ua->last_call->{json}{template}{components}[0]{parameters}[0]{text} }

if ($has && $has_config) {
  limpa(); limpa_config();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola WhatsApp API');
  my ($gid) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor WhatsApp', $EMAIL);
  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid,
                              nome => 'Exige', exige_confirmacao => 1);
  $tk = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gid)->{token};
}

subtest '404: feature desligada, ref mal formada ou inexistente' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag();
  my $ref = ref_de(tel(0));
  $dbh->do(q{DELETE FROM app_config.items WHERE key = 'canais.inscricao.enabled'});
  envia($ref)->status_is(404);
  verifica($ref, '123456')->status_is(404);
  flag();
  envia('nao-e-ref')->status_is(404)->json_is('/error', 'Confirmação não encontrada.');
  envia('f' x 32)->status_is(404);
  verifica('f' x 32, '123456')->status_is(404);
};

subtest '409: WhatsApp indisponível (sem template)' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag();
  my $ref = ref_de(tel(1));
  envia($ref)->status_is(409)->json_has('/error');
};

subtest '202 envio por template + verificar 400/200; idempotente' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag(); liga_whatsapp();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  my $ref = ref_de(tel(2));
  $ua->clear;
  my $r = envia($ref)->status_is(202)->json_is('/enviado', 1)->tx->res->json;
  like $r->{expira_em}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'expira_em ISO';
  is [sort keys %$r], [qw(enviado expira_em)], 'sem código na resposta';
  my $c = $ua->last_call->{json};
  is $c->{type}, 'template', 'template de autenticação';
  is $c->{to}, tel_wa(2), 'telefone com 55';
  is $c->{template}{name}, 'edumaps_codigo', 'nome do template';
  my $codigo = ultimo_codigo();
  like $codigo, qr/^\d{6}$/, 'código de 6 dígitos';
  ok !$dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_mensagens
      WHERE destinatario = ? AND corpo LIKE ?}, {}, tel_wa(2), "%$codigo%"),
    'código não gravado no histórico';
  is $dbh->selectrow_array(q{SELECT envios_whatsapp FROM clean.canal_confirmacao_refs
      WHERE ref_hash = encode(digest(?, 'sha256'), 'hex')}, {}, $ref), 1, 'envios_whatsapp=1';

  verifica($ref, 'abc')->status_is(400);
  my $errado = $codigo eq '000000' ? '111111' : '000000';
  verifica($ref, $errado)->status_is(400)->json_is('/error', 'Código inválido.');
  verifica($ref, $codigo)->status_is(200)->json_is('/estado', 'confirmado');
  my $m = $dbh->selectrow_hashref(q{SELECT m.* FROM clean.canal_lista_membros m
      JOIN clean.canal_confirmacao_refs r ON r.membro_id = m.id
      WHERE r.ref_hash = encode(digest(?, 'sha256'), 'hex')}, {}, $ref);
  is $m->{confirmado_via}, 'whatsapp', 'confirmado via whatsapp';
  verifica($ref, '999999')->status_is(200)->json_is('/estado', 'confirmado');
  envia($ref)->status_is(404, 'ref confirmada não recebe código');
};

subtest '410: tentativas excedidas e código expirado' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag(); liga_whatsapp();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  my $ref = ref_de(tel(3));
  verifica($ref, '123456')->status_is(410, 'sem pedido');
  envia($ref)->status_is(202);
  my $codigo = ultimo_codigo();
  my $errado = $codigo eq '000000' ? '111111' : '000000';
  verifica($ref, $errado)->status_is(400) for 1 .. 5;
  verifica($ref, $codigo)->status_is(410, 'tentativas excedidas');

  envia($ref)->status_is(202);
  $codigo = ultimo_codigo();
  $dbh->do(q{UPDATE clean.canal_confirmacoes SET expira_em = NOW() - interval '1 second'
             WHERE canal = 'whatsapp' AND endereco = ?}, {}, tel_wa(3));
  verifica($ref, $codigo)->status_is(410, 'expirado');
};

subtest '429: 3 envios por ref e por telefone/hora; 502 do provedor' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag(); liga_whatsapp();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  my $ref = ref_de(tel(4));
  envia($ref)->status_is(202) for 1 .. 3;
  envia($ref)->status_is(429, 'quarto envio da ref');

  my $ref2 = ref_de(tel(4));   # reinscrição: ref nova, mesmo telefone
  isnt $ref2, $ref, 'ref nova';
  envia($ref2)->status_is(429, 'limite por telefone/hora');

  my $ref3 = ref_de(tel(5));
  my $orig = $ua->responder;
  $ua->responder(sub { (500, { error => { message => 'boom' } }) });
  envia($ref3)->status_is(502)->json_has('/error');
  $ua->responder($orig);
  is $dbh->selectrow_array(q{SELECT status FROM clean.canal_mensagens
      WHERE canal = 'whatsapp' AND destinatario = ? ORDER BY id DESC LIMIT 1}, {}, tel_wa(5)),
    'failed', 'falha registrada em canal_mensagens';
  envia($ref3)->status_is(202, 'falha não consome o limite');
};

subtest '429: rate limit por IP' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  flag();
  my $ref = ref_de(tel(6));
  $model->config_put('canais.inscricao.rate_max', '2', $EMAIL);
  $model->config_put('canais.inscricao.rate_window_seconds', '3600', $EMAIL);
  my @st = map { verifica($ref, 'x')->tx->res->code } 1 .. 3;
  is \@st, [400, 400, 429], 'terceira excede';
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
};

done_testing;
