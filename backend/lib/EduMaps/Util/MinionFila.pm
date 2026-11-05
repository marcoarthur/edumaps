package EduMaps::Util::MinionFila;
use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(minion_fila);

# Fila Minion de uma task: `minion_filas => { <task> => '<fila>' }` no config
# da aplicação; sem entrada, `default` (a fila que o worker consome).
#
# Existe para os testes: eles rodam no mesmo banco que o minion local, que
# consome a `default` e pegava os jobs que o teste enfileirava. Com uma fila
# própria no config do teste, só o `perform_jobs({queues => [...]})` do teste
# executa esses jobs. Em produção nada é configurado e tudo segue na `default`.
#
# `gestor_senha_fila` (#336) continua aceito como sinônimo para
# `minion_filas.gestor_senha_email`.
sub minion_fila {
  my ($app, $task) = @_;
  my $cfg   = $app->config // {};
  my $filas = ref $cfg->{minion_filas} eq 'HASH' ? $cfg->{minion_filas} : {};
  return $filas->{$task}
      // ($task eq 'gestor_senha_email' ? $cfg->{gestor_senha_fila} : undef)
      // 'default';
}

1;
