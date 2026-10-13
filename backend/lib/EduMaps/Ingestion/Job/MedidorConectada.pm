package EduMaps::Ingestion::Job::MedidorConectada;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'MedidorConectada';
has description => 'Ingestão Medidor Educação Conectada (MEC/NIC.br) - requer e-SIC';
has schedule => 'quarterly';

sub run ($self, $args = {}) {
  # #172: stub não pode "ter sucesso" — sem e-SIC não há CSV/dicionário, e um job
  # que devolve sucesso com a fonte ausente é indistinguível de um job que
  # correu e a fonte não tinha nada. Falhar alto com o motivo.
  # #231: bloqueio conhecido -> 'nao_carregada' (exit 3). Sem tabela clean.* própria.
  $self->nao_carregada('MedidorConectada: ingestão não implementada — e-SIC ainda NÃO PROTOCOLADO '
    . '(decisão de 2026-10-13; CSV + dicionário + licença). '
    . 'Tracker: docs/admin/esic-requests.md. Não rodar a carga antes da resposta.');
}

1;