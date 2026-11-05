package ConfigSnapshot;
use strict;
use warnings;
use utf8;
use DBD::Pg ();

# Fotografia da config (app_config.items) para os testes.
#
# Os testes rodam contra o mesmo banco que a stack local usa e mexem em
# faixas da config (canais.inscricao.%, canais.envio.% ...). Sem restaurar,
# cada rodada da suíte apagava a config de verdade do ambiente (SMTP do
# Mailpit, bot, WhatsApp).
#
#   use ConfigSnapshot;
#   ConfigSnapshot::guardar($dbh, 'canais.inscricao.%', 'canais.envio.%');
#
# Chamar ANTES da primeira escrita ou limpeza do teste. No fim do processo, o
# END deste módulo apaga as faixas e devolve as linhas como estavam (todas as
# colunas, inclusive o segredo cifrado). Como o módulo é compilado antes do
# corpo do teste, o END dele roda depois dos END do teste, ou seja, depois
# das limpezas que o próprio teste faz.

my @COLUNAS = qw(key value secret secret_key_version sensitive updated_by updated_at);
my @FOTOS;   # { dbh, padroes, linhas }

sub guardar {
  my ($dbh, @padroes) = @_;
  die "ConfigSnapshot::guardar: informe ao menos um padrão LIKE\n" unless @padroes;
  return unless $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
  my $cols   = join ', ', @COLUNAS;
  my $filtro = join ' OR ', ('key LIKE ?') x @padroes;
  my $linhas = $dbh->selectall_arrayref(
    "SELECT $cols FROM app_config.items WHERE $filtro", {}, @padroes);
  push @FOTOS, { dbh => $dbh, padroes => [@padroes], linhas => $linhas };
  return scalar @$linhas;
}

sub restaurar {
  # do último para o primeiro: se duas fotos cobrem a mesma chave, vale a
  # mais antiga (o estado de antes do teste)
  while (my $f = pop @FOTOS) {
    my $dbh = $f->{dbh};
    my $ok = eval {
      local $dbh->{RaiseError} = 1;
      local $dbh->{PrintError} = 0;
      my $filtro = join ' OR ', ('key LIKE ?') x @{ $f->{padroes} };
      $dbh->do("DELETE FROM app_config.items WHERE $filtro", {}, @{ $f->{padroes} });
      my $ph  = join ', ', ('?') x @COLUNAS;
      my $sth = $dbh->prepare(sprintf 'INSERT INTO app_config.items (%s) VALUES (%s)',
        join(', ', @COLUNAS), $ph);
      for my $l (@{ $f->{linhas} }) {
        $sth->bind_param($_ + 1, $l->[$_]) for 0 .. $#$l;
        # secret é bytea: precisa do tipo explícito para não corromper bytes
        $sth->bind_param(3, $l->[2], { pg_type => DBD::Pg::PG_BYTEA() });
        $sth->execute;
      }
      1;
    };
    warn "ConfigSnapshot: falha ao restaurar a config: $@" unless $ok;
  }
}

sub pendentes { scalar @FOTOS }

END { local $?; restaurar() }

1;
