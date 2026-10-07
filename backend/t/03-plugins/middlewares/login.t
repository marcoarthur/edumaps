use lib qw(t/lib lib);
use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojolicious;

use_ok 'EduMaps::Middleware::Login';

# --- FakeBus: captura os emits sem depender do EventBus/app real ----------
{ package FakeBus;
  our @EMITS = ();
  sub new { bless {}, $_[0] }
  sub emit { my ($self, $type, $payload) = @_; push @EMITS, [$type, $payload] }
}

sub build_app {
  my $bus = FakeBus->new;
  my $app = Mojolicious->new;
  $app->helper(event_bus => sub { my ($c) = @_; $bus });

  $app->plugin('EduMaps::Middleware::Login');

  $app->routes->post('/api/gestor/login')->to(
    cb => sub {
      my ($c) = @_;
      my $body = $c->req->json || {};
      my $ok = ($body->{email} // '') eq 'gestor@escola.edu.br'
            && ($body->{senha} // '') eq 'senha123';
      return $c->render(json => { error => 'E-mail ou senha inválidos' }, status => 401) unless $ok;
      $c->render(json => { ok => 1 });
    }
  )->name('gestor_login');

  $app->routes->get('/api/health')->to(cb => sub { my ($c) = @_; $c->render(json => { ok => 1 }) })->name('health');
  return ($app, $bus);
}

subtest 'login 200 emite system.bot.info com o email' => sub {
  my ($app, $bus) = build_app;
  my $t = Test::Mojo->new($app);
  @FakeBus::EMITS = ();

  $t->post_ok('/api/gestor/login' => json => { email => 'gestor@escola.edu.br', senha => 'senha123' })
    ->status_is(200);

  is scalar(@FakeBus::EMITS), 1, 'login 200 emite exatamente 1 evento';
  is $FakeBus::EMITS[0][0], 'system.bot.info', 'label agregador correto';
  like $FakeBus::EMITS[0][1]{text}, qr/gestor\@escola\.edu\.br/, 'email presente no texto';
};

subtest 'login 401 (credenciais inválidas) não emite' => sub {
  my ($app, $bus) = build_app;
  my $t = Test::Mojo->new($app);
  @FakeBus::EMITS = ();

  $t->post_ok('/api/gestor/login' => json => { email => 'gestor@escola.edu.br', senha => 'errada' })
    ->status_is(401);

  is scalar(@FakeBus::EMITS), 0, 'nenhum evento emitido';
};

subtest 'rota que não é de login não emite' => sub {
  my ($app, $bus) = build_app;
  my $t = Test::Mojo->new($app);
  @FakeBus::EMITS = ();

  $t->get_ok('/api/health')->status_is(200);
  is scalar(@FakeBus::EMITS), 0, 'nenhum evento emitido';
};

done_testing;