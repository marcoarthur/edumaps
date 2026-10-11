package EduMaps::Channel::Operacoes;
use Mojo::Base -base, -signatures;
use utf8;

# ============================================================================
# OPERAÇÕES (MOTIVO) DE UMA MENSAGEM DE CANAL — FONTE ÚNICA DE VERDADE
# ============================================================================
#
# A operação responde "a que se refere esta mensagem" no histórico de envio
# (clean.canal_mensagens.operacao): aviso, informação, pedido, convite,
# confirmação, lembrete, alerta. Esta lista é espelhada no CHECK da tabela:
# adicionar uma operação nova exige mudar aqui E no CHECK (nova migration) —
# a mesma disciplina de `EduMaps::Bots::Policy::Actions`.

my @OPERACOES = qw(
  aviso
  informacao
  pedido
  convite
  confirmacao
  lembrete
  alerta
);

sub available ($class) { return [@OPERACOES] }

sub is_valid ($class, $operacao) {
  return 0 unless defined $operacao && !ref $operacao;
  return scalar(grep { $_ eq $operacao } @OPERACOES) ? 1 : 0;
}

1;
