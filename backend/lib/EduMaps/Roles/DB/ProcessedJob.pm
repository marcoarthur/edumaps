package EduMaps::Roles::DB::ProcessedJob;
use Mojo::Base -role, -signatures;
use Syntax::Keyword::Try;
use Carp qw(croak);

has _search_policy => sub ($self) {
  {
    last_job => sub($jobs, @args){
      my $last;
      while(my $info = $jobs->next) {
        $last = $info unless $last;
        $last = $info if $info->{id} > $last->{id};
      }
      return $last->{id};
    },

    last_matching_features => sub($jobs){
      my $feat = do {
        my $row = $self->as_hash->first;
        $self->reset;
        [ keys %$row ];
      };

      my $last;
      while(my $info = $jobs->next) {
        my $signature = $info->{similarity_info}{r_meta}{params}{features};
        next unless $signature;
        if ($self->_equal_signature($feat, $signature)) {
          $last = $info unless $last;
          if ($info->{id} > $last->{id} ){
            $last = $info;
          }
        }
      }
      return $last ? $last->{id} : undef;
    }
  };
};

sub set_features_from_job($self, $minion, $job_id) {
  my $job = $minion->job($job_id);
  croak "Cannot find the job $job_id" unless $job;
  my $source = $self->result_source->source_name;
  $self->result_source->schema
  ->inject_similarity_relation_from_job($job->info->{result}, $source);
  $self;
}

sub perform_similarity_job($self, $minion, $id_column = undef, $from = undef) {
  if ($from) {
    my $search = $self->_search_policy->{$from};
    croak "search policy not recognized $from" unless $search;

    my $jobs    = $minion->jobs({tasks => ['similarity'], status => ['finished']});
    my $job_id  = $search->($jobs);
    return $self->set_features_from_job($minion, $job_id);
  }

  my $source = $self->result_source;
  my $table_name = "similar_" . time;
  try {
    $self->save_in_table(
      tbl_name    => $table_name,
      schema      => 'staging',
      temporary   => 0,
    );
    my $args = {
      id_column     => $id_column ? $id_column :($source->primary_columns)[0],
      table_name    => $table_name,
      schema        => 'staging',
      metric        => 'gower',
    };

    my $id = $minion->enqueue( similarity => [$args] );
    my $job = $minion->job($id);
    $minion->perform_jobs;
    $self->set_features_from_job($minion, $id);
  } catch($err) {
    warn "Error during similarity calculus: $err";
  }

  # cleanup
  $self->result_source->schema->storage
  ->dbh_do(sub ($me, $dbh, @args){$dbh->do("DROP TABLE IF EXISTS staging.$table_name")});

  $self;
}

# TODO: how to observe equal signature ?
sub _equal_signature($self, $f1, $f2) {
  return 0 if scalar(@$f1) > scalar(@$f2) + 1;
  return 1;
}

1;
