package EduMaps::Model::Domain::SchoolQuality;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Role::Tiny::With;
use Carp qw(croak);
use Memoize;

# Indicadores
use EduMaps::Model::Indicator::School::IFS;
use EduMaps::Model::Indicator::School::ITD;
use EduMaps::Model::Indicator::School::IPS;
use EduMaps::Model::Indicator::School::IGE;
use EduMaps::Model::Indicator::School::IAI;
use EduMaps::Model::Indicator::School::IOC;

memoize('find_similar_schools');

has geo_tag         => sub { die 'Required: ibge code or name' };
has null_treatment  => sub { 'imputation' }; # ou 'discard'
has schools         => sub { die 'Did you set the geo_tag?' };
has metric          => sub { 'manhattan' };
has id_column       => sub { 'co_entidade' };
has indicators => sub {
  return {
    ifs => EduMaps::Model::Indicator::School::IFS->new,
    itd => EduMaps::Model::Indicator::School::ITD->new,
    ips => EduMaps::Model::Indicator::School::IPS->new,
    ige => EduMaps::Model::Indicator::School::IGE->new,
    iai => EduMaps::Model::Indicator::School::IAI->new,
    ioc => EduMaps::Model::Indicator::School::IOC->new,
  };
};

with qw/EduMaps::Model::Role::FindSimilar/;

# ============================================================================
# Colunas unificadas para filtragem/descarte
# ============================================================================
has _all_columns => sub ($self) {
  my %cols;
  my $inds = $self->indicators;

  my $extras = [];
  for my $key (keys %$inds) {
    my $list = $inds->{$key}->weights;
    push @$extras, $inds->{$key}->extra_cols->@*;
    for my $pair (@$list) {
      my ($col) = @$pair;
      next if ref $col eq 'CODE';
      $cols{$col} = 1;
    }
  }

  return [(keys %cols), @$extras];
};

# ============================================================================
# Setup e Sanitização
# ============================================================================
sub _setup ($self) {
  my $geo = $self->geo_tag;
  my $param;
  if ($geo =~ /^\d+$/) {
    $param = { co_municipio => $geo };
  } else {
    $param = { no_municipio => $geo };
  }

  my $rs = $self->schema->resultset('CensoEscolas')->search_rs($param);

  if ($self->null_treatment eq 'discard') {
    my @cols = $self->_all_columns->@*;
    my $not_null_cond = { -and => [ map { $_ => { '!=' => undef } } @cols ] };
    $param = { -and => [ $param, $not_null_cond ] };
    $rs = $rs->search_rs($param);
  }

  $self->schools($rs);
  return $self;
}

# ============================================================================
# Métodos Públicos
# ============================================================================
sub calculate_for_all ($self, $key) {
  my $indicator = $self->indicators->{$key} or croak "No indicator registered for $key";
  return $self->schools->as_hash->get_all->map(sub ($school) {
      return $indicator->calculate($school);
    });
}

sub ifs ($self) { return $self->calculate_for_all('ifs') }
sub itd ($self) { return $self->calculate_for_all('itd') }
sub ips ($self) { return $self->calculate_for_all('ips') }
sub ige ($self) { return $self->calculate_for_all('ige') }
sub iai ($self) { return $self->calculate_for_all('iai') }
sub ioc ($self) { return $self->calculate_for_all('ioc') }

sub new ($class, @args) {
  my $self = $class->SUPER::new(@args);
  return $self->_setup;
}

sub all_scores ($self) {
  my $schools = $self->schools->as_hash->get_all;
  my $indicators = $self->indicators;

  return $schools->map(
    sub ($school) {
      my %scores = (escola => $school);

      for my $key (keys %$indicators) {
        $scores{$key} = $indicators->{$key}->calculate($school);
      }
      return \%scores;
    }
  );
}

sub build_feature_vector($self, $school) {
  my @labels = qw/ifs itd ips ige iai ioc/;
  my $indicators = $self->indicators;
  my $scores = {};
  for my $key (keys %$indicators) {
    $scores->{$key} = $indicators->{$key}->calculate($school);
  }
  return [@$scores{@labels}];
}

sub find_similar_schools ($self, $school, $limit = 10) {
  $self->find_similar(
    $school,
    $self->schools->as_hash,
    {
      metric => $self->metric,
      limit  => $limit,
    }
  );
}

1;
