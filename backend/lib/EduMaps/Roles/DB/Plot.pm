package EduMaps::Roles::DB::Plot;
use Mojo::Base -role, -signatures;
use Syntax::Keyword::Try;
use EduMaps::R::Pipe;

sub _graph($self, $plot_type, $plot_vars) {
  die "need plot settings" unless $plot_vars;

  try {
    my $r = EduMaps::R::Pipe->new(
      data => $self,
      vars => $plot_vars,
    );
    $r->run($plot_type);
  } catch ($err) {
    warn "Error running plot: $err";
  }
  $self;
}

sub bar_plot($self, $vars) { $self->_graph('barplot', $vars); }
sub scatter_plot($self, $vars) { $self->_graph('scatterplot', $vars); }
sub histogram_plot($self, $vars) { $self->_graph('histogram', $vars); }

1;
