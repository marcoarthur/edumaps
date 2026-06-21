package EduMaps::Roles::Derived;
use Mojo::Base -role, -signatures;

requires qw(search_rs);

sub add_derived($self, %exprs) {
  my @as      = keys %exprs;
  my @selects = map { +{ '' => ref $exprs{$_} ? $exprs{$_} : \$exprs{$_}, -as => $_ } } @as;

  my $params = {
    '+select' => [ @selects ],
    '+as'     => [ @as ],
  };
  $self->search_rs(undef, $params);
}

sub select_derived($self, %exprs) {
  my @as      = keys %exprs;
  my @selects = map { 
    +{ '' => ref $exprs{$_} ? $exprs{$_} : \$exprs{$_}, -as => $_ } 
  } @as;

  my $params = {
    'select' => [ @selects ],
    'as'     => [ @as ],
  };
  $self->search_rs(undef, $params);
}


sub with_ratio($self, $numerator, $denominator, $as = 'ratio') {
  $self->add_derived(
    $as => "$numerator / NULLIF($denominator, 0)"
  );
}

sub categorize($self, $column, %ranges) {
  return $self unless keys %ranges; #No-OP

  my $case = "CASE ";
  while (my ($label, $condition) = each %ranges) {
    $case .= "WHEN $condition THEN '$label' ";
  }
  $case .= "ELSE 'NONE' END";

  return $self->add_derived( category => $case );
}

sub with_flags($self, %flags) {
  my %derived;

  while (my ($name, $condition) = each %flags) {
    $derived{$name} = "CASE WHEN ($condition) THEN 1 ELSE 0 END";
  }

  return $self->add_derived(%derived);
}

1;
