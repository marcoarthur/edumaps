package EduMaps::Task::Ivet;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use utf8;

# Task de refresh do IVET materializado (#296): mede o painel nacional no
# serviço analítico (Plumber/edumapsr, POST /ivet/refresh) e grava em
# analytics.ivet_escola. A lógica de cálculo vive SÓ no edumapsr — aqui é
# só enfileiramento + orçamento de tempo (o painel nacional completo
# roda em minutos; o job não pode cair no timeout default do Minion).

use constant {
  DEFAULT_CENSO_ANO => 2025,
  DEFAULT_RAIO_M    => 1000,
};

sub register ($self, $app, $config) {
  $app->minion->add_task(
    refresh_ivet => task {
      sub   => \&_refresh_ivet,
      roles => {'+Progress' => {log => $app->log}},
    }
  );

  # Helper: enfileira o refresh na fila 'analytics' (administrativo/
  # agendado — disparado manualmente ou por cron, nunca por requisição).
  $app->helper(
    apply_ivet_refresh => sub ($c, $args = {}) {
      return $app->minion->enqueue(
        refresh_ivet => [$args] => { queue => 'analytics' }
      );
    }
  );
}

sub _refresh_ivet ($job, $args) {
  my $app   = $job->app;
  my $v     = $app->validator->validation;
  my $start = localtime;

  $v->input($args);
  $v->optional('censo_ano', 'trim')->like(qr/^\d{4}$/);
  $v->optional('raio_m', 'trim')->like(qr/^\d+$/);

  return $job->fail("Argumentos inválidos fornecidos para refresh_ivet!")
    if $v->has_error;

  $args->{censo_ano} //= DEFAULT_CENSO_ANO;
  $args->{raio_m}    //= DEFAULT_RAIO_M;

  my $engine = $app->analytics_engine;
  return $job->fail("refresh_ivet exige analytics_engine=http (recebi '$engine')")
    unless $engine eq 'http';

  my $r_out;
  try {
    $r_out = $app->analytics->run_ivet_refresh($args);
  } catch ($err) {
    return $job->fail("Erro no refresh do IVET: $err");
  }

  my $end = localtime;
  $job->finish({
    meta => {
      name    => 'refresh_ivet',
      job_id  => $job->id,
      censo_ano => $args->{censo_ano},
      raio_m    => $args->{raio_m},
      took    => $end - $start,
    },
    ivet => $r_out,
  });
}

1;

__END__

=encoding utf8

=head1 NAME

EduMaps::Task::Ivet - Refresh do IVET materializado (#296)

=head1 DESCRIPTION

Task Minion C<refresh_ivet> (fila C<analytics>): mede o painel nacional do
IVET no serviço analítico (Plumber/edumapsr, C<POST /ivet/refresh> →
C<ivet_refresh()>) e materializa em C<analytics.ivet_escola>. A lógica de
cálculo continua só no edumapsr; a tabela guarda o resultado vigente por
C<dt_snapshot> (histórico por dia de refresh).

Deve rodar após cada carga que alimenta os blocos do IVET (censo, scores,
isócrona, etc.). Sem argumentos usa censo 2025 e raio 1000 m.

=head1 SYNOPSIS

    $c->apply_ivet_refresh();                          # defaults
    $c->apply_ivet_refresh({ censo_ano => 2025 });     # explícito

=cut
