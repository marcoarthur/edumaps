package EduMaps::R::Script;

use Mojo::Base -base, -signatures, -async_await;

use Mojo::IOLoop;
use Mojo::Log;
use IPC::Run;
use DDP;

has engine => sub { 'Rscript' };
has [qw/input output error script/] => sub {
  die 'required in order to execute';
};
has log => sub { Mojo::Log->new };

sub run ($self, @args) {
  IPC::Run::run(@args);
}

sub _task($self) {
  my $stderr = '';

  my @cmd = (
    $self->engine,
    $self->script->path,
  );

  my $ok = $self->run(\@cmd, '2>', \$stderr);

  if (!$ok) {
    $stderr //= "R execution failed";
    $stderr .= "\n" . '=' x 100;
    $stderr .= "\n" . $self->script->slurp;
    $self->error->spew($stderr);
    return -1;
  }

  return $self->output->slurp;
}

async sub execute ($self) {
  Mojo::IOLoop->subprocess->run_p( sub { $self->_task } );
}

1;
