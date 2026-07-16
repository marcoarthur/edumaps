package EduMaps::Roles::DB::SQLUtils;
use Mojo::Base -role, -signatures;
use Mojo::Collection qw(c);
use Carp qw(croak);
use Syntax::Keyword::Try;

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

sub custom_query($self, $query, $columns, $binds = undef) {
  my $me = $self->current_source_alias;
  $query = sprintf "(%s) $me", $query;
  my $params = {};
  $params->{columns} = $columns if $columns;
  $params->{bind}    = $binds   if $binds;
  $params->{from}    = \$query;

  $self->search_rs(undef, $params)->as_hash;
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

  $self->as_hash->custom_query(
    $QUERY,
    [qw/schema_name table_name column_name column_comment/],
  );
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

sub health_check($self) {
  my $cols = [
    qw/column_name data_type total_rows null_count non_null_count 
    null_percentage distinct_approx/
  ];
  my ($schema, $table) = split (/\./, $self->result_source->name);
  do {$table = $schema; $schema = 'public' } unless $table;
  my $QUERY = sprintf ("SELECT * FROM health_check_approx('%s','%s')", $schema, $table);

  $self->custom_query($QUERY,$cols)
}

# TODO: fragile implementation
sub save_in_table($self,  %opts) {
  # remove the schema part from table name
  my $name = $self->result_source->name =~ s/\w+\.//r;
  # read options
  my ($tbl_name, $schema, $is_temporary) = (
    $opts{tbl_name}       || ( $name . '_temp'),
    $opts{schema}         || 'pg_temp', 
    defined $opts{temporary} ? $opts{temporary} : 1,
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

sub count_null($self, $col) {
  $col = ref $col ? $col : [$col];
  my @count_null;
  my $alias = $self->current_source_alias;

  my %seen;

  for my $c (@$col) {
    next if ref $c; # we don't know what to do
    next if $seen{$c};
    my $null = "${c}_nulls";
    my $expr = sprintf "COUNT(*) FILTER ( WHERE %s IS NULL ) AS %s", "$alias.$c", $null;
    push @count_null, {$c =>  \$expr};
    $seen{$c} = 1;
  }

  $self->columns(\@count_null);
}

sub summary_for_nulls($self, $opts) {
  my $row = $self->as_hash->first;
  croak "No columns in resultset" unless $row;
  my $cols  = [keys $row->%*];
  my $total_rows = $self->count;

  my $null_count = $self->count_null($cols)->as_hash->first;
  my $bellow = sub($c) {
    ($null_count->{$c} / $total_rows) < $opts->{threshold}/100
  };

  # select columns with nulls percentage less than threshold
  my @cols_with_data = grep {$bellow->($_)} keys $null_count->%*;

  # total data lost because of nulls
  my $lost_count = $self->search_rs(
    {-or => [map { $_ => undef } @cols_with_data]}
  )->count;

  my $summary = {
    max_null_acceptable => $opts->{threshold},
    acceptable_features_percent => (@cols_with_data/@$cols)*100,
    max_sample_lost => ($lost_count/$total_rows)*100,
  };

  my @cols_without_data = grep {! $bellow->($_)} keys $null_count->%*;

  return {
    summary => $summary,
    acceptable_features => [@cols_with_data],
    non_acceptable_features => [@cols_without_data],
    sample_size => $total_rows,
    total_features_size => scalar(@$cols),
  };
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

1;
