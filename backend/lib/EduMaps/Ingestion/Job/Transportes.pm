package EduMaps::Ingestion::Job::Transportes;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'Transportes';
has description => 'Ingestão RENAVAM frota + RENAEST sinistros';
has schedule => 'monthly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão Transportes (RENAVAM + RENAEST)');
  
  $self->ingest_renavam_frota();
  $self->ingest_renatest_sinistro();
  
  $self->log_info('Transportes: ingestão concluída');
}

sub ingest_renavam_frota ($self) {
  $self->log_info('Baixando RENAVAM frota agregada...');
  
  # Dataset: frota-por-municipio
  $self->download_file(
    'https://dados.transportes.gov.br/dataset/frota-por-municipio',
    'data/renavam_frota.zip'
  );
  
  # Extrai ZIP, processa CSV mensal, carrega
  # ...
}

sub ingest_renatest_sinistro ($self) {
  # RENAEST sinistros por localidade
  # Requer de-para localidade -> município
  # ...
}

1;