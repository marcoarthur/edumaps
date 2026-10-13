package EduMaps::Ingestion::Job::INEP;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;

has job_name => 'INEP';
has description => 'Ingestão INEP (Censo Escolar, IDEB, ENEM) - requer e-SIC';
has schedule => 'annual';

sub run ($self, $args = {}) {
  # #172: stub não pode "ter sucesso" — sem licença confirmada não há carga do
  # Censo/IDEB/ENEM, e um job que devolve sucesso com a fonte ausente é
  # indistinguível de um job que correu e a fonte não tinha nada. Falhar alto
  # com o motivo. (O Censo Escolar já carregado veio por outro caminho e não
  # depende deste job — ver `clean.censo_escolas`/`censo_docentes`.)
  # #231: bloqueio conhecido -> 'nao_carregada' (exit 3). `tabelas` fica vazio
  # DE PROPÓSITO: censo_escolas/censo_docentes/... já têm carga por outro
  # caminho, e marcar a última tentativa deles como 'nao_carregada' por causa
  # deste stub confundiria quem lê o import_metadata.
  $self->nao_carregada('INEP: ingestão não implementada — e-SIC ainda NÃO PROTOCOLADO '
    . '(decisão de 2026-10-13; licença do Censo/IDEB/ENEM). '
    . 'Tracker: docs/admin/esic-requests.md. Não rodar a carga antes da resposta.');
}

1;