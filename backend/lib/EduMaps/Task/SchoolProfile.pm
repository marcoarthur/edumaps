package EduMaps::Task::SchoolProfile;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use utf8;

# Task batch da Fase 2 do Perfil da Escola (issue #107): materializa as
# referências comparativas, os percentis de cluster e/ou o perfil por
# escola. Como o motor HTTP é quem conhece as tabelas pré-computadas, a
# task usa `analytics_engine = http` (Plumber/edumapsr) — o motor legado
# R::Pipe não é suportado aqui.

use constant {
  ANALYTICS_SCHEMA => 'analytics',
  DEFAULT_MODE     => 'profiles',
  DEFAULT_SCOPE    => 'pending',
  DEFAULT_LIMIT    => 500,
};

# mode -> método do EduMaps::Analytics::Client
use constant MODE_CLIENT_METHOD => {
  reference => 'run_school_profile_reference',
  cluster   => 'run_school_profile_cluster',
  profiles  => 'run_school_profile_batch',
};

sub register ($self, $app, $config) {
  $app->minion->add_task(
    school_profile_batch => task {
      sub   => \&_apply_school_profile,
      roles => {'+Progress' => {log => $app->log}},
    }
  );

  # Helper: enfileira a atualização na fila 'analytics' (baixa prioridade
  # não é necessária; é um job administrativo/agendado).
  $app->helper(
    apply_school_profile => sub ($c, $args = {}) {
      return $app->minion->enqueue(
        school_profile_batch => [$args] => { queue => 'analytics' }
      );
    }
  );
}

sub _apply_school_profile ($job, $args) {
  my $app   = $job->app;
  my $v     = $app->validator->validation;
  my $start = localtime;

  my $mode = $args->{mode} // DEFAULT_MODE;

  $v->input($args);
  $v->optional('mode', 'trim')->in(sort keys %{ +MODE_CLIENT_METHOD() });
  $v->optional('schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('output_schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('nu_ano_censo', 'trim')->like(qr/^\d{4}$/);
  $v->optional('scope', 'trim')->in(qw(pending municipio uf all));
  $v->optional('co_municipio', 'trim')->like(qr/^\d{7}$/);
  $v->optional('sg_uf', 'trim')->like(qr/^[A-Z]{2}$/);
  $v->optional('limit', 'trim')->like(qr/^\d+$/);

  return $job->fail("Modo inválido: '$mode'")
    unless exists MODE_CLIENT_METHOD->{$mode};

  return $job->fail("Argumentos inválidos fornecidos para SchoolProfile!")
    if $v->has_error;

  $args->{mode}          = $mode;
  $args->{schema}      //= 'clean';
  $args->{output_schema} //= ANALYTICS_SCHEMA;
  $args->{scope}       //= DEFAULT_SCOPE;
  $args->{limit}       //= DEFAULT_LIMIT;

  my $engine = $app->analytics_engine;
  return $job->fail("SchoolProfile batch exige analytics_engine=http (recebi '$engine')")
    unless $engine eq 'http';

  my $method = MODE_CLIENT_METHOD->{$mode};

  my %payload = (
    schema        => $args->{schema},
    output_schema => $args->{output_schema},
    (defined $args->{nu_ano_censo} ? (nu_ano_censo => 0 + $args->{nu_ano_censo}) : ()),
  );
  if ($mode eq 'profiles') {
    $payload{scope} = $args->{scope};
    $payload{co_municipio} = 0 + $args->{co_municipio} if defined $args->{co_municipio};
    $payload{sg_uf} = $args->{sg_uf} if defined $args->{sg_uf};
    $payload{limit} = 0 + $args->{limit} if defined $args->{limit};
  }

  my $r_out;
  try {
    $r_out = $app->analytics->$method(\%payload);
  } catch ($err) {
    return $job->fail("Erro na execução do serviço analítico ($mode): $err");
  }

  my $end = localtime;
  $job->finish({
    meta => {
      name    => 'school_profile_batch',
      job_id  => $job->id,
      mode    => $mode,
      scope   => $args->{scope},
      took    => $end - $start,
    },
    analytics_info => {
      query_args => {
        schema_name => ANALYTICS_SCHEMA,
        mode        => $mode,
      },
      r_meta => $r_out,
    },
  });
}

1;

__END__

=encoding utf8

=head1 NAME

EduMaps::Task::SchoolProfile - Task batch da Fase 2 do Perfil da Escola

=head1 DESCRIPTION

Materializa em `analytics` as tabelas pré-computadas do Perfil da Escola
(issue #107):

=over

=item * C<mode = reference> — C<analytics.school_profile_reference>
(médias Brasil/rede/município por ano);

=item * C<mode = cluster> — C<analytics.school_cluster_profile> (percentis
por cluster);

=item * C<mode = profiles> — C<analytics.school_profile> por escola
(scope C<pending> | C<municipio> | C<uf> | C<all>).

=back

Usa a fila Minion C<analytics> e o motor C<analytics_engine = http>
(Plumber/edumapsr). Deve rodar após a carga do censo (reference/profiles)
e após cada execução de clusterização (cluster/profiles).

=head1 SYNOPSIS

    $c->apply_school_profile({ mode => 'reference' });
    $c->apply_school_profile({ mode => 'cluster' });
    $c->apply_school_profile({ mode => 'profiles', scope => 'pending', limit => 500 });

=cut
