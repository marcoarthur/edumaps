package EduMaps::Bots::Policy::Actions;
use Mojo::Base -base, -signatures;

# Classificação de ações permitidas para envio (fase 1) — alimenta o
# multiselect do Painel de Configuração e a validação is_valid.
my @ACTIONS = (
  'system_alert',
  'system_info',
  'system_bot_info',    # severidade info do label system.bot.* (issue #188)
  'system_bot_warn',
  'system_bot_error',
  'system_bot_trace',
  'ingest_stall',
  'ingest_done',
  'ingest_failed',
  'user_notification',
  'admin_notification',
);

sub available ($class) {
  return [@ACTIONS];
}

sub is_valid ($class, $action) {
  return scalar(grep { $_ eq $action } @ACTIONS) ? 1 : 0;
}

1;
