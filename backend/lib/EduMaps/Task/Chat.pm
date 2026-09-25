package EduMaps::Task::Chat;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;

# Normaliza valores que o Plumber (R) serializa como arrays de 1 elemento
# para escalares. Ex.: [1] -> 1, ["SELECT ..."] -> "SELECT ...".
sub _scalar ($v) {
  return $v->[0] if ref $v eq 'ARRAY' && @$v == 1;
  return $v;
}

# Task do Assistente do Censo (chat NL->SQL sobre o Censo Escolar). O trabalho
# pesado (LLM) roda no job, que chama o Plumber (POST /ask) via
# EduMaps::Analytics::Client — com cache read-through em
# analytics.analysis_cache, o que também serve de fallback quando o provedor de
# LLM está lento/indisponível.
sub register ($self, $app, $config) {
  $app->minion->add_task(
    chat_ask => task {
      sub   => \&_chat_ask,
      roles => { '+Progress' => { log => $app->log } },
    }
  );

  $app->helper(ask_censo  => \&_enqueue_chat);
  $app->helper(monitor_chat => \&_monitor_chat);
}

sub _chat_ask ($job, $args) {
  my $pergunta = $args->{pergunta};
  my $contexto = $args->{contexto} // {};

  $job->progress(5, 'Consultando o assistente...');

  # Config global do Assistente (Painel de Configuração) — apenas campos
  # definidos são enviados; os demais usam os defaults do R.
  my $config = $job->app->model('AppConfig')->chat_llm_config || {};

  my $result;
  try {
    $result = $job->app->analytics->run_chat({
      pergunta => $pergunta,
      contexto => $contexto,
      config   => $config,
    });
  } catch ($err) {
    $job->app->log->error("Falha no Assistente do Censo: $err");
    return $job->fail({ error => "$err" });
  }

  my $cache_hit = $result->{cache_hit} ? 1 : 0;
  my $linhas    = _scalar($result->{linhas} // 0);

  $job->progress(100, $cache_hit
    ? "Resposta do cache ($linhas linha(s))"
    : "Resposta gerada ($linhas linha(s))");

  $job->finish({
    cache_hit => $cache_hit,
    pergunta  => $pergunta,
    contexto  => $contexto,
    resposta  => _scalar($result->{resposta}),
    sql       => _scalar($result->{sql}),
    linhas    => $linhas,
    colunas   => _scalar($result->{colunas}),
    origem    => $result->{origem},
    resultado => $result->{resultado},
    chart     => $result->{chart},
  });
}

sub _enqueue_chat ($app, $args) {
  return $app->minion->enqueue(
    chat_ask => [$args] => { queue => 'analytics' }
  );
}

sub _monitor_chat ($c, $job_id) {
  $c->monitor_job(
    {
      job_id    => $job_id,
      poll_time => 1,
      on_finish => sub { $c->log->info("job $job_id (chat) finalizado") },
    }
  );
}

1;
