package EduMaps::Bots::Policy::Actions;
use Mojo::Base -base, -signatures;

# Classificação de ações permitidas para envio (fase 1)
my @ACTIONS = (
  'system_alert',
  'system_info',
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
