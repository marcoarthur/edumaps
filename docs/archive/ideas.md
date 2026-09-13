Excelente estrutura! Com o diretório `Role` já criado, podemos implementar roles reutilizáveis no `EduMaps::Model::Base`. Aqui estão sugestões de roles gerais:

## Estrutura de Roles Proposta

```perl
# lib/EduMaps/Model/Role/JSONable.pm
package EduMaps::Model::Role::JSONable;
use Mojo::Base -role;
use Mojo::JSON qw(encode_json decode_json);

requires 'as_hash';  # Método que os modelos devem implementar

sub to_json {
    my ($self, $pretty = 0) = @_;
    my $data = $self->as_hash;
    return $pretty ? encode_json($data) : encode_json($data);
}

sub from_json {
    my ($self, $json) = @_;
    return $self->new(decode_json($json));
}

1;
```

```perl
# lib/EduMaps/Model/Role/Cachable.pm
package EduMaps::Model::Role::Cachable;
use Mojo::Base -role;
use Mojo::Cache;
    need_bind: false
has has_bind => sub { Mojo::Cache->new };
has cache_ttl => 300;  # 5 minutes default

around find => sub {
    my ($orig, $self, @args) = @_;
    my $cache_key = $self->_cache_key('find', @args);
    return $self->cache->get($cache_key) //= $self->$orig(@args);
};

around search => sub {
    my ($orig, $self, @args) = @_;
    my $cache_key = $self->_cache_key('search', @args);
    return $self->cache->get($cache_key) //= $self->$orig(@args);
};

sub _cache_key {
    my ($self, $method, @args) = @_;
    return join(':', ref($self), $method, map { ref($_) ? encode_json($_) : $_ } @args);
}

sub clear_cache {
    my ($self) = @_;
    $self->cache->clear;
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithPagination.pm
package EduMaps::Model::Role::WithPagination;
use Mojo::Base -role;

has page     => 1;
has per_page => 20;

sub paginate {
    my ($self, $results) = @_;
    my $total = scalar @$results;
    my $offset = ($self->page - 1) * $self->per_page;
    my $pages = ceil($total / $self->per_page);
    
    return {
        data       => [@$results[$offset .. $offset + $self->per_page - 1]],
        pagination => {
            current_page => $self->page,
            per_page     => $self->per_page,
            total        => $total,
            total_pages  => $pages,
            has_next     => $self->page < $pages,
            has_prev     => $self->page > 1,
        }
    };
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithValidation.pm
package EduMaps::Model::Role::WithValidation;
use Mojo::Base -role;
use Syntax::Keyword::Try;

has validations => sub { {} };

sub validate {
    my ($self, $data, $rules) = @_;
    my @errors;
    
    for my $field (keys %$rules) {
        my $value = $data->{$field};
        my $rule = $rules->{$field};
        
        if ($rule->{required} && !defined $value) {
            push @errors, "$field is required";
            next;
        }
        
        next unless defined $value;
        
        if ($rule->{type} eq 'integer' && $value !~ /^\d+$/) {
            push @errors, "$field must be an integer";
        }
        
        if ($rule->{type} eq 'string' && ref $value) {
            push @errors, "$field must be a string";
        }
        
        if ($rule->{min} && $value < $rule->{min}) {
            push @errors, "$field must be at least $rule->{min}";
        }
        
        if ($rule->{max} && $value > $rule->{max}) {
            push @errors, "$field must be at most $rule->{max}";
        }
        
        if ($rule->{in} && !grep { $value eq $_ } @{$rule->{in}}) {
            push @errors, "$field must be one of: " . join(', ', @{$rule->{in}});
        }
    }
    
    return \@errors;
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithGeospatial.pm
package EduMaps::Model::Role::WithGeospatial;
use Mojo::Base -role;

requires 'schema';
requires 'resultset';

sub find_nearby {
    my ($self, $lat, $lng, $radius = 3000, $limit = 20) = @_;
    
    my $sql = q{
        SELECT *, 
               ST_Distance(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4674)) as distance
        FROM clean.escolas
        WHERE ST_DWithin(geometry, ST_SetSRID(ST_MakePoint(?, ?), 4674), ?)
        ORDER BY distance
        LIMIT ?
    };
    
    return $self->schema->storage->dbh->selectall_arrayref(
        $sql, { Slice => {} }, $lng, $lat, $lng, $lat, $radius, $limit
    );
}

sub to_geojson {
    my ($self, $records) = @_;
    
    my $features = [];
    for my $record (@$records) {
        push @$features, {
            type => 'Feature',
            geometry => {
                type => 'Point',
                coordinates => [$record->{longitude}, $record->{latitude}]
            },
            properties => $self->_extract_properties($record)
        };
    }
    
    return {
        type => 'FeatureCollection',
        features => $features
    };
}

sub _extract_properties {
    my ($self, $record) = @_;
    # To be implemented by consuming class
    return $record;
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithExport.pm
package EduMaps::Model::Role::WithExport;
use Mojo::Base -role;
use Text::CSV_XS;

requires 'as_arrayref';

sub to_csv {
    my ($self, $data = undef) = @_;
    $data //= $self->as_arrayref;
    
    my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });
    my $output;
    
    # Headers
    my $headers = $data->[0] ? [keys %{$data->[0]}] : [];
    $csv->combine(@$headers);
    $output .= $csv->string . "\n";
    
    # Data
    for my $row (@$data) {
        $csv->combine(map { $row->{$_} } @$headers);
        $output .= $csv->string . "\n";
    }
    
    return $output;
}

sub to_excel {
    my ($self, $data = undef) = @_;
    # Would require Excel::Writer::XLSX or similar
    # Implementation depends on your needs
    die "Excel export not implemented yet";
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithLogging.pm
package EduMaps::Model::Role::WithLogging;
use Mojo::Base -role;

has log => sub { Mojo::Log->new };

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
    my $self = $class->$orig(@args);
    $self->log->debug("Created new " . ref($self));
    return $self;
};

around DESTROY => sub {
    my ($orig, $self) = @_;
    $self->log->debug("Destroying " . ref($self));
    $self->$orig;
};

sub log_query {
    my ($self, $sql, $params) = @_;
    $self->log->debug("SQL: $sql");
    $self->log->debug("Params: " . join(', ', @$params)) if $params;
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithFiltering.pm
package EduMaps::Model::Role::WithFiltering;
use Mojo::Base -role;

sub apply_filters {
    my ($self, $results, $filters) = @_;
    
    for my $field (keys %$filters) {
        my $value = $filters->{$field};
        next unless defined $value;
        
        $results = [grep { $self->_match_filter($_, $field, $value) } @$results];
    }
    
    return $results;
}

sub _match_filter {
    my ($self, $item, $field, $filter) = @_;
    
    my $item_value = $item->{$field};
    return 0 unless defined $item_value;
    
    if (ref $filter eq 'HASH') {
        # Range filter: { min => 10, max => 20 }
        if (exists $filter->{min} && $item_value < $filter->{min}) {
            return 0;
        }
        if (exists $filter->{max} && $item_value > $filter->{max}) {
            return 0;
        }
        return 1;
    }
    elsif (ref $filter eq 'ARRAY') {
        # In array filter
        return grep { $item_value eq $_ } @$filter ? 1 : 0;
    }
    elsif ($filter =~ /^\*(.*)\*$/) {
        # Contains filter: *text*
        return $item_value =~ /$1/;
    }
    elsif ($filter =~ /^(.*)\*$/) {
        # Starts with filter: text*
        return $item_value =~ /^$1/;
    }
    elsif ($filter =~ /^\*(.*)$/) {
        # Ends with filter: *text
        return $item_value =~ /$1$/;
    }
    else {
        # Exact match
        return $item_value eq $filter;
    }
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithStatistics.pm
package EduMaps::Model::Role::WithStatistics;
use Mojo::Base -role;
use List::Util qw(min max sum);

sub calculate_stats {
    my ($self, $values, $field) = @_;
    
    my @nums = grep { defined $_ && looks_like_number($_) } 
               map { $_->{$field} } @$values;
    
    return {} unless @nums;
    
    return {
        count    => scalar @nums,
        sum      => sum(@nums),
        min      => min(@nums),
        max      => max(@nums),
        avg      => sum(@nums) / @nums,
        median   => $self->_median(\@nums),
        std_dev  => $self->_std_dev(\@nums),
    };
}

sub _median {
    my ($self, $nums) = @_;
    my @sorted = sort { $a <=> $b } @$nums;
    my $mid = int(@sorted / 2);
    return @sorted % 2 ? $sorted[$mid] : ($sorted[$mid-1] + $sorted[$mid]) / 2;
}

sub _std_dev {
    my ($self, $nums) = @_;
    my $avg = sum(@$nums) / @$nums;
    my $variance = sum(map { ($_ - $avg) ** 2 } @$nums) / @$nums;
    return sqrt($variance);
}

1;
```

