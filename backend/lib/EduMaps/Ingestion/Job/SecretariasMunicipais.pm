package EduMaps::Ingestion::Job::SecretariasMunicipais;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

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
  # #231: bloqueio conhecido -> 'nao_carregada' (exit 3). Sem tabela clean.* própria.
  $self->nao_carregada('SecretariasMunicipais: ingestão não implementada — e-SICs municipais '
    . 'ainda NÃO PROTOCOLADOS (decisão de 2026-10-13; transporte escolar por unidade/turno). '
    . 'Tracker: docs/admin/esic-requests.md.');
}

1;