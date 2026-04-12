package Imports;

# Boiler Plate imports for tests
use Import::Into;

our @DEFAULTS = (
  qw/strict warnings utf8 DDP/
);

sub import {
  my $target = caller;

  feature->import::into($target, ':5.38');
  Test2::V1->import::into($target, '-ipP');
  Test2::Tools::Compare->import::into(
    $target,
    qw(T F D DF E DNE FDNE U L)
  );

  $_->import::into($target) for @DEFAULTS;
  binmode(STDOUT, ':utf8');
  binmode(STDERR, ':utf8');
}

sub unimport {}

1;
