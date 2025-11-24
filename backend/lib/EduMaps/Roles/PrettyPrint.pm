package EduMaps::Roles::PrettyPrint;
use Mojo::Base -role, -signatures;
use Mojo::Util qw(tablify);
use Term::Table;
use IO::Pager;

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

1;
