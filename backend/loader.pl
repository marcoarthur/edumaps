#!/usr/bin/env perl
#
use Mojo::Base -strict, -signatures;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;

my %options;
if (@ARGV) { my $table = shift @ARGV;
  %options = ( constraint => $table, components => [@ARGV]);
}
my @db_params = (
  'dbi:Pg:dbname=gisdb;host=ubatexu.lan', 'devel', 'senhaboa123'
);
my $namespace = 'MyApp::Schema';

make_schema_at(
  $namespace,
  {  
    %options,
    db_schema => ['foss4g2021'],
    debug => 1,
    relationships => 1,
    use_namespaces => 1,
    dump_directory => "./lib",
  },
  [@db_params]
);
