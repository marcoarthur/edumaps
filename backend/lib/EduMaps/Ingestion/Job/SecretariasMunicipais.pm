package EduMaps::Ingestion::Job::SecretariasMunicipais;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'SecretariasMunicipais';
has description => 'e-SICs municipais para transporte escolar por unidade';
has schedule => 'annual';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando e-SICs municipais para transporte escolar...');
  
  # Itera lista de municípios prioritários
  # Para cada: protocola e-SIC municipal, aguarda resposta
  # ...
}

1;