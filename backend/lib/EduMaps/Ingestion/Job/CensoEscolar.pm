package EduMaps::Ingestion::Job::CensoEscolar;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'CensoEscolar';
has description => 'Carga completa Censo Escolar (microdados INEP)';
has schedule => 'annual';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando carga Censo Escolar (microdados INEP)');
  
  # Baixa ZIPs anuais do INEP
  # Processa CSV -> COPY para tabelas clean.censo_escolas, censo_docentes, etc.
  # ...
}

1;