package EduMaps::Schema::ResultSet::Base;
use Mojo::Base 'DBIx::Class::ResultSet', -signatures;
use Mojo::Collection qw(c);
use Role::Tiny::With;
use EduMaps::R::Pipe;
use Syntax::Keyword::Try;
our @APP_ROLES = map { "EduMaps::Roles::$_" } qw(PrettyPrint Formats);
with @APP_ROLES;

# table of regular expressions used in module
our %re = (
  pg_fqtn => 
  [ 
    "fully qualified table name regex",
    qr/
    (?:                                   # Grupo não-capturante para o bloco completo da tabela
      (?<tabela>                          # GRUPO CAPTURANTE 'tabela'
        (?:"[^"]+" | [a-z_][a-z0-9_]*)
      )
      \.                                  # O ponto literal
    )?                                    # Todo o bloco da tabela é opcional
    (?<coluna>                            # GRUPO CAPTURANTE 'coluna' (obrigatório)
      (?:"[^"]+" | [a-z_][a-z0-9_]*)
    )
    /ix
  ],
);

__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});
__PACKAGE__->load_components(qw{+EduMaps::Schema::ResultSet::Component::Stash});

sub geojson_features($self, $geom, $properties) {
  my $attrs = ref $properties eq 'ARRAY' ?
  [ map { ("'$_'", $_) } @$properties ]
  :
  [ map { ("'$_'", $properties->{$_})} keys %$properties ];

  $self->search_rs(
    undef,
    {
      select => [
        {
          json_build_object => [
            qw('type' 'FeatureCollection' 'features'),
            { coalesce => 
              [
                { 
                  json_agg => { 
                    json_build_object => [
                      qw('type' 'Feature' 'geometry'),
                      \"ST_AsGeoJSON($geom)::json",
                      qw('properties'),
                      { json_build_object =>  $attrs }
                    ]
                  } 
                },
                \"'[]'::json"
              ]
            }
          ],
          -as => 'feature',
        }
      ],
      as => ['feature'],
    }
  );
}

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

