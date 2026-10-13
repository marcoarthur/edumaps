package EduMaps::Ingestion::NaoCarregada;
use Mojo::Base -base, -signatures;
use utf8;

# ---------------------------------------------------------------------------
# Exceção "fonte NÃO CARREGADA por bloqueio conhecido" (#231)
# ---------------------------------------------------------------------------
#
# Distingue dois desfechos que antes eram o mesmo `die`:
#
#   falhou         — o job tentou e quebrou (rede, dado, bug). Erro.
#   nao_carregada  — o job sabe, ANTES de tentar, que não pode carregar:
#                    e-SIC não protocolado, API retirada (INMET, #171),
#                    fonte fora do objetivo por decisão do developer (ANTT,
#                    isócronas). Não é bug, mas também NÃO é sucesso.
#
# O job lança com `$self->nao_carregada($motivo)` (Base.pm). O Runner apanha,
# grava `ultimo_status = 'nao_carregada'` + motivo em clean.import_metadata
# para as tabelas do job (sem tocar na proveniência da última carga boa) e o
# CLI sai com o código 3 — distinto de sucesso (0) e de falha (1). Nunca há
# sucesso silencioso.
#
# Stringifica como "[NAO_CARREGADA] <motivo>", para quem só lê `$@`.

use overload
  '""'     => sub ($self, @) { '[NAO_CARREGADA] ' . $self->motivo },
  'bool'   => sub { 1 },
  fallback => 1;

has motivo => '';
has job    => '';

sub throw ($class, %args) { die $class->new(%args) }

1;
