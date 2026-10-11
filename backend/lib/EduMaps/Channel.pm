package EduMaps::Channel;
use Mojo::Base -base, -signatures;
use utf8;

use Carp qw(croak);

# ============================================================================
# FÁBRICA DE CANAIS DE COMUNICAÇÃO
# ============================================================================
#
# Mapeia o nome do canal (email/whatsapp/telegram) para a sua implementação,
# carregando a classe sob demanda. Evita `if/elsif` espalhado pelo código:
# adicionar um canal novo é uma linha no %TYPES + a subclasse.

our %TYPES = (
  email    => 'EduMaps::Channel::Email',
  whatsapp => 'EduMaps::Channel::WhatsApp',
  telegram => 'EduMaps::Channel::Telegram',
);

sub types ($class) { return [sort keys %TYPES] }

sub is_valid_type ($class, $name) {
  return (defined $name && exists $TYPES{$name}) ? 1 : 0;
}

# Constrói um canal pelo nome. %args chegam ao construtor (config, schema, log,
# ua, history, confirmation...). O nome é imposto pela fábrica.
sub build ($class, $name, %args) {
  my $impl = $TYPES{$name}
    or croak "Canal desconhecido: '" . ($name // '') . "'";
  (my $file = "$impl.pm") =~ s{::}{/}g;
  eval { require $file; 1 }
    or croak "Falha ao carregar $impl: $@";
  return $impl->new(%args, name => $name);
}

# Constrói a partir de um hashref de config (saída de AppConfig->channel_config).
# `enabled` ausente assume habilitado; presente manda.
sub build_from_config ($class, $name, $config = {}, %args) {
  my $enabled = defined $config->{enabled} ? ($config->{enabled} ? 1 : 0) : 1;
  return $class->build($name, %args, config => $config, enabled => $enabled);
}

1;
