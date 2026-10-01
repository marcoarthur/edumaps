package EduMaps::Ingestion::Job::INEP;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'INEP';
has description => 'Ingestão INEP (Censo Escolar, IDEB, ENEM) - requer e-SIC';
has schedule => 'annual';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão INEP (aguardando e-SIC para licença)...');
  
  # Aguarda licença ser confirmada via e-SIC
  # Enquanto isso, prepara estrutura
  
  $self->log_info('INEP: aguardando resposta de e-SIC para licença');
}

1;