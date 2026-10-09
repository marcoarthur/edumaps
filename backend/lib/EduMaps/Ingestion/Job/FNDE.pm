package EduMaps::Ingestion::Job::FNDE;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'FNDE';
has description => 'Ingestão FNDE (PNATE, Novo PAC/Proinfância, PDDE) - requer e-SIC';
has schedule => 'monthly';

sub run ($self, $args = {}) {
  # #172: stub não pode "ter sucesso" — sem e-SIC não há URL/dicionário, e um job
  # que devolve sucesso com a fonte ausente é indistinguível de um job que
  # correu e a fonte não tinha nada. Falhar alto com o motivo.
  die 'FNDE: ingestão não implementada — aguardando e-SIC (licença + URL + dicionário).
    Tracker: docs/admin/esic-requests.md. Não rodar a carga antes da resposta.'
}

1;