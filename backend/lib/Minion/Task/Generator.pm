package Minion::Task::Generator;

use Exporter 'import';
our @EXPORT_OK = qw(task);

use Mojo::Base qw(Minion::Job);
use Mojo::Util qw/dumper/;
use Mojo::Loader qw/load_class/;

use Class::Method::Modifiers;
use Hash::Merge qw/merge/;
use List::Util qw/pairfirst/;
use Scalar::Util ();

has _opts => sub { {} };

has roles => sub { [] };

require Role::Tiny;

around 'new' => sub {
  my $orig = shift;
  my $self = shift;

  my $sub = 
  ref $_[0] eq 'CODE' ?
  shift() :
  $_[0]->{sub};

  my $roles = $_[0]->{roles};

  my $p = (ref $self) || $self;

  return sub {
    my $job = shift;
    bless $job, $p;
    my $roles = $roles;

    my (undef, $opts);
    if ( @_ % 2 eq 0 ) {
      ( undef, $opts ) = pairfirst { $a eq '-opts' } @_;
      $job->opts($opts);
    }

    my @roles = keys %$roles;

    for (@roles) {
      $job->opts({ _role_class($_) => $roles->{$_} });
    }
    $job = $job->with_roles(@roles) if @roles;
    $job->run($sub, @_);
  };
};

sub _role_class {
  local $_ = shift;
  my $role = $_ =~ s/\+/Minion::Job::Role::/r;
}


around 'with_roles' => sub {
  my $orig = shift;
  my $self = shift;


  my @roles;
  for (@_) {
    my $role = _role_class($_);
    my $e = load_class $role;
    push @roles, $role unless $e;
  }

  $self->roles(\@roles);
  $orig->($self, @roles);
};

sub opts {
  my $job = shift;
  my $opts = $job->_opts;
  return $opts unless @_;
  if (ref $_[0] eq 'HASH') { $opts = merge $opts, shift }
  $job->_opts($opts);
};

sub run {
  my $job = shift;
  my $sub = shift;

  my $r = $sub->($job, @_);

  if ($@) {
    $job->fail($@);
  } else {
    $job->finish($r);
  }
}

sub task { __PACKAGE__->new(@_) }

1;

__END__

=pod

=head1 NAME

Minion::Task::Generator - Taken from https://github.com/simonecesano/Minion-Task-Generator

=head1 AUTHOR

O Autor do plugin é simonecesano

=cut
