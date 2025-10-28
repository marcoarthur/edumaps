package MyApp::Roles::Formats;
use Mojo::Base -role, -signatures;
use Mojo::JSON qw(encode_json);
use Mojo::DOM;
use Mojo::Collection qw(c);
use YAML;

requires qw(next search_rs result_source);

has include_header   => sub { 1 };
has __columns => sub ($self) {
  # Strategy 1: Try to get from actual result data
  my $rs = $self->as_hash;
  if (my $first = $rs->next) {
    $rs->reset;
    return [sort keys %$first];
  }

  # Strategy 2: Try to get from statement handle
  my $cursor = $self->cursor;
  if (my $sth = $cursor->{sth}) {
    return [$sth->{NAME}];
  }

  # Strategy 3: Fallback to result_source
  return [$self->result_source->columns];
};

sub as_hash($self) {
  return $self->search_rs(
    undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator'}
  );
}

sub _create_file_writer($self, $fh, $formatter) {
  return sub (@values) { print $fh $formatter->(@values) };
}

sub _create_formatter($self, $fh, $formatter_cb) {
  if ($fh) {
    return $self->_create_file_writer($fh, $formatter_cb);
  }
  else {
    return $self->_create_accumulator($formatter_cb);
  }
}

sub _create_accumulator($self, $formatter) {
  my $buffer = '';  # Nova variável cada vez
  return sub (@values) {
    if (@values) {
      $buffer .= $formatter->(@values);
    } else {
      my $result = $buffer;
      $buffer = '';
      return $result;
    }
  };
}

sub _apply_format($self, $formatter_cb, $fh = undef) {
  my @columns = $self->__columns->@*;
  my $rs = $self->as_hash;
  my $output = $self->_create_formatter($fh, $formatter_cb);

  # Header
  $output->(@columns) if $self->include_header;

  # Data
  while (my $row = $rs->next) {
    $output->( @{$row}{@columns} );
  }

  return $output->() unless $fh;
  return 1; # Sucesso para filehandle
}

sub to_tsv($self, $fh = undef) {
  my $tsv_fmt = sub (@values) {
    @values = map { defined $_ ? $_ : 'NA' } @values;
    return join ("\t", @values) . "\n";
  };
  return $self->_apply_format($tsv_fmt, $fh);
}

sub to_markdown($self, $fh = undef) {
  my $md_cb = sub (@values) {
    @values = map { defined $_ ? $_ : '' } @values;
    return "|" . join("|", @values) . "|\n";
  };
  return $self->_apply_format($md_cb, $fh);
}

sub to_fixed_width($self, $fh = undef, %options) {
  my %defaults = (
    widths      => {},      # Hash com larguras por coluna
    align       => 'left',  # left|right
    pad_char    => ' ',     # Caractere de preenchimento
    na_string   => '',      # Representação de valores undefined
  );
  my $opts = { %defaults, %options };

  my $fixed_formatter = sub (@values) {
    my @formatted;
    my @cols = $self->__columns->@*;

    for my $i (0..$#values) {
      my $value = defined $values[$i] ? $values[$i] : $opts->{na_string};
      my $width = $opts->{widths}{$cols[$i]} || length($value) || 10;

      # Truncar se necessário
      $value = substr($value, 0, $width) if length($value) > $width;

      # Aplicar alinhamento
      if ($opts->{align} eq 'right') {
        $value = sprintf("%*s", $width, $value);
      } else {
        $value = sprintf("%-*s", $width, $value);
      }

      push @formatted, $value;
    }

    return join('', @formatted) . "\n";
  };

  return $self->_apply_format($fixed_formatter, $fh);
}

sub to_json($self, $fh = undef) {
  my $json = encode_json( [$self->as_hash->all] );
  return $fh ? print $fh $json : $json;
}

sub to_yaml($self, $fh = undef) {
  my $yaml = YAML::Dump([$self->as_hash->all]);
  return $fh ? print $fh $yaml : $yaml;
}

sub to_html($self, $fh = undef) {
  my $dom = Mojo::DOM->new;

  my $table_row = sub (@values) {
    @values = map { defined $_ ? $_ : 'NA' } @values;
    my $tr = $dom->parse('<tr></tr>')->[0];
    c( map { $dom->new_tag('td', $_) } @values )
    ->each( sub { $tr->append_content($_)} );
    return $tr;
  };

  # generate body part
  my @cols = $self->__columns->@*;
  my $tbody = $dom->parse('<tbody></tbody>')->[0];
  c($self->as_hash->all)->map(
    sub ($row) { $table_row->(@{$row}{@cols}) }
  )->each( sub { $tbody->append_content($_) } );

  # generate header part
  my $thead = $dom->parse('<thead><tr></tr></thead>')->[0];
  c($self->__columns->@*)->each(
    sub { 
      $thead->at('tr')->append_content($dom->new_tag('th', $_))
    }
  );

  # generate table
  my $table = $dom->parse('<table></table>')->[0];
  $table->append_content($_) for ($thead, $tbody);

  return $fh ? print $fh "$table" : "$table";
}

1;

__END__

zotero://note/u/3PCTKTKC/?line=2

