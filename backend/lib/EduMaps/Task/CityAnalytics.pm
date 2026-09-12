package EduMaps::Task::CityAnalytics;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use EduMaps::Analysis::R::Pipe;
use Time::Piece;
use utf8;

use constant {
  STAGING_SCHEMA   => 'staging',
  ANALYTICS_SCHEMA => 'analytics',
  DB_SERVICE       => 'edumaps_local',
  DEFAULT_ANALYSIS => 'full_summary',
};

# Fonte única de verdade: tipo de análise -> nome da função R correspondente
use constant ANALYSIS_R_FUNCTION => {
  full_summary       => 'compute_and_save_city_summary',
  score_distribution => 'compute_and_save_score_distributions',
  school_clusters    => 'compute_and_save_school_clusters',
};

# Validações específicas para cada modalidade analítica
my %ANALYSIS_VALIDATORS = (
  full_summary       => sub ($v) {},
  score_distribution => sub ($v) {
    $v->optional('target_grade_col', 'trim')->like(qr/^\w+$/);
  },
  school_clusters    => sub ($v) {
    $v->optional('k_clusters', 'trim')->like(qr/^\d+$/);
    $v->optional('features', 'trim');
  },
);

sub register ($self, $app, $config) {
  # Registra a task no Minion
  $app->minion->add_task(
    city_analytics => task {
      sub   => \&_apply_city_analytics,
      roles => {'+Progress' => {log => $app->log}},
    }
  );

  # Helper com regras de idempotência e desduplicação
  $app->helper(
    apply_city_analytics => sub ($c, $args) {
      my $cod_ibge = $args->{codigo_ibge};
      return unless $cod_ibge;

      my $analysis  = $args->{analysis} // DEFAULT_ANALYSIS;
      my $cache_key = "edumaps:analytics:city:${cod_ibge}:${analysis}";

      # 1. Idempotência via Cache (CHI): Se já está calculado e em cache, ignora
      if ($app->chi && $app->chi->get($cache_key)) {
        $app->log->debug("[CityAnalytics] Cache HIT para $cache_key. Enfileiramento ignorado.");
        return;
      }

      # 2. Desduplicação de Jobs: Evita enfileirar se houver um job ativo ou inativo para o mesmo IBGE
      # Minion
      my $jobs = $app->minion->jobs({
          tasks  => ['city_analytics'],
          states => ['inactive', 'active'],
          notes  => [$cod_ibge], 
        });
      if ($jobs->total > 0) {
        $app->log->debug("[CityAnalytics] Job já pendente/em execução no Minion para IBGE $cod_ibge.");
        return;
      }

      # 3. Enfileiramento em fila dedicada 'speculative' com baixa prioridade
      # #Minion
      return $app->minion->enqueue(
        city_analytics => [$args] => {
          queue    => 'speculative',
          priority => 0, # Baixa prioridade em relação às requisições diretas de usuários
          notes    => { codigo_ibge => $cod_ibge, analysis => $analysis }
        }
      );
    }
  );
}

sub _apply_city_analytics ($job, $args) {
  my $app   = $job->app;
  my $v     = $app->validator->validation;
  my $start = localtime;
  my $rpipe = EduMaps::Analysis::R::Pipe->new;

  my $analysis = $args->{analysis} // DEFAULT_ANALYSIS;

  $v->input($args);
  $v->required('codigo_ibge', 'trim')->like(qr/^\d{7}$/); # Valida padrão IBGE 7 dígitos
  $v->optional('schema',      'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('db_service',  'trim')->like(qr/^\w+$/);
  $v->optional('source_file', 'trim')->like(qr/^\w+$/);
  $v->optional('analysis',    'trim')->in(sort keys %{ +ANALYSIS_R_FUNCTION() });

  return $job->fail("Análise inválida: '$analysis'")
  unless exists ANALYSIS_R_FUNCTION->{$analysis};

  ($ANALYSIS_VALIDATORS{$analysis} // sub {})->($v);

  return $job->fail("Argumentos inválidos fornecidos para CityAnalytics!") if $v->has_error;

  # Defaults gerais
  $args->{analysis}    = $analysis;
  $args->{schema}    //= STAGING_SCHEMA;
  $args->{db_service}//= DB_SERVICE;
  $args->{source_file}//= 'city_analytics';

  my $r_function = ANALYSIS_R_FUNCTION->{$analysis};
  my $cod_ibge   = $args->{codigo_ibge};

  my $r_out;
  try {
    $r_out = $rpipe->run(
      {
        paths       => $args->{paths} || $app->renderer->paths,
        source_file => $args->{source_file} . '.R',
        script      => <<~"EOS",
        ${r_function}(
          con           = dbConnect(RPostgres::Postgres(), service = "$args->{db_service}"),
          schema        = "$args->{schema}",
          codigo_ibge   = "$cod_ibge",
          output_schema = "@{[ ANALYTICS_SCHEMA ]}"
        )
        EOS
      }
    );
  } catch ($err) {
    return $job->fail("Erro na execução do script R ($analysis) para IBGE $cod_ibge: $err");
  }

  # Atualiza o cache CHI ao finalizar o processamento com sucesso
  my $cache_key = "edumaps:analytics:city:${cod_ibge}:${analysis}";
  if ($app->chi) {
    $app->chi->set($cache_key, $r_out, '24 hours');
  }

  my $end = localtime;
  $job->finish(
    {
      meta => {
        name        => 'city_analytics',
        job_id      => $job->id,
        codigo_ibge => $cod_ibge,
        analysis    => $analysis,
        took        => $end - $start,
      },
      analytics_info => {
        query_args => {
          schema_name  => ANALYTICS_SCHEMA,
          output_table => 'city_school_analytics',
          codigo_ibge  => $cod_ibge,
          analysis     => $analysis,
        },
        r_meta => $r_out,
      }
    }
  );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Task::CityAnalytics - Task Minion para pré-computação especulativa de estatísticas e clusters escolares via R

=head1 SYNOPSIS

# No startup da aplicação EduMaps
$self->plugin('EduMaps::Task::CityAnalytics');

# Disparo via helper (aplica checagem de cache CHI e desduplicação no Minion)
my $job_id = $c->apply_city_analytics({
    codigo_ibge => '3550308',             # São Paulo
    analysis    => 'school_clusters',     # opcional, padrão: 'full_summary'
  });

=head1 DESCRIPTION

O módulo L<EduMaps::Task::CityAnalytics> gerencia a execução assíncrona de análises pesadas
(distribuição de notas, agrupamento k-means/DBSCAN de infraestrutura e sumarizações gerais de cidades).
Ele foi projetado especificamente para uso em B<computação especulativa>:

=over 4

=item * B<Desduplicação de Jobs>: Evita enfileirar o mesmo cálculo se já houver um job ativo ou inativo.

=item * B<Idempotência via CHI>: Consulta o cache antes de criar novos registros de tarefas.

=item * B<Isolamento de Recursos>: Enfileira os jobs na fila C<speculative> com prioridade reduzida (0), evitando gargalos nas tarefas ativas disparadas por interação direta de usuários.

=back

=head1 HELPERS

=head2 apply_city_analytics

my $job_id = $c->apply_city_analytics(\%args);

Valida idempotência, desduplica e enfileira a tarefa na fila especulativa do Minion. Retorna C<undef> se o cálculo já estiver em cache ou enfileirado.

=head1 SEE ALSO

L<Minion>, L<EduMaps::Analysis::R::Pipe>, L<EduMaps::EventBus::Middleware::PrecomputeAnalytics>

=cut
