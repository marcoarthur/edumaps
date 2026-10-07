use lib qw(t/lib lib);
use Mojo::Base -strict;
use Test::More;
use Mojo::Log;
use EventBus;

use_ok 'EduMaps::Middleware::Bot';

# --- Mocks --------------------------------------------------------------
# MockNotif: notifier injetado — regista chamadas (caminho síncrono: em prove
# não há loop rodando, então o Middleware::Bot usa notify()).
{ package MockNotif;
  our @CALLS = ();
  sub new { bless {}, $_[0] }
  sub notify { my ($self, $action, $text) = @_; push @CALLS, [$action, $text]; return 1 }
  sub notify_p {
    my ($self, $action, $text) = @_;
    push @CALLS, ["p:$action", $text];
    require Mojo::Promise;
    return Mojo::Promise->resolve(1);
  }
}

# MockApp: app mínimo — só o log (notifier é injetado, schema não é usado).
{ package MockApp;
  sub new { bless { log => Mojo::Log->new }, $_[0] }
  sub log { $_[0]{log} }
}

sub make_mw {
  my %args = @_;
  @MockNotif::CALLS = ();
  return EduMaps::Middleware::Bot->new(
    app      => MockApp->new,
    notifier => $args{notifier} // MockNotif->new,
  );
}

sub una_bus {
  my $mw = shift;
  my $bus = EventBus->new;
  $bus->use($mw->to_middleware);
  return $bus;
}

subtest 'encaminha severidades para o Notifier e a cadeia continua' => sub {
  my $mw  = make_mw;
  my $bus = una_bus($mw);
  my %handled;
  for my $type (qw/system.bot.info system.bot.warn system.bot.error system.bot.trace/) {
    $bus->on($type => sub { $handled{$type}++ });
  }

  $bus->emit('system.bot.info',  { text => 'Login realizado: a@b.c' });
  $bus->emit('system.bot.warn',  { text => 'Job lento' });
  $bus->emit('system.bot.error', { text => 'Falha crítica' });
  $bus->emit('system.bot.trace', { text => 'req /api/x 42ms' });

  is_deeply [map { $_->[0] } @MockNotif::CALLS],
    [qw/system_bot_info system_bot_warn system_bot_error system_bot_trace/],
    'severidade -> ação correta';
  is $MockNotif::CALLS[0][1], 'Login realizado: a@b.c', 'texto repassado';
  ok $handled{'system.bot.info'} && $handled{'system.bot.warn'}
    && $handled{'system.bot.error'} && $handled{'system.bot.trace'},
    '$next sempre chamado — handlers do tipo executaram';
};

subtest 'severidade fora do mapa é ignorada sem croak' => sub {
  my $mw  = make_mw;
  my $bus = una_bus($mw);
  my $warn;
  local $SIG{__WARN__} = sub { $warn = $_[0] };

  eval { $bus->emit('system.bot.nonsense', { text => 'x' }) };
  is $@, '', 'emit não morre';
  is scalar(@MockNotif::CALLS), 0, 'nada encaminhado';
};

subtest 'evento fora do label system.bot.* não é tocado' => sub {
  my $mw  = make_mw;
  my $bus = una_bus($mw);
  $bus->on('city.details.requested' => sub { });
  $bus->emit('city.details.requested', { codigo_ibge => '3550308' });
  is scalar(@MockNotif::CALLS), 0, 'nada encaminhado';
};

subtest 'texto vazio/ausente é ignorado' => sub {
  my $mw  = make_mw;
  my $bus = una_bus($mw);
  $bus->on('system.bot.info' => sub { });
  $bus->emit('system.bot.info', { text => '' });
  $bus->emit('system.bot.info', {});
  is scalar(@MockNotif::CALLS), 0, 'nada encaminhado';
};

subtest 'croak do Notifier não propaga (cadeia intacta)' => sub {
  my $quebrado = bless {}, 'MockNotifQuebrado';
  { package MockNotifQuebrado;
    our $DIED;
    sub new { bless {}, $_[0] }
    sub notify {
      my ($self, $action, $text) = @_;
      $MockNotifQuebrado::DIED = [$action, $text];
      die "Notifier quebrou internamente\n";
    }
  }
  my $mw  = EduMaps::Middleware::Bot->new(app => MockApp->new, notifier => $quebrado);
  my $bus = una_bus($mw);
  my $handled = 0;
  $bus->on('system.bot.info' => sub { $handled++ });

  eval { $bus->emit('system.bot.info', { text => 'x' }) };
  is $@, '', 'emit não morre com Notifier quebrado';
  is_deeply $MockNotifQuebrado::DIED, ['system_bot_info', 'x'], 'ação/texto chegaram ao Notifier';
  is $handled, 1, '$next chamado mesmo após falha do Notifier';
};

done_testing;