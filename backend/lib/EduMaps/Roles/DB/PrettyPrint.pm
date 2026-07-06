package EduMaps::Roles::DB::PrettyPrint;

use Mojo::Base -role, -signatures;
use Mojo::Util qw(tablify);
use Term::Table;
use IO::Pager;
use SQL::Abstract::Tree;

requires qw(search_rs);

sub print_table($self, $pager = 0, $exclude = undef) {
  # exclude columns if request
  my $params = {
    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    $exclude ? $self->_exclude(@$exclude)->%* : (),
  };

  # hit database
  my @results = $self->search_rs(undef, $params)->all;
  return unless @results;

  # set table header and lines
  my $headers = [sort keys %{$results[0]}];
  my $rows  = [map { [@$_{@$headers}] } @results];
  my $table = Term::Table->new(header => $headers, rows => $rows, sanitize => 1);
  my $txt   = join "\n", $table->render;
  $pager ?
  do {
    my $pager = IO::Pager->new;
    $pager->print($txt);
  } : say $txt;
  $self;
}

sub _exclude($self, @excols) {
  my @cols = $self->result_source->columns;

  my %set   = map { $_ => 1 } @cols;
  $set{$_}  = 0 for @excols;
  my @select = grep { $set{$_} } keys %set;
  return {
    'select' => [@select],
  };
}

sub formatted_sql ($self, %args) {
  my $interpolate = $args{interpolate} // 1;
  my $output_fh   = $args{output_fh};

  # 1. Obtém a referência do as_query (array plano)
  my $query_data = ${$self->as_query};
  my ($sql, @binds) = @$query_data;   # $sql é string, @binds são os binds individuais

  my @bind_values = map { ref $_ eq 'ARRAY' ? $_->[1] : $_ } @binds;

  # 3. Cria o formatador
  my $sqlat = SQL::Abstract::Tree->new(
    fill_in_placeholders => $interpolate,
    placeholder_surround => ["'", "'"],
    %args,
  );

  # 4. Formata a SQL (substitui placeholders se $interpolate for verdadeiro)
  my $formatted_sql = $sqlat->format($sql, \@bind_values);

  # 6. Escreve no filehandle se solicitado
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

1;
