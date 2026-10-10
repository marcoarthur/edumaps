package EduMaps;
use Mojo::Base 'Mojolicious', -signatures;
use EduMaps::Schema;

# ABSTRACT: Plataforma de análise educacional geoespacial para municípios brasileiros

our $VERSION = '0.001';

has schema => sub { state $sch = EduMaps::Schema->go() };
has default_conf_file => './edu_maps.conf';

sub startup ($self) {
  # ------------------------------------------------------------
  # Config
  # ------------------------------------------------------------
  my $conf = $self->plugin(Config => {file => $ENV{EDUMAPS_CONF} || $self->default_conf_file });

  # ------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------
  $self->plugin("EduMaps::Plugin::Helpers");
  $self->plugin("EduMaps::Plugin::Analytics");

  # ------------------------------------------------------------
  # Plugins
  # ------------------------------------------------------------
  $self->plugin(Minion => {Pg => $conf->{db_url} });
  $self->plugin('Minion::Admin');
  $self->plugin('Status');

  # Observabilidade: Sentry (5xx + jobs Minion falhos). Sem `sentry.dsn` no
  # conf/ambiente o plugin é no-op (helper `sentry` inativo).
  $self->plugin('EduMaps::Plugin::Sentry');
  $self->plugin("EduMaps::Task::$_") for qw/Siope OSM Clustering Similarity SchoolEmbedding CityAnalytics GruposFolha Chat SchoolProfile/;
  # Session ANTES de Cache::SchoolSearch: o cache curto-circuita o
  # around_dispatch em HIT (não chama $next), então qualquer middleware
  # registrado depois dele perde os requests servidos do cache. A telemetria
  # precisa contar TODOS os requests /api/* (inclusive HITs de cache).
  $self->plugin("EduMaps::Middleware::$_") for qw/Session Cache::SchoolSearch Login/;

  # ------------------------------------------------------------
  # Handlers/Middlewares do EventBus
  # ------------------------------------------------------------
  $self->add_mw('SiopeTask');
  # EventLogger bufferizado: acumula eventos em memória e persiste em lote
  # (flush 30s/500 ou comando 'event_logger.flush'). Config via
  # $conf->{event_logger} (flush_interval_s, max_buffer).
  $self->add_mw('EventLogger', $conf->{event_logger} // {});
  $self->add_mw('EduMaps::Middleware::Bot');

  # Consome os labels system.bot.* sem o WARN do EventBus ("sem nenhum handler
  # registrado") — o envio real acontece no Middleware::Bot, na cadeia.
  $self->event_bus->on($_, sub { }) for map { "system.bot.$_" } qw(info warn error trace);

  # Telemetria (Middleware::Session + endpoint de eventos): eventos que só
  # têm o EventLogger na cadeia (persistência em lote) não precisam de
  # handler — só do no-op para silenciar o WARN a cada request.
  $self->event_bus->on($_, sub { }) for qw/session.request session.navigate session.search session.login session.logout session.api_error/;

  # ------------------------------------------------------------
  # Custom Validations
  # ------------------------------------------------------------
  $self->plugin("EduMaps::Plugin::CustomValidations");

  # ------------------------------------------------------------
  # API definitions
  # ------------------------------------------------------------
  push @{$self->routes->namespaces}, 'EduMaps::Controller';

  $self->plugin("EduMaps::Plugin::API::$_") for qw(City School Gestor Task Rank SchoolNetwork Cluster Pesquisa Chat Admin Session);

  $self->log->info("EduMaps inicializado com sucesso [v$VERSION].");
}

1;

__END__

=head1 NAME

EduMaps - Plataforma de análise educacional geoespacial

=head1 DESCRIPTION

EduMaps integra dados do INEP, OSM, SIOPE e IPEA para análise
de cobertura escolar e acessibilidade em municípios brasileiros.

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=cut
