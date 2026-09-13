Para modularizar sua classe `EduMaps::Schema::ResultSet::Base`, extraí as funcionalidades em **Roles** (traits) usando `Role::Tiny`. A ideia é manter a classe base enxuta, compondo apenas as roles, tal como já faz com `PrettyPrint` e `Formats`.

Abaixo, apresento a **proposta de divisão** em roles coesas, com a **nova classe base** e **exemplos de implementação** de algumas roles. As roles podem ser criadas no namespace `EduMaps::Roles::`.

---

## Estrutura proposta de Roles

| Role                          | Métodos incluídos                                                                                              |
|-------------------------------|----------------------------------------------------------------------------------------------------------------|
| **SearchHelpers**             | `get_all`, `cache`, `count_of`, `having`, `only`, `limit`, `order_by`, `group_by`, `alias`, `distinct`, `filter_by`, `like`, `maybe_search`, `not_null`, `is_null`, `exclude_columns` |
| **Derived**                   | `add_derived`, `select_derived`, `with_flags`, `categorize`, `with_ratio`                                     |
| **Stats**                     | `summary_stats`, `covariance`, `frequency_of`, `null_ratio`, `count_distinct`, `with_ntile`                   |
| **Scaling**                   | `z_score`, `minmax_scale`, `robust_scale`, `rank_scale`, `log_scale`, `unit_vector_scale`, `boxcox`, `quantile_scale` |
| **Joins**                     | `join`, `anti_join`, `prefetch`, `relations`                                                                  |
| **Aggregates**                | `rollup`, `grouping_sets`                                                                                     |
| **SQLUtils**                  | `separate_fqn`, `sql_func`, `round`, `explain`, `custom_query`, `health_check`, `comments`                    |
| **TempTable**                 | `save_in_table`                                                                                               |
| **Plot**                      | `_graph`, `bar_plot`, `scatter_plot`, `histogram_plot`                                                        |
| **Geo**                       | `geojson_features`                                                                                            |

---

## Nova classe base

```perl
package EduMaps::Schema::ResultSet::Base;

use Mojo::Base 'DBIx::Class::ResultSet', -signatures;
use Role::Tiny::With;
use Mojo::Collection qw(c);
use EduMaps::R::Pipe;
use Syntax::Keyword::Try;

# Roles já existentes + novas
our @APP_ROLES = map { "EduMaps::Roles::$_" } qw(
    PrettyPrint
    Formats
    SearchHelpers
    Derived
    Stats
    Scaling
    Joins
    Aggregates
    SQLUtils
    TempTable
    Plot
    Geo
);
with @APP_ROLES;

# Componentes DBIC (permanecem na classe base)
__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});
__PACKAGE__->load_components(qw{+EduMaps::Schema::ResultSet::Component::Stash});

# Tabela de expressões regulares (pode ser movida para SQLUtils, mas mantida aqui por simplicidade)
our %re = (
  pg_fqtn => [
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

1;
```

---

## Exemplos de implementação de algumas Roles

### 1. Role `SearchHelpers`

```perl
package EduMaps::Roles::SearchHelpers;

use Role::Tiny;
use Mojo::Collection qw(c);

requires 'search_rs', 'current_source_alias', 'result_source';

sub get_all($self) { c($self->all) }

sub cache($self) { $self->search_rs(undef, { cache => 1 }) }

sub count_of($self, $col, $total = "total") {
    $col = ref $col ? $col : [$col];
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

sub limit($self, $n) { $self->search_rs( undef, { rows => $n } ) }

sub order_by($self, $desc) {
    $self->search_rs( undef, { order_by => $desc } );
}

sub group_by($self, @group) {
    $self->search_rs( undef, { group_by => [ @group ] } );
}

sub alias($self, $alias) { $self->search_rs(undef, { alias => $alias } ) }

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

sub not_null ($self, $col) {
    $col = ref $col ? $col : [$col];
    $self->search_rs({ map { $_ => { '!=' => undef } } @$col });
}

sub is_null($self, $cols) {
    $cols = ref $cols ? $cols : [$cols];
    $self->filter_by( map { $_ => { '=' => undef } } @$cols );
}

sub exclude_columns($self, $cols) {
    $cols = ref $cols ? $cols : [$cols];
    my $attrs = $self->{attrs} || {};
    my @total = @{
        $attrs->{as} || $attrs->{'select'} || $attrs->{'columns'} || [$self->result_source->columns]
    };
    my %to_remove = map { $_ => 1 } @$cols;
    @total = grep { !exists $to_remove{$_} } @total;
    $self->columns([@total]);
}

1;
```

### 2. Role `Derived`

