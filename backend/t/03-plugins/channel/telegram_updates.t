# t/03-plugins/channel/telegram_updates.t
# Bot público do Telegram (#212, onda 2): EduMaps::Channel::Telegram::Updates.
# /start válido/inválido/usado, contato próprio (igual → confirmado; divergente
# → conflito), contato de terceiro, mensagem qualquer, tolerância ao 55,
# reply_markup no payload e registro em canal_mensagens. Sem rede (FakeUA).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use FakeUA;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::Telegram::Updates';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh   = $t->app->schema->storage->dbh;
my $has   = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacao_refs')");
my $model = $t->app->model('Canal');

my $INEP  = 99770000 + ($$ % 1000);
my $EMAIL = sprintf 'gestor.tg.updates.%d@edumaps.test', $$;
my ($token, @chats);

sub limpa {
  return unless $has;
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'telegram'
             AND destinatario = ANY(?::text[])}, {}, [map {"$_"} @chats]) if @chats;
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
END { limpa() }

my $ua = FakeUA->new;
my $up = EduMaps::Channel::Telegram::Updates->new(
  model => $model, config => { token => '111:TOKEN-PUBLICO' }, ua => $ua,
  log => Mojo::Log->new(level => 'fatal'));

sub inscreve ($nome, $tel) {
  my $r = $model->registrar_inscricao(token => $token, nome => $nome,
    telefone => $tel, consentimento => 1);
  return $r;
}

my $UPD = 1000;
sub msg ($chat, %m) {
  push @chats, $chat;
  return { update_id => $UPD++, message => {
    message_id => 1, chat => { id => $chat, type => 'private' },
    from => { id => $chat }, %m } };
}

sub membro ($id) {
  return $dbh->selectrow_hashref(
    'SELECT * FROM clean.canal_lista_membros WHERE id = ?', {}, $id);
}

subtest 'unidades: telefone canônico e teclados' => sub {
  ok $up->telefones_conferem('+55 11 94444-0001', '11944440001'), 'com 55 x sem 55';
  ok $up->telefones_conferem('11944440001', '5511944440001'), 'sem 55 x com 55';
  ok $up->telefones_conferem('5511944440001', '5511944440001'), 'iguais';
  ok !$up->telefones_conferem('5511944440002', '11944440001'), 'diferentes';
  ok !$up->telefones_conferem('', ''), 'vazio nunca confere';
  is $up->teclado_contato->{keyboard}[0][0]{text}, 'Compartilhar meu número', 'botão';
};

subtest 'setup' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  limpa();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola Bot');
  my ($gid) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Bot', $EMAIL);
  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid,
                              nome => 'Exige', exige_confirmacao => 1);
  $token = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id},
                                gestor_id => $gid)->{token};
  ok $token, 'token';
};

subtest '/start válido → teclado request_contact; contato próprio igual → confirmado' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  my $chat = 7000000000 + ($$ % 1000);
  my $r = inscreve('Ana', '(11) 94444-0001');
  my $ref = $r->{confirmacao}{ref};

  $ua->clear;
  is $up->handle(msg($chat, text => "/start $ref"))->{acao}, 'start_ok', 'start_ok';
  my $c = $ua->last_call;
  is $c->{method}, 'sendMessage', 'sendMessage';
  like $c->{url}, qr{/bot111:TOKEN-PUBLICO/sendMessage$}, 'token do bot PÚBLICO';
  is $c->{json}{chat_id}, "$chat", 'chat_id';
  is $c->{json}{reply_markup}, {
    keyboard => [[ { text => 'Compartilhar meu número', request_contact => 1 } ]],
    one_time_keyboard => 1, resize_keyboard => 1,
  }, 'reply_markup request_contact one_time';
  is $dbh->selectrow_array(q{SELECT telegram_chat_pendente FROM clean.canal_confirmacao_refs
       WHERE ref_hash = encode(digest(?, 'sha256'), 'hex')}, {}, $ref), $chat,
    'telegram_chat_pendente gravado';

  # contato próprio, com 55 (a inscrição foi sem 55)
  $ua->clear;
  my $h = $up->handle(msg($chat, contact => {
    phone_number => '+5511944440001', user_id => $chat, first_name => 'Ana' }));
  is $h->{acao}, 'confirmado', 'confirmado';
  my $m = membro($r->{membro_id});
  ok $m->{confirmado_em}, 'confirmado_em';
  is $m->{confirmado_via}, 'telegram', 'via telegram';
  is $m->{telegram_chat_id}, $chat, 'telegram_chat_id gravado';
  is $ua->last_call->{json}{reply_markup}, { remove_keyboard => 1 }, 'remove o teclado';
  is $model->estado_ref($ref)->{estado}, 'confirmado', 'ref usada';

  my $hist = $dbh->selectall_arrayref(
    q{SELECT operacao, status FROM clean.canal_mensagens
      WHERE canal = 'telegram' AND destinatario = ? ORDER BY id}, { Slice => {} }, "$chat");
  is scalar(@$hist), 2, 'dois envios registrados';
  is [map { "$_->{operacao}/$_->{status}" } @$hist], ['confirmacao/sent', 'confirmacao/sent'],
    'operação confirmacao, status sent';

  # /start com ref já usada → genérica, sem teclado
  $ua->clear;
  is $up->handle(msg($chat, text => "/start $ref"))->{acao}, 'start_invalido', 'ref usada';
  ok !exists $ua->last_call->{json}{reply_markup}, 'sem teclado';
};