sub not_null ($self, $col) {
  $self->search_rs({ $col => { '!=' => undef } });
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

sub random_sample($self, $limit = 10) {
  return $self->search_rs(
    undef,
    {
      order_by => { -asc => \"RANDOM()" },
      rows     => $limit,
    }
  );
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

sub join($self, $relations) {
  $relations = ref $relations ? $relations : [ $relations ];
  $self->search_rs( undef, { join => $relations } );
}

# TODO: entender o que fazer e o proposito específico de anti_joins
sub anti_join($self, $related) {
  my $rels = $self->result_source->relationship_info($related);
  my $join_cond = {};

  if ( ref $rels->{cond} eq 'HASH' ) {
    $join_cond = $rels->{cond};
  } else {
    ...; # não implementado
  }

  # Obter o alias atual da resultset principal
  my $current_alias = $self->current_source_alias;
  
  # Extrair as partes da condição de join
  my ($foreign_col, $self_col);
  
  if (ref $rels->{cond} eq 'HASH') {
    # Para condições do tipo: { 'foreign.id' => 'self.foreign_id' }
    ($foreign_col, $self_col) = each %{$rels->{cond}};
  } else {
    die "Cannot calculate the JOIN condition";
  }
  
  # Remover prefixos de alias (ex: "foreign." ou "self.")
  $foreign_col =~ s/^\w+\.//;
  $self_col =~ s/^\w+\.//;
  
  # Obter a resultset relacionada
  my ($rs_name) = ($rels->{source} =~ m/::(\w+)$/);
  my $rel_rs = $self->result_source->schema->resultset($rs_name);
  
  # Criar a condição para a subquery
  # Usamos -ident para criar uma referência à coluna da query externa
  my $rs_param = { 
    $foreign_col => { -ident => "$current_alias.$self_col" }
  };
  
  my $rs_attrs = { 
    select => [\1],
    alias => "${related}_subq"  # Alias único para a subquery
  };
  
  # Retornar nova resultset com NOT EXISTS
  return $self->search_rs(
    { 
      -not_exists => $rel_rs->search_rs($rs_param, $rs_attrs)->as_query 
    }
  );
}

sub prefetch($self, $relations) {
  $relations = ref $relations ? $relations : [ $relations ];
  $self->search_rs( undef, { prefetch => $relations } );
}

sub columns($self, $cols) {
  $self->search_rs( undef, { columns => $cols } );
}

sub relations($self) {  
  c($self->result_source->relationships)
  ->map( sub { +{ $_ => $self->result_source->relationship_info($_) } } );
}

# TODO: skip dbic views
sub comments($self) {
  my $tbl_name = $self->result_source->name =~ s/^\w+\.//r;
  my $QUERY =<<~"EOQ";
  SELECT 
      n.nspname AS schema_name,
      c.relname AS table_name,
      a.attname AS column_name,
      col_description(a.attrelid, a.attnum) AS column_comment
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid
  WHERE c.relkind = 'r'  -- Somente tabelas
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND c.relname = '$tbl_name'
  ORDER BY n.nspname, c.relname, a.attnum
  EOQ

  $self->custom_query(
    $QUERY,
    [qw/schema_name table_name column_name column_comment/],
  );
}

# TODO: too weak implementation
sub save_in_table($self,  %opts) {
  # remove the schema part from table name
  my $name = $self->result_source->name =~ s/\w+\.//r;
  # read options
  my ($tbl_name, $schema, $is_temporary) = (
    $opts{temp}       || ( $name . '_temp'),
    $opts{schema}     || 'pg_temp', 
    $opts{temporary}  || 1,
  );
  # get the select statement and bindings
  my ($stmt, @binds)  = @{ $self->as_query->$* };
  @binds              = map { $_->[1] } @binds;
  my $storage         = $self->result_source->schema->storage;
  my $tbl             = "${schema}.${tbl_name}";
  # set the DDL transaction
  my $transaction     = sub ($me, $dbh, @args)
  {
    # drop any previous temp table
    my $drop_if = sprintf('DROP TABLE IF EXISTS %s', $tbl); 
    # create temp or permanent
    my $create  = $is_temporary ? 'CREATE TEMPORARY TABLE' : 'CREATE TABLE';
    # set the create sql statement
    $create     = sprintf ("%s %s AS (%s)",$create, $tbl, $stmt);
    # run drop
    $dbh->do($drop_if);
    # run create
    $dbh->do($create, undef, @binds);
  };

  # execute in a safe way
  $storage->txn_do(
    sub { 
      try { return $storage->dbh_do($transaction); }
      catch ($err) {
        warn "Error during temporary table creation: $err";
        $storage->txn_rollback;
      }
    }
  );
}

sub search_in($self, $resultset) {
  return $self->result_source->schema->resultset($resultset);
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

sub custom_query($self, $query, $columns, $binds = undef) {
  my $me = $self->current_source_alias;
  $query = sprintf "(%s) $me", $query;
  my $params = {};
  $params->{columns} = $columns if $columns;
  $params->{bind}    = $binds   if $binds;
  $params->{from}    = \$query;

  $self->search_rs(undef, $params)->as_hash;
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

sub z_score($self, $col) {
  $self->add_derived(
    "z_score_for_$col" => qq< ($col -AVG($col) OVER()) / NULLIF(STDDEV($col) OVER(), 0) >
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

sub minmax_scale($self, $col) {
  $self->add_derived(
    "minmax_for_$col" =>
      qq<
        ($col - MIN($col) OVER())
        / NULLIF(MAX($col) OVER() - MIN($col) OVER(), 0)
      >
  );
}

sub robust_scale($self, $col) {
  my $expr = 'percentile_cont(%f) WITHIN GROUP (ORDER BY %s.%s)';
  my $me   = $self->current_source_alias;
  my $rs   = $self->search_rs(undef); # cria um novo
  my $ps   = $rs->columns(
    [
      { p25 => \sprintf($expr, 0.25, $me, $col) },
      { p50 => \sprintf($expr, 0.50, $me, $col) },
      { p75 => \sprintf($expr, 0.75, $me, $col) },
    ]
  )->as_hash->single;

  $self->add_derived(
    "robust_for_$col" => qq|
    CASE
      WHEN $me.$col IS NULL THEN NULL
      ELSE
        ($me.$col - $ps->{p50}) / NULLIF($ps->{p75} - $ps->{p25}, 0)
      END
    |,
  );
}

sub rank_scale($self, $col) {
  $self->add_derived(
    "rank_for_$col" =>
      qq< RANK() OVER (ORDER BY $col) >
  );
}

sub log_scale($self, $col, $offset = 0) {
  $self->add_derived(
    "log_for_$col" =>
      qq< LN($col + $offset) >
  );
}

sub unit_vector_scale($self, $col) {
  $self->add_derived(
    "unit_for_$col" =>
      qq<
        $col
        / NULLIF(
            SQRT(SUM($col * $col) OVER()),
            0
          )
      >
  );
}

sub boxcox($self, $col, $lambda = 0) {
  my $expr = $lambda == 0
    ? qq< LN($col) >
    : qq< (POWER($col, $lambda) - 1) / $lambda >;

  $self->add_derived(
    "boxcox_for_$col" => $expr
  );
}

sub quantile_scale($self, $col) {
  $self->add_derived(
    "quantile_for_$col" =>
      qq< CUME_DIST() OVER (ORDER BY $col) >
  );
}

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

# TODO: not working, we need ROLLUP 
# sub add_sum_last_line($self, %opts) {
#   my $filter = sub { s/^(\w+)\.//r };
#
#   my @sums = map {
#     my $col = $filter->($_);
#     my $sql = qq{SUM($col)};
#     { $col => \$sql };
#   } $opts{cols}->@*;
#
#   my @nas = map {
#     my $col = $filter->($_);
#     { $col => \'NULL' };
#   } $opts{NA}->@*;
#
#   my ($rset_name) = (ref $self) =~ m/^.*::(\w+)$/;
#   my $last_line = $self->result_source->schema->resultset($rset_name)
#   ->search_rs(
#     undef,
#     {
#       columns => [ @nas, @sums ]
#     }
#   );
#
#   $self->union([$last_line]);
# }

sub bar_plot($self, $vars) { $self->_graph('barplot', $vars); }
sub scatter_plot($self, $vars) { $self->_graph('scatterplot', $vars); }
sub histogram_plot($self, $vars) { $self->_graph('histogram', $vars); }

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

sub separate_fqn($self, $target) {
  my ($table, $col);
  if ( $target =~ $re{pg_fqtn}[1] ) {
    $table = $+{tabela};
    $col = $+{coluna};
  }
  return $table, $col;
}

sub sql_func($self, $func, @args) {
  return sprintf(qq{$func(%s)}, CORE::join(',', @args));
}

sub round($self, $expr, $n = 2) {
  return $self->sql_func('ROUND', $expr, $n);
}

sub explain($self, %options) {
  my $analyze  = $options{analyze}  // 0;
  my $buffers  = $options{buffers}  // 0;
  my $timing   = $options{timing}   // 1;
  my $verbose  = $options{verbose}  // 0;
  my $inc_qry  = $options{include}  // 0;
  my $format   = $options{format}   || 'text';  # text, yaml, json, xml

  my @explain_opts;
  push @explain_opts, 'ANALYZE'  if $analyze;
  push @explain_opts, 'BUFFERS'  if $buffers;
  push @explain_opts, 'TIMING'   if $timing && $analyze;
  push @explain_opts, 'VERBOSE'  if $verbose;
  push @explain_opts, "FORMAT $format";

  my ($stmt, @binds)  = @{ $self->as_query->$* };
  @binds              = map { $_->[1] } @binds;
  my $storage         = $self->result_source->schema->storage;
  my $explain_cmd     = sprintf ("EXPLAIN (%s) %s", CORE::join(',', @explain_opts), $stmt);
  my $explain;

  try {
    $storage->dbh_do(
      sub ($me, $dbh, @args) {
        $explain = c($dbh->selectall_arrayref($explain_cmd, undef, @binds))->flatten->join("\n")->to_string;
      }
    );
  }
  catch($err) {
    warn "Error during explain";
  }

  # include query
  if( $inc_qry ) {
    $explain_cmd =~ s{\?}{
        my $value = shift @binds;
        defined $value ? $value : 'NULL';
    }eg;

    $explain = CORE::join "\n", $explain_cmd, $explain;
  }

  return $explain;
}

1;
