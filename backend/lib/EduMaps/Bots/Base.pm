package EduMaps::Bots::Base;
use Mojo::Base -base, -signatures;

# Classe base para bots (Telegram, outros canais)
# Preparada para envio e recebimento; fase 1: apenas envio

has enabled => 0;
has name    => 'base';
has config  => sub { {} };
has log     => sub { Mojo::Log->new };

sub can_send { return shift->enabled ? 1 : 0 }

sub can_receive { return 0 } # fase 1: desativado

1;
