package EduMaps::Roles::SearchHelpers;
use Mojo::Base -role, -signatures;
use Mojo::Collection qw(c);

requires qw(all search_rs);

sub get_all($self) { c($self->all) }

sub cache($self) { $self->search_rs(undef, { cache => 1 } ) };

sub count_of($self, $col, $total = "total") {

  $col = ref $col ? $col : [$col];

  # should we apply same rules in: https://metacpan.org/pod/DBIx::Class::ResultSet#columns ?
  my $filter = sub { s/^(\w+)\.//r };
  $self->search_rs(
    undef,
    {
      select   => [ $col->@*, { '' => { count => '*' }, -as => $total } ],
      as       => [ (map $filter->($_), $col->@*), $total ],
      group_by => [ $col->@* ],
      order_by => { -desc => $total },
    }
  );
}

sub having($self, $expr) {
  $self->search_rs(undef, { having => $expr });
}

sub only($self, @cols) { 
  $self->as_subselect_rs->search_rs( undef, { columns => [ @cols ] } ); 
}

sub limit($self, $n) { $self->search_rs( undef, { rows => $n } ); }

sub order_by($self, $desc) {
  $self->search_rs( undef, { order_by => $desc } );
}

sub group_by($self, @group) {
  $self->search_rs( undef, { group_by => [ @group ] } );
}

sub alias($self, $alias) { $self->search_rs(undef, { alias => $alias } ); }

sub distinct($self) { $self->search_rs( undef, { distinct => 1 } ) }

sub filter_by($self, %filters) {
  my $me = $self->current_source_alias;
  my $search = {};

  while (my ($field, $value) = each %filters) {
    next unless defined $value;
    $field = $field =~ /\w+\./ ? $field : "$me.$field";

    if (ref $value eq 'ARRAY') {
      $search->{$field} = { '-in' => $value };
    } elsif ($value =~ /%/) {
      $search->{$field} = { '-like' => $value };
    } elsif ($value =~ /^([<>]=?)\s*(.+)$/) {
      $search->{$field} = { $1 => $2 };
    } else {
      $search->{$field} = $value;
    }
  }

  return $self->search_rs($search);
}

sub not_null ($self, $col) {
  $col = ref $col ? $col : [$col];
  $self->search_rs({ map { $_ => { '!=' => undef } } @$col });
}

sub like ($self, %patterns) {
  $self->search_rs(
    map { 
      my $col = $_;
      +{ $col => { -ilike => $patterns{$col} } };
    } keys %patterns
  );
}

sub maybe_search ($self, $cond) {
  return $cond ? $self->search_rs($cond) : $self;
}

sub exclude_columns($self, $cols) {
  $cols = ref $cols ? $cols : [$cols];

  my $attrs     = $self->{attrs} || {};
  my @total     = @{
    $attrs->{as} || $attrs->{'select'} || $attrs->{'columns'} || [$self->result_source->columns]
  };
  my %to_remove = map { $_ => 1 } @$cols;
  @total = grep { !exists $to_remove{$_} } @total;
  $self->columns([@total]);
}

sub is_null($self, $cols) {
  $cols = ref $cols ? $cols : [$cols];
  $self->filter_by( map { $_ => { '=' => undef } } @$cols );
}

sub columns($self, $cols) {
  $self->search_rs( undef, { columns => $cols } );
}

sub search_in($self, $resultset) {
  return $self->result_source->schema->resultset($resultset);
}

1;