```perl
package EduMaps::Roles::Derived;

use Role::Tiny;
requires 'search_rs';

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

sub with_flags($self, %flags) {
    my %derived;
    while (my ($name, $condition) = each %flags) {
        $derived{$name} = "CASE WHEN ($condition) THEN 1 ELSE 0 END";
    }
    return $self->add_derived(%derived);
}

sub categorize($self, $column, %ranges) {
    return $self unless keys %ranges;
    my $case = "CASE ";
    while (my ($label, $condition) = each %ranges) {
        $case .= "WHEN $condition THEN '$label' ";
    }
    $case .= "ELSE 'NONE' END";
    return $self->add_derived( category => $case );
}

sub with_ratio($self, $numerator, $denominator, $as = 'ratio') {
    $self->add_derived(
        $as => "$numerator / NULLIF($denominator, 0)"
    );
}

1;
```

### 3. Role `Stats` (parcial)

```perl
package EduMaps::Roles::Stats;

use Role::Tiny;
requires 'search_rs', 'add_derived', 'not_null';

sub summary_stats($self, $value_column, @group_by_columns) {
    warn "No group given" and return $self unless @group_by_columns;
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

sub with_ntile($self, $column, $n = 100, $as = 'ntil') {
    return $self->search_rs(undef, {
        '+select' => [{ '' => \"NTILE($n) OVER (ORDER BY $column)", -as => $as }],
        '+as' => [$as]
    });
}

sub covariance($self, $x, $y, %opts) {
    my @cols;
    my $func = $opts{sample} ? 'covar_samp' : 'covar_pop';
    push @cols, { '' => qq{$func($x,$y)},  -as => 'covariance' };
    push @cols, { '' => \[qq/'$x, $y'/],   -as => 'variables' };
    push @cols, { '' => qq{corr($x,$y)},  -as => 'correlation' }  if $opts{correlation};
    push @cols, { count => '*',           -as => 'count' }        if $opts{count};
    my $includes = $opts{includes};
    if ( $includes ) {
        $includes= ref $includes ? $includes : [$includes];
        my @includes = map { +{ '' => $_, -as => $_ =~ s/\w+\.//r } } $includes->@*;
        push @cols, @includes;
    }
    my @as = map { $_->{-as} } @cols;
    $self->search_rs(undef, { select => [@cols], as => [@as] });
}

# ... frequency_of, null_ratio, count_distinct etc.

1;
```

### 4. Role `SQLUtils` (parcial)

```perl
package EduMaps::Roles::SQLUtils;

use Role::Tiny;
use Syntax::Keyword::Try;
use Mojo::Collection qw(c);
requires 'search_rs', 'result_source', 'current_source_alias', 'as_query';

sub separate_fqn($self, $target) {
    my ($table, $col);
    if ( $target =~ $self->{re}->{pg_fqtn}[1] ) {  # supondo que a classe base tenha %re
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

sub custom_query($self, $query, $columns, $binds = undef) {
    my $me = $self->current_source_alias;
    $query = sprintf "(%s) $me", $query;
    my $params = {};
    $params->{columns} = $columns if $columns;
    $params->{bind}    = $binds   if $binds;
    $params->{from}    = \$query;
    $self->search_rs(undef, $params)->as_hash;
}

sub explain($self, %options) {
    my $analyze  = $options{analyze}  // 0;
    my $buffers  = $options{buffers}  // 0;
    my $timing   = $options{timing}   // 1;
    my $verbose  = $options{verbose}  // 0;
    my $inc_qry  = $options{include}  // 0;
    my $format   = $options{format}   || 'text';
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
    if( $inc_qry ) {
        $explain_cmd =~ s{\?}{
            my $value = shift @binds;
            defined $value ? $value : 'NULL';
        }eg;
        $explain = CORE::join "\n", $explain_cmd, $explain;
    }
    return $explain;
}

# health_check, comments etc.

1;
```

### 5. Role `Plot`

```perl
package EduMaps::Roles::Plot;

use Role::Tiny;
use Syntax::Keyword::Try;
use EduMaps::R::Pipe;
requires 'search_rs';

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

sub bar_plot($self, $vars) { $self->_graph('barplot', $vars) }
sub scatter_plot($self, $vars) { $self->_graph('scatterplot', $vars) }
sub histogram_plot($self, $vars) { $self->_graph('histogram', $vars) }

1;
```

---

## Observações finais

- **Dependências entre roles**: Algumas roles dependem de outras (ex: `Stats` usa `add_derived` e `not_null`). Como a classe base compõe todas, isso não é problema. Caso queira usar uma role isoladamente, pode-se adicionar `requires` para os métodos necessários.
- **%re**: Mantive na classe base por simplicidade, mas poderia ser movido para `SQLUtils` se preferir.
- **Componentes DBIC** (`SetOperations`, `Stash`) continuam carregados na classe base, pois são específicos do esquema.
- **Testes**: Recomendo testar cada role separadamente para garantir que os métodos se comportem como antes.
- **Documentação**: Adicione `=head1` em cada role para documentar seus métodos.

Essa modularização facilita a manutenção, reúso e testes, mantendo a classe base enxuta e focada na composição.
