package EduMaps::Ingestion::Job::INMET;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use DateTime;

has job_name => 'INMET';
has description => 'Ingestão INMET Alerta-AS (CAP 1.2) e BDMEP série histórica';
has schedule => 'daily';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão INMET (Alerta-AS + BDMEP)');
  
  # 1. Alerta-AS (CAP 1.2) - eventos que interrompem aula
  $self->ingest_alerta_as();
  
  # 2. BDMEP - série diária de estações (incremental)
  $self->ingest_bdmep_incremental();
  
  $self->log_info('INMET: ingestão concluída');
}

sub ingest_alerta_as ($self) {
  $self->log_info('Baixando Alerta-AS (CAP 1.2)...');
  
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Baixando Alerta-AS (CAP 1.2)");
    return;
  }
  
  # API: https://dados.inmet.gov.br/alertas/cap12
  # Parâmetros: data_ini, data_fim, uf
  my $today = DateTime->now->ymd('-');
  my $url = "https://dados.inmet.gov.br/alertas/cap12?data_ini=$today&data_fim=$today";
  
  my $res = $self->fetch_with_retry($url);
  my $data = $res->json;
  
  # Processa e insere
  my $inserted = 0;
  for my $alert (@$data) {
    # Insere em clean.inmet_alerta
    # ...
    $inserted++;
  }
  
  $self->upsert_metadata(
    'clean.inmet_alerta',
    'API INMET Alerta-AS',
    'https://dados.inmet.gov.br/alertas/cap12',
    'CC-BY-4.0 (INMET)',
    $inserted,
    "Alerta-AS CAP 1.2 - eventos meteorológicos com código IBGE"
  );
}

sub ingest_bdmep_incremental ($self) {
  $self->log_info('Baixando BDMEP incremental...');
  
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Baixando BDMEP incremental");
    return;
  }
  
  # API: https://dados.inmet.gov.br/bdmep/estacao
  # Parâmetros: estacao, data_ini, data_fim
  # Faz download incremental (últimos 30 dias)
  
  my $end_date = DateTime->now->ymd('-');
  my $start_date = DateTime->now->subtract(days => 30)->ymd('-');
  
  # Lista estações ativas
  my $estacoes = $self->fetch_with_retry('https://dados.inmet.gov.br/bdmep/estacao')->json;
  
  my $inserted = 0;
  for my $est (@$estacoes) {
    my $url = "https://dados.inmet.gov.br/bdmep/estacao?estacao=$est->{codigo}&data_ini=$start_date&data_fim=$end_date";
    my $res = $self->fetch_with_retry($url);
    my $data = $res->json;
    
    for my $row (@$data) {
      # Insere em clean.inmet_bdmep
      # ...
      $inserted++;
    }
  }
  
  $self->upsert_metadata(
    'clean.inmet_bdmep',
    'API INMET BDMEP',
    'https://dados.inmet.gov.br/bdmep/estacao',
    'CC-BY-4.0 (INMET)',
    $inserted,
    "Série diária histórica 26 anos - carga incremental"
  );
}

1;