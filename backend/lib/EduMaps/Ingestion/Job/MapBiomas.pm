package EduMaps::Ingestion::Job::MapBiomas;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'MapBiomas';
has description => 'Ingestão MapBiomas cobertura/fogo - aguardando loader (COG público da Coleção 11, #170)';
has schedule => 'quarterly';

sub run ($self, $args = {}) {
  # #170 (parte 1): o job anterior baixava BR_Municipios_2024.gpkg (malha
  # municipal do IBGE) para uma tabela de uso do solo e descarregava uma
  # página web do MapBiomas como se fosse GPKG — o mesmo defeito da #154:
  # geometria administrativa não é cobertura de uso do solo. A API real do
  # MapBiomas exige TOKEN (e-SIC em curso): mapbiomas_cobertura fica NÃO
  # CONSTRUÍDA no schema até o acesso ser concedido. O loader real (URL
  # verificado + scripts R + areolização) continua na issue #170,
  # aguardando o e-SIC.
  # #231: 'nao_carregada' (exit 3) + motivo gravado na tabela. O re-escopo
  # de 2026-10-13 (COG público sem token, P3 da #156) ainda não tem loader.
  $self->nao_carregada('MapBiomas: ingestão não implementada — o loader antigo baixava malha do '
    . 'IBGE, não MapBiomas, e foi retirado (#170; aguardava e-SIC para token da API). '
    . 'Re-escopo de 2026-10-13: COG público sem token, loader novo na fase P3 da #156. '
    . 'mapbiomas_cobertura declarada NÃO CONSTRUÍDA no schema.');
}

sub tabelas ($self, $args = {}) { return ('clean.mapbiomas_cobertura') }

1;