```perl
# lib/EduMaps/Model/Role/WithSchema.pm
package EduMaps::Model::Role::WithSchema;
use Mojo::Base -role;

has schema => sub { shift->app->schema };
has dbh    => sub { shift->schema->storage->dbh };

sub with_transaction {
    my ($self, $coderef) = @_;
    my $guard = $self->schema->storage->txn_scope_guard;
    my $result = $coderef->($self);
    $guard->commit;
    return $result;
}

1;
```

## Aplicando Roles no EduMaps::Model::Base

```perl
# lib/EduMaps/Model/Base.pm
package EduMaps::Model::Base;
use Mojo::Base -base;

# Import roles
use EduMaps::Model::Role::JSONable;
use EduMaps::Model::Role::Cachable;
use EduMaps::Model::Role::WithLogging;
use EduMaps::Model::Role::WithSchema;
use EduMaps::Model::Role::WithStatistics;
use EduMaps::Model::Role::WithValidation;
use EduMaps::Model::Role::WithFiltering;

# Apply roles
with qw(
    EduMaps::Model::Role::JSONable
    EduMaps::Model::Role::Cachable
    EduMaps::Model::Role::WithLogging
    EduMaps::Model::Role::WithSchema
    EduMaps::Model::Role::WithStatistics
    EduMaps::Model::Role::WithValidation
    EduMaps::Model::Role::WithFiltering
);

has app => sub { undef };

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->log->debug("Initializing " . ref($self));
    return $self;
}

# Método base que os modelos devem implementar
sub as_hash { die "Method as_hash must be implemented by " . ref(shift) }

sub as_arrayref { die "Method as_arrayref must be implemented by " . ref(shift) }

1;
```

