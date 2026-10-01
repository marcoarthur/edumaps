package EduMaps::Ingestion::Job::FNDE;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'FNDE';
has description => 'Ingestão FNDE (PNATE, Novo PAC/Proinfância, PDDE) - requer e-SIC';
has schedule => 'monthly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão FNDE (aguardando e-SIC para licença)...');
  
  # Aguarda e-SIC para licença + URL + dicionário
  # ...
}

1;