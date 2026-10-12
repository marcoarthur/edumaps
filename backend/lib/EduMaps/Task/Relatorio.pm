package EduMaps::Task::Relatorio;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use Syntax::Keyword::Try;
use Scalar::Util qw(blessed);
use Mojo::JSON ();
use Minion::Task::Generator qw/task/;

# Assistente de Relatório (#219). A task `relatorio_gerar` roda na fila
# `analytics` (o mesmo worker do Assistente do Censo) e chama o Plumber
# (POST /report, com o `assistente` dos args — Fase 4) via EduMaps::Analytics::Client — com cache read-through de
# 24 h em analytics.analysis_cache. O resultado do job é o ReportResult do R
# acrescido de `cache_hit` (booleano JSON).
#
# Erros:
#   - 400 do R (tema/nível/geotag/opção inválidos, eduBR ausente): o job
#     falha com a mensagem do R, que é dirigida ao usuário;
#   - qualquer outro (conexão, 5xx, resposta inválida): mensagem genérica —
#     o detalhe vai só para o log, nunca para o cliente.

use constant ERRO_GENERICO =>
  'Não foi possível gerar o relatório agora. Tente novamente em alguns minutos.';

sub register ($self, $app, $config) {
  $app->minion->add_task(
    relatorio_gerar => task {
      sub   => \&_relatorio_gerar,
      roles => { '+Progress' => { log => $app->log } },
    }
  );

  $app->helper(gerar_relatorio => \&_enqueue);
}

sub _relatorio_gerar ($job, $args) {
  my $app = $job->app;

  $job->progress(5, 'Preparando o relatório...');

  # Config global do LLM (Painel de Configuração), a mesma do Assistente do
  # Censo — campos não definidos usam os defaults do R.
  my $config = $app->model('AppConfig')->chat_llm_config || {};

  $job->progress(15, 'Consultando os dados e redigindo o relatório...');

  my $result;
  try {
    $result = $app->analytics->run_report({
      geotag     => $args->{geotag},
      assistente => $args->{assistente},    # undef (jobs antigos) = relatorio
      tema       => $args->{tema},
      opcoes     => $args->{opcoes} // {},
      contexto   => { cod_inep => $args->{cod_inep} },
      config     => $config,
    });
  } catch ($err) {
    $app->log->error("Falha no Assistente de Relatório: $err");
    if (blessed $err && $err->can('code') && ($err->code // 0) == 400) {
      return $job->fail({ error => $err->message // ERRO_GENERICO });
    }
    return $job->fail({ error => ERRO_GENERICO });
  }

  unless (ref $result eq 'HASH') {
    $app->log->error('Assistente de Relatório: resposta do R não é um objeto');
    return $job->fail({ error => ERRO_GENERICO });
  }

  my $cache_hit = $result->{cache_hit} ? 1 : 0;

  $job->progress(100, $cache_hit ? 'Relatório do cache' : 'Relatório gerado');

  $job->finish({
    %$result,
    cache_hit => $cache_hit ? Mojo::JSON::true : Mojo::JSON::false,
  });
}

# Enfileira na fila `analytics` (configurável por `relatorio_queue`, para os
# testes não concorrerem com o worker real).
sub _enqueue ($c, $args) {
  my $queue = $c->app->config->{relatorio_queue} // 'analytics';
  return $c->app->minion->enqueue(
    relatorio_gerar => [$args] => { queue => $queue }
  );
}

1;