## Exemplo de uso em EduMaps::Model::School

```perl
# lib/EduMaps/Model/School.pm
package EduMaps::Model::School;
use Mojo::Base 'EduMaps::Model::Base';

use EduMaps::Model::Role::WithGeospatial;
use EduMaps::Model::Role::WithPagination;
use EduMaps::Model::Role::WithExport;

with qw(
    EduMaps::Model::Role::WithGeospatial
    EduMaps::Model::Role::WithPagination
    EduMaps::Model::Role::WithExport
);

sub find {
    my ($self, $cod_inep) = @_;
    my $result = $self->schema->resultset('Escolas')->find($cod_inep);
    return $result ? $result->TO_JSON : undef;
}

sub as_hash {
    my ($self, $result) = @_;
    return $result->TO_JSON if $result;
    return {};
}

sub as_arrayref {
    my ($self, $results) = @_;
    return [map { $_->TO_JSON } @$results];
}

sub payroll {
    my ($self, $cod_inep, $dt) = @_;
    # implementation...
}

1;
```

## Resumo dos Roles

| Role | Funcionalidade |
|------|---------------|
| **JSONable** | Conversão para/fr JSON |
| **Cachable** | Cache de resultados de queries |
| **WithPagination** | Paginação de resultados |
| **WithValidation** | Validação de dados |
| **WithGeospatial** | Operações geográficas |
| **WithExport** | Exportação CSV/Excel |
| **WithLogging** | Logging automático |
| **WithFiltering** | Filtragem avançada |
| **WithStatistics** | Cálculos estatísticos |
| **WithSchema** | Acesso ao schema e transactions |

Esta arquitetura permite composição flexível onde cada modelo pode escolher quais roles utilizar conforme sua necessidade específica.
