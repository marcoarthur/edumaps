package EduMaps::Ingestion::Job::ANTT;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Text::CSV;

has job_name => 'ANTT';
has description => 'Ingestão ANTT (OD, Acidentes, Trechos, Contagem)';
has schedule => 'monthly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão ANTT (OD, Acidentes, Trechos, Contagem)');
  
  $self->ingest_od_municipio();
  $self->ingest_acidentes_trecho();
  $self->ingest_trecho_geodados();
  $self->ingest_contagem_equipamento();
  
  $self->log_info('ANTT: ingestão concluída');
}

sub ingest_od_municipio ($self) {
  $self->log_info('Baixando ANTT MONITRIIP OD...');
  
  # Dataset: monitriip-servico-regular
  # CSV ISO-8859-1, delimitador ;
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Baixando ANTT MONITRIIP OD");
    return;
  }
  $self->download_file('https://dados.antt.gov.br/dataset/monitriip-servico-regular', 'data/antt_od.csv');
  $self->process_antt_od_csv('data/antt_od.csv');
}

sub process_antt_od_csv ($self, $csv_path) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Processando CSV ANTT OD: $csv_path");
    return;
  }
  # CSV ISO-8859-1, delimitador ;
  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', encoding => 'iso-8859-1' });
  open my $fh, '<:encoding(iso-8859-1)', $csv_path or die "Não abriu $csv_path: $!";
  
  my $header = $csv->getline($fh);
  my $sth = $self->app->schema->storage->dbh->prepare(q{
    INSERT INTO clean.antt_od_municipio
    (codigo_ibge_origem, codigo_ibge_destino, mes_viagem, quantidade_bilhetes, supressao_aplicada, dt_snapshot)
    VALUES (?, ?, ?, ?, ?, CURRENT_DATE)
    ON CONFLICT (codigo_ibge_origem, codigo_ibge_destino, mes_viagem, dt_snapshot) DO UPDATE SET
      quantidade_bilhetes = EXCLUDED.quantidade_bilhetes,
      supressao_aplicada = EXCLUDED.supressao_aplicada,
      dt_snapshot = CURRENT_DATE
  });
  
  my $inserted = 0;
  while (my $row = $csv->getline($fh)) {
    # Supressão obrigatória: quantidade_bilhetes < 10
    my $qtd = $row->{quantidade_bilhetes} // 0;
    my $supressao = $qtd < 10 ? 1 : 0;
    $qtd = 0 if $supressao;  # Zera se suprimido
    
    # tipo_gratuidade FORA da camada analítica (não carrega)
    
    $sth->execute(
      $row->{codigo_ibge_origem},
      $row->{codigo_ibge_destino},
      $row->{mes_viagem},
      $qtd,
      $supressao ? 1 : 0
    );
    $inserted++;
  }
  
  $self->upsert_metadata(
    'clean.antt_od_municipio',
    'ANTT MONITRIIP CSV',
    'https://dados.antt.gov.br/dataset/monitriip-servico-regular',
    'CC-BY-4.0 (ANTT)',
    $inserted,
    "Matriz OD município×município×mês. Supressão count<10 obrigatória. tipo_gratuidade excluído."
  );
}

sub ingest_acidentes_trecho ($self) {
  $self->log_info('Processando acidentes ANTT...');
  
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Processando acidentes ANTT");
    return;
  }
  
  # Dataset: acidentes
  $self->download_file('https://dados.antt.gov.br/dataset/acidentes', 'data/antt_acidentes.csv');
  $self->process_antt_acidentes_csv('data/antt_acidentes.csv');
}

sub ingest_trecho_geodados ($self) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Processando trechos ANTT");
    return;
  }
  
  # Processa dataset trechos (geodados com município)
  $self->log_info('Processando trechos ANTT...');
  
  $self->download_file('https://dados.antt.gov.br/dataset/trechos', 'data/antt_trechos.gpkg');
  # Processa GPKG via ogr2ogr
  $self->run_r_script('process_antt_trechos_gpkg.R');
}

sub ingest_contagem_equipamento ($self) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Processando contagem de equipamentos ANTT");
    return;
  }
  
  # KMZ -> GPKG -> carga
  $self->log_info('Processando contagem de equipamentos ANTT...');
  
  $self->download_file('https://dados.antt.gov.br/dataset/contagem-equipamentos', 'data/antt_contagem.kmz');
  # Converte KMZ para GPKG
  $self->run_r_script('convert_kmz_to_gpkg.R');
  $self->run_r_script('load_antt_contagem.R');
}

1;