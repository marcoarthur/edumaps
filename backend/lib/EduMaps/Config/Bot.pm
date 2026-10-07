package EduMaps::Config::Bot;
use Mojo::Base -base, -signatures;

# Configuração isolada do Bot (separada da config geral do EduMaps)
has telegram_token => '';
has telegram_chat_id => '';
has telegram_enabled => 0;
has allowed_actions => sub { [] }; # whitelist

sub is_action_allowed ($self, $action) {
  return 0 unless defined $action && length $action;
  my $list = $self->allowed_actions // [];
  return 0 unless @$list;
  return scalar(grep { $_ eq $action } @$list) ? 1 : 0;
}

1;
