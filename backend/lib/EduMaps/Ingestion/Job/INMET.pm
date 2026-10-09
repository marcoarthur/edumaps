package EduMaps::Ingestion::Job::INMET;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'INMET';
has description => 'Ingestão INMET (BDMEP + Alerta-AS) - NÃO CONSTRUÍDA (decisão #171 C)';
has schedule => 'daily';

sub run ($self, $args = {}) {
  # #171 (decisão C): a API do INMET foi retirada — dados.inmet.gov.br não
  # resolve (sem registo A), apitempo.inmet.gov.br/bdmep/estacao e
  # /alertas/cap12 dão 404, e os restantes hosts são interface web ou feed
  # RSS. Sem loader para endpoints mortos: inmet_bdmep/inmet_alerta ficam
  # NÃO CONSTRUÍDAS no schema (COMMENT ON TABLE, change
  # comments_inmet_mapbiomas_pendente). O RSS de avisos não alimenta as
  # tabelas pretendidas (séries históricas por estação + alertas CAP).
  # Falhar sempre com o motivo — revisitar se o INMET publicar API/feed
  # oficial de novo.
  die 'INMET: ingestão não implementada — decisão #171 (C): a API do INMET foi
    retirada (endpoints mortos). Tabelas inmet_bdmep/inmet_alerta declaradas
    NÃO CONSTRUÍDAS no schema.'
}

1;
