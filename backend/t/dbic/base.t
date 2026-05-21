use lib qw(./t/lib);
use Imports;
use Mojo::Collection qw(c);
use EduMaps::Schema;

my $sch = EduMaps::Schema->go;
my $health_check = c($sch->sources)->map(sub {$sch->resultset($_)})->grep(sub {$_->can('health_check')});

subtest healtcheck_method => sub {
  ok ($health_check->size <= scalar($sch->sources), 'a subset of rs can health_check');

  $health_check->each(
    sub ($rs, $idx) {
      # purely dbic view, does not make sense for health_check
      return if $rs->result_source->isa('DBIx::Class::ResultSource::View');
      is(
        $rs->health_check->as_hash->first,
        hash {
          field column_name => E;
          field data_type => E;
          field total_rows => E;
          field null_count => E;
          field non_null_count => E;
          field distinct_approx => E;
        },
        "counting fields for health checking"
      );
    }
  );
};

done_testing;
