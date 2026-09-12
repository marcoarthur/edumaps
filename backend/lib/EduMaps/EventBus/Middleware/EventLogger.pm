package EduMaps::EventBus::Middleware::EventLogger;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(encode_json);
use Syntax::Keyword::Try;

has 'app';
has ignore_events => sub { { 'system.ping' => 1 } }; # Eventos de ruído para ignorar

sub to_middleware ($self) {
  return sub ($event, $next) {
    # 1. Registra o evento de forma assíncrona/não-bloqueante
    $self->_record_event($event);

    # 2. Continua a execução do EventBus sem esperar a gravação terminar
    return $next->($event);
  };
}

sub _record_event ($self, $event) {
  my $type = $event->{type};
  return if $self->ignore_events->{$type};

  my $payload    = $event->{payload} // {};
  my $cod_ibge   = $payload->{codigo_ibge} // $payload->{ibge_code};
  my $is_spec    = $payload->{is_speculative} ? 1 : 0;

  try {
    $self->app->pg->db->insert_p(
      'event_store',
      {
        event_id       => $event->{id},
        event_type     => $type,
        codigo_ibge    => $cod_ibge,
        is_speculative => $is_spec,
        source         => $event->{source} // 'unknown',
        payload        => encode_json($payload),
        created_at     => scalar(localtime($event->{timestamp})),
      }
    )->catch(sub ($err) {
        $self->app->log->error("Erro ao gravar no EventStore: $err");
      });
  }
  catch ($err) {
    $self->app->log->error("Falha síncrona no EventLogger: $err");
  }
}

1;
