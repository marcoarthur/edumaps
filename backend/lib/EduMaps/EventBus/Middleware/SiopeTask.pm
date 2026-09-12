package EduMaps::EventBus::Middleware::SiopeTask;

use Mojo::Base -base, -signatures;
use Syntax::Keyword::Try;
use DateTime;

has 'app';                                    # Instância do aplicativo Mojolicious
has event_type   => 'city.details.requested'; # Tipo de evento monitorado
has default_year => 2025;                     # Ano padrão para consulta SIOPE

# Retorna a closure no formato aceito pelo EventBus: sub ($event, $next)
sub to_middleware ($self) {
  return sub ($event, $next) {
    if ($event->{type} eq $self->event_type) {
      $self->_process_event($event);
    }

    # Passa a execução para o próximo middleware / handlers da cadeia
    return $next->($event);
  };
}

sub _process_event ($self, $event) {
  my $payload  = $event->{payload} // {};
  my $cod_ibge = $payload->{codigo_ibge} // $payload->{ibge_code};
  my $year     = $payload->{year}        // $self->default_year;

  unless ($cod_ibge) {
    $self->app->log->info("SiopeTask Middleware: Evento '" . $event->{type} . "' recebido sem 'codigo_ibge'");
    return;
  }

  # verifica se já existe informações SIOPE
  my $payroll = $self->app->model('City')->payroll(
    $cod_ibge, DateTime->new( month => 1, year => $year, locale => 'pt')
  );
  return if $payroll && $payroll->size > 0;

  try {
    # Chama o helper registrado pelo plugin EduMaps::Task::Siope
    my $job_id = $self->app->get_siope($cod_ibge, $year);

    $self->app->log->info(
      sprintf("SIOPE Minion Job #%s agendado via EventBus para a cidade %s (Ano: %s)", $job_id, $cod_ibge, $year)
    );
  }
  catch ($err) {
    $self->app->log->error("Falha ao agendar task SIOPE via EventBus Middleware: $err");
  }
}

1;

__END__

=head1 NAME

EduMaps::EventBus::Middleware::SiopeTask - Middleware do EventBus para disparo automático de tarefas SIOPE

=head1 SYNOPSIS

my $siope_mw = EduMaps::EventBus::Middleware::SiopeTask->new(app => $app);
$event_bus->use($siope_mw->to_middleware);

=cut
