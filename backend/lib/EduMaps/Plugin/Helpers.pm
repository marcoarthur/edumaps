package EduMaps::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Carp qw(croak);
use Mojo::JSON qw(encode_json);
use Scalar::Util qw(weaken);
use constant {
  MSG_SENT_LIMIT => 10**3,
  COMPLETE_PERCENT => 99.9,
  DEFAULT_POLL_TIME => 2,
};

has models_cache => sub { state $cache = {} };

sub register ($self, $app, @args) {
  $self->_add_helpers($app);
}

sub _add_helpers($self, $app) {

  $app->helper(
    model => sub ($c, $model) {
      my $class = "EduMaps::Model::$model";
      return $self->models_cache->{$class} ||= do {
        unless ($class->can('new')) {
          eval "require $class" or die "Não foi possível carregar o modelo $class: $@";
        }
        $class->new( schema => $app->schema );
      };
    }
  );

  $app->helper(
    monitor_job => \&_monitor_minion_job
  );
}

sub _monitor_minion_job($c, $args) {
  my $watch = $c->minion->job($args->{job_id});
  return unless $watch;
  return if $watch->info->{state} eq 'finished';
  my $finish_cb = $args->{on_finish};
  my $weaked = $c;
  weaken($weaked);
  my $monitor;

  # remove monitor e chama callback passando resultado
  $c->on(
    finish => sub {
      Mojo::IOLoop->remove($monitor) if $monitor;
      $finish_cb->($watch->info->{result}) if $finish_cb;
    }
  );

  # abre o Server Sent Event (sse)
  $c->write_sse unless $args->{on_progress};
  $args->{on_progress} //= sub ($msg){
    return unless $weaked;
    $weaked->write_sse($msg)
  };

  # polling progresso do job
  my $poll_time = $args->{poll_time} // DEFAULT_POLL_TIME;
  my $msg_count = 0;
  $monitor = Mojo::IOLoop->recurring(
    $poll_time => sub {
      my $current_info = $watch->info;
      my $state        = $current_info->{state};
      my $progress     = $current_info->{notes}{progress} // { percent => 0, message => 'Iniciando...' };

      $weaked->log->debug(
        sprintf "Job (%d) at state (%s): processed (%s%%)",
        $current_info->{id}, $state, ($progress->{percent} // 0)
      );

      $args->{on_progress}->({type => 'progress', text => encode_json($progress)});

      $weaked->finish if ($watch->info->{state} eq 'finished' or $progress->{percent} >= COMPLETE_PERCENT);
      $weaked->finish if $msg_count++ >= MSG_SENT_LIMIT;
    }
  );
}

1;
