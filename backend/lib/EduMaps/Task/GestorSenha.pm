package EduMaps::Task::GestorSenha;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use EduMaps::Channel::Email;
use EduMaps::Util::MinionFila qw(minion_fila);
# carregado antes de citar VALIDADE_MINUTOS (senão o Role::Tiny acha o pacote
# já criado e não o carrega como papel)
use EduMaps::Roles::Business::Pesquisa::SenhaRedefinicao ();

# ============================================================================
# E-MAIL DE REDEFINIÇÃO DE SENHA DO GESTOR (#336)
# ============================================================================
#
# Task Minion `gestor_senha_email [{gestor_id}]`. O pedido (API) só enfileira:
# assim a resposta leva o mesmo tempo exista a conta ou não, e o envio SMTP não
# prende a requisição.
#
# O TOKEN NASCE AQUI, dentro do job: os argumentos do job ficam gravados no
# banco (minion_jobs), e o token em claro não pode ir para lá. O banco guarda
# só o hash (clean.senha_redefinicoes); o histórico do canal grava o corpo com
# o token mascarado.

our $TASK = 'gestor_senha_email';

sub register ($self, $app, @args) {
  $app->minion->add_task($TASK => \&_run);
  # Fila configurável (minion_fila, padrão `default`): os testes usam uma
  # fila própria para o worker de verdade não pegar os jobs deles.
  $app->helper(gestor_senha_enfileirar => sub ($c, $gestor_id) {
    $c->app->minion->enqueue($TASK => [{ gestor_id => $gestor_id + 0 }] => {
      attempts => 1, queue => minion_fila($c->app, $TASK),
    });
  });
}

sub _run ($job, $args = {}) {
  my $app = $job->app;
  my $id  = ref $args eq 'HASH' ? $args->{gestor_id} : undef;
  return $job->finish({ parado => 'sem_gestor' }) unless defined $id && $id =~ /^\d+\z/;

  my $r = eval { enviar($app, $id) } // { ok => 0, error => ($@ || 'falha desconhecida') };
  # Log sem e-mail nem token.
  $app->log->warn("gestor_senha_email: falha no envio (gestor $id): $r->{error}") unless $r->{ok};
  return $job->finish({ ok => $r->{ok} ? 1 : 0, ($r->{ok} ? () : (erro => "$r->{error}")) });
}

# Gera o token e envia. Exposto para teste (sem worker).
sub enviar ($app, $gestor_id) {
  my $pesq   = $app->model('Pesquisa');
  my $gestor = $pesq->_row('SELECT id, nome, email FROM clean.gestores WHERE id = ?', $gestor_id + 0)
    or return { ok => 0, error => 'gestor inexistente' };

  my $cfg  = $app->model('Canal')->email_config;
  my $base = $cfg->{public_base_url} // '';
  $base =~ s{/+$}{};
  return { ok => 0, error => 'e-mail ou URL pública não configurados' }
    unless $cfg->{enabled} && $cfg->{smtp_host} && $cfg->{from} && $base =~ m{^https?://};

  my $token = $pesq->redefinicao_criar($gestor->{id});
  my $link  = "$base/gestor/redefinir-senha#$token";
  my $corpo = corpo($gestor->{nome}, $link);

  my $mail = EduMaps::Channel::Email->new(
    config         => $cfg,
    enabled        => 1,
    schema         => $pesq->schema,
    log            => $app->log,
    smtp_transport => $app->build_controller->canais_smtp,
  );
  return $mail->send_message({
    to              => $gestor->{email},
    operacao        => 'alerta',
    assunto         => 'Redefinição de senha do EduMaps',
    corpo           => $corpo,
    corpo_historico => ($corpo =~ s/\Q$token\E/******/gr),
  });
}

sub corpo ($nome, $link) {
  my $min = EduMaps::Roles::Business::Pesquisa::SenhaRedefinicao::VALIDADE_MINUTOS();
  return join "\n",
    "Olá, $nome.",
    '',
    'Recebemos um pedido para redefinir a senha da sua conta de gestor no EduMaps.',
    'Para criar uma senha nova, abra o link abaixo:',
    '',
    $link,
    '',
    "O link vale por $min minutos e só pode ser usado uma vez. Ao trocar a senha,",
    'você sai de todos os aparelhos em que estava conectado.',
    '',
    'Se não foi você que pediu, ignore esta mensagem: sua senha continua a mesma.',
    '',
    '— EduMaps';
}

1;
