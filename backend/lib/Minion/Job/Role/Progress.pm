package Minion::Job::Role::Progress;
use Mojo::Base -role, -signatures;
use Mojo::Log;

has log => sub { Mojo::Log->new };
# Opção para usar um backend externo (ex: Redis) em vez de notes
has progress_backend => sub { undef };

# Método principal para reportar progresso
sub progress ($self, $percent=undef, $message=undef, $extra = {}) {
  $percent = 0 unless defined $percent;
  $percent = 100 if $percent > 100;
  $percent = 0   if $percent < 0;

  my $data = {
    percent  => $percent,
    message  => $message // '',
    extra    => $extra // {},
    updated  => time,
  };

  if (my $backend = $self->progress_backend) {
    # Usa backend externo (ex: Redis com chave baseada no job id)
    $backend->set_progress($self->job->id, $data);
  } else {
    # Armazena via note (nativo do Minion)
    $self->note(progress => $data);
  }

  $self->log->debug(sprintf("Progress %d%%: %s", $percent, $message));
  return $data;
}

# Método para consultar o progresso (geralmente usado pelo cliente)
sub get_progress ($self) {
  if (my $backend = $self->progress_backend) {
    return $backend->get_progress($self->id);
  } else {
    # Recupera das notes do job
    my $info = $self->job->info;
    return $info->{notes}{progress} // { percent => 0, message => 'Aguardando início' };
  }
}

# Método para finalizar com sucesso (opcional)
sub finish_progress ($self, $message){
  $self->progress(100, $message // 'Concluído');
}

1;
