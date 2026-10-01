package EduMaps::Ingestion::Job::MedidorConectada;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'MedidorConectada';
has description => 'Ingestão Medidor Educação Conectada (MEC/NIC.br) - requer e-SIC';
has schedule => 'quarterly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão Medidor Educação Conectada (aguardando e-SIC)...');
  
  # Aguarda e-SIC para CSV + dicionário + licença
  # ...
}

1;