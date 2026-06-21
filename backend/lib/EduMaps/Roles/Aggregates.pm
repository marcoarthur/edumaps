package EduMaps::Roles::Aggregates;
use Mojo::Base -role, -signatures;

sub rollup($self, $cols) {
  $cols = [$cols] unless ref $cols;
  my $rollup = sprintf "ROLLUP(%s)", CORE::join(',', $cols->@*);
  $self->search_rs(
    undef,
    {
      group_by => [\$rollup],
    }
  );
}

sub grouping_sets($self, $sets) {
  my $sql = sprintf "GROUPING SETS (%s)", 
  CORE::join(
    ',', 
    map {
      sprintf '(%s)', CORE::join(',', $_->@*)
    } $sets->@*
  );

  $self->search_rs(
    undef,
    { group_by => [\$sql] }
  );
}

1;
