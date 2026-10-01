package EduMaps::Ingestion::Job::BrazilCrime;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Text::CSV;

has job_name => 'BrazilCrime';
has description => 'Ingestão BrazilCrime (criminalidade municipal via CRAN)';
has schedule => 'monthly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão BrazilCrime via CRAN');
  
  # 1. Instala/atualiza pacote R BrazilCrime
  $self->run_r_script('install_brazilcrime.R');
  
  # 2. Executa script de extração
  my $output = $self->run_r_script('extract_brazilcrime.R');
  
  # 3. Processa CSV gerado
  my $csv_path = 'data/brazilcrime_municipio.csv';
  my $rows = $self->process_csv($csv_path);
  
  # 4. Carrega no banco
  my $loaded = $self->load_to_db('clean.brazilcrime_municipio', $rows);
  
  # 5. Atualiza metadados
  $self->upsert_metadata(
    'clean.brazilcrime_municipio',
    'BrazilCrime CRAN package',
    'https://cran.r-project.org/package=BrazilCrime',
    'GPL-3',
    $loaded,
    "Ingestão automática via CRAN package BrazilCrime"
  );
  
  $self->log_info("BrazilCrime: $loaded registros carregados");
}

sub process_csv ($self, $csv_path) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Processando CSV: $csv_path");
    return [];
  }
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
  open my $fh, '<:encoding(utf8)', $csv_path or die "Não abriu $csv_path: $!";
  my @rows;
  while (my $row = $csv->getline($fh)) {
    push @rows, $row;
  }
  close $fh;
  return \@rows;
}

sub load_to_db ($self, $table, $rows) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Carregando " . scalar(@$rows) . " linhas em $table");
    return scalar @$rows;
  }
  my $db = $self->app->schema->storage->dbh;
  my $loaded_count = 0;
  my $sth = $db->prepare(q{
    INSERT INTO clean.brazilcrime_municipio
    (codigo_ibge, ano, homicidio_doloso, homicidio_culposo, latrocinio,
     roubo_veiculo, roubo_carga, roubo_outros, furto_veiculo, furto_outros,
     estelionato, ameaca, lesao_corporal, violacao_domicilio,
     supressao_celula_pequena, dt_snapshot)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_DATE)
    ON CONFLICT (codigo_ibge, ano, dt_snapshot) DO UPDATE SET
      homicidio_doloso = EXCLUDED.homicidio_doloso,
      homicidio_culposo = EXCLUDED.homicidio_culposo,
      latrocinio = EXCLUDED.latrocinio,
      roubo_veiculo = EXCLUDED.roubo_veiculo,
      roubo_carga = EXCLUDED.roubo_carga,
      roubo_outros = EXCLUDED.roubo_outros,
      furto_veiculo = EXCLUDED.furto_veiculo,
      furto_outros = EXCLUDED.furto_outros,
      estelionato = EXCLUDED.estelionato,
      ameaca = EXCLUDED.ameaca,
      lesao_corporal = EXCLUDED.lesao_corporal,
      violacao_domicilio = EXCLUDED.violacao_domicilio,
      supressao_celula_pequena = EXCLUDED.supressao_celula_pequena,
      dt_snapshot = CURRENT_DATE
  });
  
  my $count = 0;
  for my $row (@$rows) {
    $sth->execute(@$row{qw(codigo_ibge ano homicidio_doloso homicidio_culposo latrocinio
        roubo_veiculo roubo_carga roubo_outros furto_veiculo furto_outros
        estelionato ameaca lesao_corporal violacao_domicilio
        supressao_celula_pequena)});
    $count++;
  }
  return $count;
}

1;