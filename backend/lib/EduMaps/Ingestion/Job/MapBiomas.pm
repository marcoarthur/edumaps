package EduMaps::Ingestion::Job::MapBiomas;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Mojo::UserAgent;

has job_name => 'MapBiomas';
has description => 'Ingestão MapBiomas cobertura e fogo (GPKG via Geoftp)';
has schedule => 'quarterly';

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão MapBiomas (GPKG via Geoftp)');
  
  # 1. Baixa GPKG do Geoftp (collection fixa)
  my $gpkg_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.gpkg';
  my $gpkg_path = 'data/BR_Municipios_2024.gpkg';
  
  $self->download_file($gpkg_url, $gpkg_path);
  
  # 2. Processa GPKG via ogr2ogr
  $self->run_r_script('extract_mapbiomas_gpkg.R');
  
  # 3. Carrega no banco
  $self->run_r_script('load_mapbiomas_to_db.R');
  
  # 4. Fogo (mesmo processo)
  my $fogo_url = 'https://mapbiomas.org/download/collection/collection9/fogo';
  my $fogo_path = 'data/mapbiomas_fogo.gpkg';
  $self->download_file($fogo_url, $fogo_path);
  $self->run_r_script('load_mapbiomas_fogo.R');
  
  $self->log_info('MapBiomas: ingestão concluída');
}

1;