# t/04-api/canais/limite_ip_real.t
# Limitador das rotas públicas das listas com QR: IP real e contagem no banco.
# Antes: em memória (por processo) e por tx->remote_address — o IP do nginx,
# então todos os visitantes dividiam a contagem e o ip_anon era o mesmo para
# todas as inscrições. Test::Mojo conecta de 127.0.0.1 (proxy confiável por
# padrão), então o X-Real-IP simula visitantes diferentes atrás do nginx.
use lib qw(t/lib lib);
use Imports;
use ConfigSnapshot;
use Test::Mojo;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
ConfigSnapshot::guardar($t->app->schema->storage->dbh, q{%});   # config restaurada no fim
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.canal_listas')");
plan skip_all => 'escopo canais ausente em auth_falhas (migration nao aplicada)'
  unless ($dbh->selectrow_array(q{SELECT pg_get_constraintdef(oid) FROM pg_constraint
                                   WHERE conname = 'auth_falhas_escopo_check'}) // '') =~ /canais/;

my $INEP   = 99660000 + ($$ % 999);
my $EMAIL  = sprintf 'gestor.limite.%d@edumaps.test', $$;
my $model  = $t->app->model('Canal');
my $secret = $t->app->secrets->[0];
my ($gestor_id, @chaves);

sub limpa {
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

limpa();
$dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?) ON CONFLICT (codigo_inep) DO NOTHING',
  {}, $INEP, 'Escola do limitador');
($gestor_id) = $dbh->selectrow_array(
  'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
  {}, $INEP, 'Gestor Limite', $EMAIL);
$model->config_put('canais.inscricao.enabled', 'true', $EMAIL);
$model->config_put('canais.inscricao.public_base_url', 'http://edumaps.test', $EMAIL);
$model->config_put('canais.inscricao.rate_max', '2', $EMAIL);
$model->config_put('canais.inscricao.rate_window_seconds', '60', $EMAIL);

END {
  return unless $dbh;
  $dbh->do(q{DELETE FROM clean.auth_falhas WHERE escopo = 'canais' AND chave = ?}, {}, $_) for @chaves;
  limpa();
}

sub novo_token {
  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => "Lista $_[0]");
  return $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id)->{token};
}
sub inscreve {
  my ($token, $ip, $n) = @_;
  push @chaves, $model->auth_chave($secret, "$token|$ip");
  $t->post_ok("/api/canais/inscricao/$token", { 'X-Real-IP' => $ip }, json => {
    nome => "Pessoa $n", telefone => sprintf('119%08d', $$ * 10 + $n), consentimento => JSON::PP::true,
  });
}

subtest 'visitantes diferentes atrás do nginx têm contagens separadas' => sub {
  my $tk = novo_token('separadas');
  inscreve($tk, '203.0.113.1', 1)->status_is(201);
  inscreve($tk, '203.0.113.1', 2)->status_is(201);
  inscreve($tk, '203.0.113.1', 3)->status_is(429)->header_like('Retry-After', qr/^\d+$/);
  my $ra = $t->tx->res->headers->header('Retry-After');
  ok $ra > 0 && $ra <= 60, "Retry-After dentro da janela ($ra s)";

  # outro visitante no mesmo QR segue livre (antes: bloqueado junto)
  inscreve($tk, '203.0.113.2', 4)->status_is(201);
};

subtest 'X-Real-IP forjado de conexão não confiável é ignorado' => sub {
  local $t->app->config->{auth_limite}{proxies_confiaveis} = ['10.9.9.9/32'];
  my $tk = novo_token('forjado');
  push @chaves, $model->auth_chave($secret, "$tk|127.0.0.1");
  inscreve($tk, '198.51.100.1', 5)->status_is(201);
  inscreve($tk, '198.51.100.2', 6)->status_is(201);
  inscreve($tk, '198.51.100.3', 7)->status_is(429, 'IPs forjados contam todos no IP da conexão');
};

subtest 'contagem no banco: vale para outro processo' => sub {
  my $tk = novo_token('processo');
  inscreve($tk, '203.0.113.9', 8)->status_is(201);
  inscreve($tk, '203.0.113.9', 9)->status_is(201);
  # modelo novo = outro worker, sem memória compartilhada
  my $outro = EduMaps::Model::Canal->new(schema => $model->schema);
  my $r = $outro->rate_limit_check(token => $tk, ip => '203.0.113.9', secret => $secret);
  is $r->{ok}, 0, 'outro processo vê a contagem';
  ok $r->{retry_after} > 0, 'e informa a espera';
};

subtest 'ip_anon das inscrições usa o IP real' => sub {
  my $tk = novo_token('ip_anon');
  inscreve($tk, '203.0.113.20', 10)->status_is(201);
  inscreve($tk, '203.0.113.21', 11)->status_is(201);
  my $anon = $dbh->selectcol_arrayref(q{
    SELECT i.ip_anon FROM clean.canal_inscricoes i
      JOIN clean.canal_qrcodes q ON q.id = i.qrcode_id WHERE q.token = ?}, {}, $tk);
  is scalar(@$anon), 2, 'duas inscrições';
  isnt $anon->[0], $anon->[1], 'IPs diferentes → ip_anon diferentes';
  unlike join(',', @$anon), qr/203\.0\.113/, 'nunca o IP puro';
};

subtest 'tabela não guarda token nem IP em claro' => sub {
  my $claro = $dbh->selectrow_array(
    q{SELECT count(*) FROM clean.auth_falhas WHERE escopo = 'canais' AND chave !~ '^[0-9a-f]{64}$'});
  is $claro, 0, 'só HMAC';
};

done_testing;