subtest 'contato divergente → conflito, membro pendente' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  my $chat = 7100000000 + ($$ % 1000);
  my $r = inscreve('Bia', '11944440002');
  $up->handle(msg($chat, text => "/start $r->{confirmacao}{ref}"));
  $ua->clear;
  my $h = $up->handle(msg($chat, contact => { phone_number => '5511900000000', user_id => $chat }));
  is $h->{acao}, 'conflito', 'conflito';
  ok !membro($r->{membro_id})->{confirmado_em}, 'membro continua pendente';
  ok $dbh->selectrow_array('SELECT conflito FROM clean.canal_inscricoes WHERE id = ?', {},
    $r->{inscricao_id}), 'conflito=true na inscrição';
  like $ua->last_call->{json}{text}, qr/não confere/, 'resposta "não confere"';
  is $model->estado_ref($r->{confirmacao}{ref})->{estado}, 'pendente', 'ref segue pendente';
};

subtest 'contato de terceiro → recusa' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  my $chat = 7200000000 + ($$ % 1000);
  my $r = inscreve('Caio', '11944440003');
  $up->handle(msg($chat, text => "/start $r->{confirmacao}{ref}"));
  is $up->handle(msg($chat, contact => { phone_number => '5511944440003', user_id => 42 }))->{acao},
    'terceiro', 'user_id diferente';
  is $up->handle(msg($chat, contact => { phone_number => '5511944440003' }))->{acao},
    'terceiro', 'sem user_id';
  ok !membro($r->{membro_id})->{confirmado_em}, 'não confirmou';
  ok !$dbh->selectrow_array('SELECT conflito FROM clean.canal_inscricoes WHERE id = ?', {},
    $r->{inscricao_id}), 'sem conflito';
};

subtest '/start inválido, contato sem ref, mensagem qualquer, grupo, rate limit' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  my $chat = 7300000000 + ($$ % 1000);
  $ua->clear;
  is $up->handle(msg($chat, text => '/start'))->{acao}, 'start_invalido', 'sem ref';
  is $up->handle(msg($chat, text => '/start ' . ('f' x 32)))->{acao}, 'start_invalido', 'inexistente';
  is $up->handle(msg($chat, text => '/start xyz'))->{acao}, 'start_invalido', 'formato';
  is $up->handle(msg($chat, contact => { phone_number => '1', user_id => $chat }))->{acao},
    'sem_ref', 'contato sem ref pendente';
  is $up->handle(msg($chat, text => 'oi'))->{acao}, 'padrao', 'mensagem qualquer';
  like $ua->last_call->{json}{text}, qr/apenas para confirmar/, 'resposta fixa';
  is scalar(@{ $ua->calls }), 5, 'uma resposta por mensagem';

  $ua->clear;
  my $g = msg(-100123, text => 'oi');
  $g->{message}{chat}{type} = 'group';
  is $up->handle($g)->{acao}, 'ignorado', 'grupo ignorado';
  is $up->handle({ update_id => 1, edited_message => {} })->{acao}, 'ignorado', 'sem message';
  is scalar(@{ $ua->calls }), 0, 'sem resposta';

  local $EduMaps::Channel::Telegram::Updates::RATE_MAX = 3;
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  my @a = map { $up->handle(msg($chat, text => 'x'))->{acao} } 1 .. 4;
  is $a[3], 'rate_limited', 'quarta excede';
};

subtest 'falha do Telegram não propaga e fica registrada' => sub {
  plan skip_all => 'migration nao aplicada' unless $has;
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  my $chat = 7400000000 + ($$ % 1000);
  my $bad = FakeUA->new(responder => sub { (403, { ok => 0, description => 'Forbidden: bot was blocked' }) });
  my $u2 = EduMaps::Channel::Telegram::Updates->new(model => $model,
    config => { token => '111:T' }, ua => $bad, log => Mojo::Log->new(level => 'fatal'));
  is $u2->handle(msg($chat, text => 'oi'))->{acao}, 'padrao', 'trata mesmo assim';
  is $dbh->selectrow_array(q{SELECT status FROM clean.canal_mensagens
       WHERE canal = 'telegram' AND destinatario = ? ORDER BY id DESC LIMIT 1}, {}, "$chat"),
    'failed', 'falha registrada';
};

done_testing;
