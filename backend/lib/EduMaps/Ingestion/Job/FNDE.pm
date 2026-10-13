package EduMaps::Ingestion::Job::FNDE;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

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
  # #231: bloqueio conhecido -> 'nao_carregada' (exit 3), não falha nem sucesso.
  # Sem tabela clean.* própria: o estado fica só no resultado do runner.
  $self->nao_carregada('FNDE: ingestão não implementada — e-SIC ainda NÃO PROTOCOLADO '
    . '(decisão de 2026-10-13; licença + URL + dicionário). '
    . 'Tracker: docs/admin/esic-requests.md. Não rodar a carga antes da resposta.');
}

1;