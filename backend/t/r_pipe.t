use strict;
use warnings;

use Test::More;
use lib qw(./lib);
use Test::MockModule;
use Mojo::File qw(tempfile);
use EduMaps::R::Pipe;

# --- Fake ResultSet -----------------------------------------------------

{
  package Test::RS;
  sub new { bless {}, shift }
  sub to_csv {
    return "x\n1\n2\n3\n4\n5\n";
  }
}

{
  package Test::Proc;
  sub new { my $class = shift; bless { @_ }, $class }

  sub wait {
    my ($self) = @_;
    $self->{output}->spew("PNGDATA");
    return 0;
  }
}

# --- Mock do Script R ---------------------------------------------------

my $mock = Test::MockModule->new('EduMaps::R::Script');

$mock->redefine(
  new => sub { bless {}, 'EduMaps::R::Script' },

  input  => sub { $_[0]->{input}  = $_[1] },
  output => sub { $_[0]->{output} = $_[1] },
  error  => sub { $_[0]->{error}  = $_[1] },
  script => sub { $_[0]->{script} = $_[1] },

  execute => sub {
    my ($self) = @_;
    return Test::Proc->new(
      output => $self->{output},
      error  => $self->{error},
    );
  },
);

# --- Teste --------------------------------------------------------------

my $pipe = EduMaps::R::Pipe->new(
  data => Test::RS->new,
);

my $output = $pipe->run(
  'histogram',
  x      => 'x',
  width  => 500,
  height => 600,
  format => 'png',
);

ok(-e $output->path, 'Output file exists');
is($output->slurp, 'PNGDATA', 'Output content generated');
ok(-s $pipe->_input, 'CSV input was generated');
ok(-s $pipe->_script_file, 'R script was rendered');

done_testing;
