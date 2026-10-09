package EduMaps::Ingestion::Job::SecretariasMunicipais;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'SecretariasMunicipais';
has description => 'e-SICs municipais para transporte escolar por unidade';
has schedule => 'annual';

sub run ($self, $args = {}) {
  # #172: stub não pode "ter sucesso" — sem resposta das secretarias não há dado,
  # e um job que devolve sucesso com a fonte ausente é indistinguível de um job
  # que correu e a fonte não tinha nada. Falhar alto com o motivo.
  die 'SecretariasMunicipais: ingestão não implementada — aguardando e-SICs municipais
    (transporte escolar por unidade/turno). Tracker: docs/admin/esic-requests.md.'
}

1;