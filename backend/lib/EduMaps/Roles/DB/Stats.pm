package EduMaps::Roles::DB::Stats;
use Mojo::Base -role, -signatures;

requires qw(search_rs);

sub with_ntile($self, $column, $n = 100, $as = 'ntil') {
  return $self->search_rs(undef, {
      '+select' => [{ '' => \"NTILE($n) OVER (ORDER BY $column)", -as => $as }],
      '+as' => [$as]
    }
  );
}

sub summary_stats($self, $value_column, @group_by_columns) {
  warn "No group given" and return $self unless @group_by_columns; # no-OP
  return $self->search_rs(
    undef,
    {
      select => [
        @group_by_columns,
        { count    => '*', -as => 'count' },
        { sum      => $value_column, -as => 'sum' },
        { avg      => $value_column, -as => 'avg' },
        { min      => $value_column, -as => 'min' },
        { max      => $value_column, -as => 'max' },
        { stddev   => $value_column, -as => 'stddev' },
        { variance => $value_column, -as => 'variance' },
        { 
          '' => \"PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY $value_column)",
          -as => 'median' 
        },
      ],
      as => [
        @group_by_columns,
        qw(count sum avg min max stddev variance median)
      ],
      group_by => [@group_by_columns],
      order_by => { -desc => 'avg' },
    }
  );
}

sub random_sample($self, $limit = 10) {
  return $self->search_rs(
    undef,
    {
      order_by => { -asc => \"RANDOM()" },
      rows     => $limit,
    }
  );
}

sub covariance($self, $x, $y, %opts) {
  my @cols;
  my $func = $opts{sample} ? 'covar_samp' : 'covar_pop';
  # default columns
  push @cols, { '' => qq{$func($x,$y)},  -as => 'covariance' };
  push @cols, { '' => \[qq/'$x, $y'/],   -as => 'variables' };

  # optional columns
  push @cols, { '' => qq{corr($x,$y)},  -as => 'correlation' }  if $opts{correlation};
  push @cols, { count => '*',           -as => 'count' }        if $opts{count};

  # includes helps if you have a group_by
  my $includes = $opts{includes};
  if ( $includes ) {
    $includes= ref $includes ? $includes : [$includes];
    my @includes = map { +{ '' => $_, -as => $_ =~ s/\w+\.//r } } $includes->@*;
    push @cols, @includes;
  }

  my @as = map { $_->{-as} } @cols;
  $self->search_rs(undef, { select => [@cols], as => [@as] });
}

sub frequency_of($self, $col, %opts) {
  $col = ref $col ? $col : [$col];
  my $filter = sub { s/^(\w+)\.//r };

  my @cat = map { +{ '' => $_, -as => $filter->($_)} } $col->@*;
  push @cat, {count => '*', -as => 'count'};

  if ($opts{relative}) {
    # use window aggregate function to compute the frequency
    my $sql = "COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()";
    push @cat, { '' => \$sql, -as => 'frequency' };
  }

  my @as = map { $_->{-as} } @cat;

  if ( $opts{no_nulls} ) {
    $self->not_null($_) for @$col;
  }

  $self->search_rs(
    undef,
    {
      select   => [@cat],
      as       => [@as],
      group_by => $col,
      order_by => { -desc => 'count' },
    }
  );
}

sub null_ratio ($self, $cols){
  $cols = ref $cols ? $cols : [$cols];

  my $total = $self->count || 1;
  my %nulls;

  for my $col ($cols->@*) {
    my $nulls = $self->search_rs({ $col => undef })->count;
    $nulls{$col} = $nulls / $total;
  }

  return \%nulls;
}

sub count_distinct ($self, $col){
  $self->search_rs(
    undef,
    {
      'select' => [{ count => { distinct => $col } }],
      'as'     => ['count'],
    }
  );
}

1;
