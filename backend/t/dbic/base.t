use lib qw(./t/lib);
use Imports;
use Mojo::Collection qw(c);
use EduMaps::Schema;

my $sch = EduMaps::Schema->go;
sub filter_resultsets($filter_cb) {
  c($sch->sources)->map( sub { $sch->resultset($_ ) } )->grep( $filter_cb );
}

subtest  health_check_method => sub {
  my $can_health_check = filter_resultsets(
    sub ($rs) {
      $rs->can('health_check') &&
      # purely dbic view, does not make sense for health_check
      not $rs->result_source->isa('DBIx::Class::ResultSource::View');
    }
  );

  ok ($can_health_check->size <= scalar($sch->sources), 'a subset of rs can health_check');

  $can_health_check->each(
    sub ($rs, $idx) {
      is(
        $rs->health_check->as_hash->first,
        hash {
          field column_name => E;
          field data_type => E;
          field total_rows => E;
          field null_count => E;
          field non_null_count => E;
          field distinct_approx => E;
          etc();
        },
        "counting fields for health checking"
      );
    }
  );
};

done_testing;
