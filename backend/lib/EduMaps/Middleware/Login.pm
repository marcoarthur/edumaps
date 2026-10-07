package EduMaps::Middleware::Login;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# ============================================================================
# MIDDLEWARE DE LOGIN -> system.bot.info (issue #188)
# ============================================================================
#
# Dispara `system.bot.info` quando houver uma AÇÃO DE LOGIN com sucesso
# (rota `gestor_login` = POST /api/gestor/login respondendo 200 — gestor ou
# admin de instalação). O envio em si é assíncrono a jusante
# (EduMaps::Middleware::Bot): aqui só emitimos no EventBus — o request de
# login NÃO espera o processo do Bot.
#
# Nunca loga nem envia credenciais: apenas o e-mail vai no texto da
# mensagem. Login 401 e rotas que não são de login não emitem.
# ============================================================================

has login_route => 'gestor_login';

sub register ($self, $app, $conf = {}) {
  $self->login_route($conf->{login_route}) if $conf->{login_route};

  $app->hook(
    around_dispatch => sub ($next, $c) {
      # E-mail capturado ANTES do dispatch (corpo da requisição ainda intacto).
      my $body  = $c->req->json || {};
      my $email = $body->{email} // '';

      $next->();

      return unless $c->res->code == 200;
      return unless $self->_is_login_route($c);

      $app->event_bus->emit('system.bot.info', { text => "Login realizado: $email" });
      return;
    }
  );
}

sub _is_login_route ($self, $c) {
  my $endpoint = $c->match->endpoint;
  return 0 unless $endpoint;
  return ($endpoint->name // '') eq $self->login_route ? 1 : 0;
}

1;

__END__

=head1 NAME

EduMaps::Middleware::Login - emite system.bot.info em login de gestor bem-sucedido

=head1 SYNOPSIS

  # EduMaps.pm
  $self->plugin('EduMaps::Middleware::Login');

=head1 DESCRIPTION

Plugin Mojolicious que observa o dispatch: quando a rota `gestor_login`
(POST /api/gestor/login) responde 200, emite `system.bot.info` com o e-mail no
texto. O envio da mensagem é assíncrono — o request de login não espera o bot.

=cut