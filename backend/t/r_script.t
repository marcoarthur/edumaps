use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Devel::StackTrace;
use Test::MockModule;
use Mojo::File qw(tempfile);
use EduMaps::R::Script;

# --- Arquivos temporários ---------------------------------------------
my $script = tempfile->spew("#!/usr/bin/env Rscript\n");
my $input  = tempfile->spew("x\n1\n2\n");
my $output = tempfile->spew("PNG output");
my $error  = tempfile;

# --- Mock EduMaps::R::Script::run -----------------------------------------------

*EduMaps::R::Script::run = sub {
  my ($self, $cmd, @rest) = @_;
  is(
    $cmd,
    ['Rscript', $script->path],
    'command passed correctly'
  );
  $output->spew("PNGDATA");
  return 1;
};

# --- Execução ----------------------------------------------------------

my $r = EduMaps::R::Script->new(
  script => $script,
  input  => $input,
  output => $output,
  error  => $error,
);

my $future = $r->execute;
ok($future, 'execute returns a future');
ok($future->isa('Mojo::Promise'), 'A promise');
ok($future->can('then'), 'Can call then');

my $rc = $future->
then( 
  sub {
    my ($out) = @_;
    is(
      $out,
      "PNGDATA",
      'command is correct'
    );
  }
)->wait;

is($rc, 1, 'execution returns success');
is($error->slurp, '', 'no error written');

done_testing;
