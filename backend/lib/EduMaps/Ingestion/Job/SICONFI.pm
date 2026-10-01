package EduMaps::Ingestion::Job::SICONFI;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'SICONFI';
has description => 'Ingestão SICONFI (receitas/despesas) + CGU Transparência';
has schedule => 'monthly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão SICONFI + CGU Transparência');
  
  $self->ingest_siconfi_receita();
  $self->ingest_siconfi_despesa();
  $self->ingest_cgu_transferencias();
  
  $self->log_info('SICONFI/CGU: ingestão concluída');
}

sub ingest_siconfi_receita ($self) {
  # API: https://tesouror.transparencia.gov.br/api/v1/receitas
  # Parâmetros: exercicio, id_ente, tipo_receita
  # ...
}

sub ingest_siconfi_despesa ($self) {
  # API: https://tesouror.transparencia.gov.br/api/v1/despesas
  # Função 12 = Educação, subfunções 361-365
  # ...
}

sub ingest_cgu_transferencias ($self) {
  # API: https://api.portaldatransparencia.gov.br/api-de-dados/transferencias
  # WAF intermitente (405) -> retry com backoff
  # Job noturno com cache
  # ...
}

1;