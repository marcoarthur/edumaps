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

  # ------------------------------------------------------------
  # Plugins
  # ------------------------------------------------------------
  $self->plugin(Minion => {Pg => $conf->{db_url} });
  $self->plugin('Minion::Admin');
  $self->plugin('Status');
  $self->plugin("EduMaps::Task::$_") for qw/Siope OSM Clustering Similarity/;
  $self->plugin("EduMaps::Middleware::$_") for qw/Cache::SchoolSearch/;

  # ------------------------------------------------------------
  # Handlers/Middlewares do EventBus
  # ------------------------------------------------------------
  $self->add_mw($_) for qw/SiopeTask EventLogger/;

  # ------------------------------------------------------------
  # Custom Validations
  # ------------------------------------------------------------
  $self->plugin("EduMaps::Plugin::CustomValidations");

  # ------------------------------------------------------------
  # API definitions
  # ------------------------------------------------------------
  push @{$self->routes->namespaces}, 'EduMaps::Controller';

  $self->plugin("EduMaps::Plugin::API::$_") for qw(City School Task Rank);

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
