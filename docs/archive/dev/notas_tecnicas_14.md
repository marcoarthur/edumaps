# Preview SQL

Ótimo! O problema agora é que o `SQL::Abstract::Tree` está exibindo `ARRAY(0x...)` em vez do valor, porque **`@bind_values` ainda contém um arrayref** em vez do valor escalar.

Isso significa que a estrutura de `@binds` não está sendo desempacotada corretamente. Vamos ajustar a extração para garantir que apenas valores escalares sejam passados para o `format`.

### Correção definitiva

```perl
sub formatted_sql ($self, %args) {
    my $interpolate = $args{interpolate} // 1;
    my $output_fh   = $args{output_fh};

    my $query_data = $self->as_query;
    my ($sql, @binds) = @$query_data;

    # Extrai valores de forma robusta
    my @bind_values;
    for my $bind (@binds) {
        if (ref $bind eq 'ARRAY') {
            # Se o array tem dois elementos e o primeiro é hash (metadados)
            if (@$bind == 2 && ref $bind->[0] eq 'HASH') {
                push @bind_values, $bind->[1];
            }
            else {
                # Caso: array aninhado (ex: bind com múltiplos valores)
                push @bind_values, map { ref $_ eq 'ARRAY' ? $_->[1] : $_ } @$bind;
            }
        } elsif (ref $bind eq 'HASH') {
            # Caso raro: bind como hash
            push @bind_values, $bind->{value} // $bind->{dbic_colname} // $bind;
        } else {
            push @bind_values, $bind;
        }
    }

    # Cria o formatador com placeholder_surround definido
    my $sqlat = SQL::Abstract::Tree->new(
        fill_in_placeholders => $interpolate,
        placeholder_surround => ['', ''],
        %args,
    );

    # Formata a SQL (interpola se $interpolate for verdadeiro)
    my $formatted_sql = $sqlat->format($sql, \@bind_values);

    # Se NÃO interpolar, adiciona binds no final
    if (!$interpolate) {
        $formatted_sql .= " : " . join(', ', @bind_values);
    }

    if ($output_fh) {
        print $output_fh $formatted_sql . "\n";
    }

    return $formatted_sql;
}
```

### Teste rápido

Agora, a saída deve mostrar:

```sql
( SELECT ... FROM clean.escolas me WHERE municipio = 'Ubatuba' )
```

Sem o `ARRAY(...)`.

### Explicação

A estrutura de binds retornada por `as_query` pode ser:
- `[ [ { ... }, "Ubatuba" ] ]` – um bind com metadados.
- Ou `[ [ { ... }, "Ubatuba" ], [ { ... }, 123 ] ]` – múltiplos binds.

O código acima extrai o **segundo elemento** de cada bind quando ele é um array com dois elementos e o primeiro é um hashref (metadados). Isso garante que `@bind_values` contenha apenas valores escalares (`"Ubatuba"`, `123`, etc.).

Agora o `SQL::Abstract::Tree` interpola corretamente e exibe o valor real. 🎉
Perfeito! Funcionou! 🎉

Agora a SQL é exibida com o valor `'Ubatuba'` interpolado corretamente, em vez de `ARRAY(0x...)`. O segredo estava em extrair **apenas os valores escalares** dos binds, ignorando os metadados (`dbic_colname`, `sqlt_datatype`) que o DBIC anexa a cada bind.

### Resumo do que foi ajustado

1. **Extrair binds corretamente** – a estrutura retornada por `as_query` é `[ $sql, bind1, bind2, ... ]`, onde cada bind é `[ { metadados }, valor ]`. Nosso loop extrai apenas `$bind->[1]` quando é um array de 2 elementos com hash no primeiro.

2. **Definir `placeholder_surround`** – ao instanciar o `SQL::Abstract::Tree`, passamos `placeholder_surround => ['', '']` para evitar o erro de `undef` ao tentar desreferenciar.

3. **Passar binds como arrayref de valores escalares** – `\@bind_values` contém apenas os valores, permitindo a interpolação correta.

### Código final da Role

```perl
sub formatted_sql ($self, %args) {
    my $interpolate = $args{interpolate} // 1;
    my $output_fh   = $args{output_fh};

    my $query_data = $self->as_query;
    my ($sql, @binds) = @$query_data;

    my @bind_values;
    for my $bind (@binds) {
        if (ref $bind eq 'ARRAY' && @$bind == 2 && ref $bind->[0] eq 'HASH') {
            push @bind_values, $bind->[1];
        } elsif (ref $bind eq 'ARRAY') {
            push @bind_values, map { ref $_ eq 'ARRAY' ? $_->[1] : $_ } @$bind;
        } elsif (ref $bind eq 'HASH') {
            push @bind_values, $bind->{value} // $bind->{dbic_colname} // $bind;
        } else {
            push @bind_values, $bind;
        }
    }

    my $sqlat = SQL::Abstract::Tree->new(
        fill_in_placeholders => $interpolate,
        placeholder_surround => ['', ''],
        %args,
    );

    my $formatted_sql = $sqlat->format($sql, \@bind_values);
    $formatted_sql .= " : " . join(', ', @bind_values) unless $interpolate;

    if ($output_fh) {
        print $output_fh $formatted_sql . "\n";
    }

    return $formatted_sql;
}

sub preview_sql ($self, $interpolate = 1) {
    return $self->formatted_sql(
        interpolate => $interpolate,
        output_fh   => \*STDOUT,
    );
}
```

Agora você tem uma ferramenta poderosa para inspecionar SQL gerada pelo DBIC, sem depender de `DBIC_TRACE` global e com a formatação elegante do `SQL::Abstract::Tree`. 🚀
