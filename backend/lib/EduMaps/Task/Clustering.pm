package EduMaps::Task::Clustering;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use EduMaps::Analysis::R::Pipe;
use EduMaps::Presets;
use Time::Piece;

use constant {
  STAGING_SCHEMA    => 'staging',
  DB_SERVICE        => 'edumaps_local',
  DEFAULT_ALGORITHM => 'kmeans',
  DEFAULT_CLUSTERS  => 5,
  DEFAULT_EPS       => 0.5,
  DEFAULT_MIN_PTS   => 5,
};

# Mapa unico e explicito: algoritmo -> nome da funcao R correspondente.
# Esta e a UNICA fonte de verdade sobre quais algoritmos existem;
# a lista de valores aceitos pelo validador e derivada daqui (ver abaixo),
# para nunca mais divergir como aconteceu antes (algorithm validado mas
# nao usado para escolher a funcao/script real).
use constant ALGORITHM_R_FUNCTION => {
  kmeans   => 'compute_and_save_kmeans_with_meta',
  dbscan   => 'compute_and_save_dbscan_with_meta',
  gmm      => 'compute_and_save_gmm_with_meta',
  spectral => 'compute_and_save_spectral_with_meta',
};

# Validacao adicional de parametros especifica de cada algoritmo.
# Cada entrada recebe o objeto $v (Mojolicious::Validation) ja com
# ->input() chamado, e adiciona as regras extras necessarias.
my %ALGORITHM_VALIDATORS = (
  kmeans   => sub ($v) { $v->optional('clusters', 'trim')->num(2, 10) },
  gmm      => sub ($v) { $v->optional('clusters', 'trim')->num(2, 10) },
  spectral => sub ($v) { $v->optional('clusters', 'trim')->num(2, 10) },
  dbscan   => sub ($v) {
    $v->optional('eps', 'trim')->is_between(0.0001,100);
    $v->optional('min_pts', 'trim')->num(1, 1000);
  },
);

# Defaults aplicados apos a validacao passar, quando o parametro
# correspondente nao foi informado.
my %ALGORITHM_DEFAULTS = (
  kmeans   => { clusters => DEFAULT_CLUSTERS },
  gmm      => { clusters => DEFAULT_CLUSTERS },
  spectral => { clusters => DEFAULT_CLUSTERS },
  dbscan   => { eps => DEFAULT_EPS, min_pts => DEFAULT_MIN_PTS },
);

# Monta o trecho de argumentos nomeados especifico de cada algoritmo,
# usado para completar a chamada da funcao R.
my %ALGORITHM_R_ARGS = (
  kmeans   => sub ($a) { sprintf('k = %d', $a->{clusters}) },
  gmm      => sub ($a) { sprintf('k = %d', $a->{clusters}) },
  spectral => sub ($a) { sprintf('k = %d', $a->{clusters}) },
  dbscan   => sub ($a) {
    # sprintf com %.10g normaliza notacao cientifica/locale e evita
    # que um eps tipo 1e-05 quebre a interpolacao no script R
    sprintf('eps = %.10g, min_pts = %d', $a->{eps}, $a->{min_pts});
  },
);

sub register ($self, $app, $config) {
  # registra task
  $app->minion->add_task(clusterization => \&_apply_clustering);

  # adiciona o helper
  $app->helper(
    apply_clustering => sub ($c, $args) { $app->minion->enqueue( clusterization => [$args] ) }
  );
}

sub _apply_clustering($job, $args) {
  my $v = $job->app->validator->validation;
  my $start = localtime;
  my $rpipe = EduMaps::Analysis::R::Pipe->new;

  # O algoritmo precisa ser resolvido ANTES da validacao completa,
  # pois algumas regras (clusters vs eps/min_pts) sao condicionais a ele.
  my $algorithm = $args->{algorithm} // DEFAULT_ALGORITHM;

  $v->input($args);
  $v->required('id_column', 'trim')->like(qr/^\w+$/);
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('source_file', 'trim')->like(qr/^\w+$/);
  $v->optional('schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('db_service', 'trim')->like(qr/^\w+$/);
  $v->optional('algorithm', 'trim')->in(sort keys %{ +ALGORITHM_R_FUNCTION() });
  # features: lista de colunas usadas na clusterização (opcional; por
  # padrão o motor R auto-detecta as colunas numéricas)
  $v->optional('features');
  # filter: restrição por igualdade de coluna (ex.: geotag), repassado ao
  # motor R. Estrutura {coluna => valor escalar}, validada manualmente
  # porque o Mojolicious::Validator não tem tipo 'hash'.
  $v->optional('filter');

  return $job->fail("Invalid algorithm '$algorithm'")
    unless exists ALGORITHM_R_FUNCTION->{$algorithm};

  ($ALGORITHM_VALIDATORS{$algorithm} // sub {})->($v);

  return $job->fail("Invalid arguments!") if $v->has_error;

  # filter: {coluna => valor escalar} — rejeita estrutura fora desse formato
  # antecipadamente (o motor R ainda valida as colunas na tabela).
  if (defined $args->{filter}) {
    return $job->fail("Invalid arguments! 'filter' must be a hash of column => scalar")
      unless ref $args->{filter} eq 'HASH';
    for my $col (keys %{ $args->{filter} }) {
      my $val = $args->{filter}{$col};
      return $job->fail("Invalid arguments! 'filter' value for '$col' must be scalar")
        if ref $val;
    }
  }

  # Defaults gerais
  $args->{algorithm}    = $algorithm;
  $args->{schema}     //= STAGING_SCHEMA;
  $args->{db_service} //= DB_SERVICE;
  # source_file segue o algoritmo por padrao (kmeans.R, dbscan.R, ...),
  # mas pode ser sobrescrito explicitamente (ex: para apontar a uma
  # variante/versao alternativa do script durante testes)
  $args->{source_file} //= $algorithm;

  # Defaults especificos do algoritmo (clusters | eps+min_pts | ...)
  for my $key (keys %{ $ALGORITHM_DEFAULTS{$algorithm} // {} }) {
    $args->{$key} //= $ALGORITHM_DEFAULTS{$algorithm}{$key};
  }

  # -------------------------------------------------------------------------
  # Tabela denormalizada de indicadores (presets multi-tabela). O job
  # materializa clean.school_indicators (TRUNCATE + INSERT) para o ano IDEB
  # escolhido ANTES de chamar o motor R — o Plumber lê/escreve cluster_id na
  # MESMA tabela, logo ela precisa existir com o conteúdo do ano em questão.
  # -------------------------------------------------------------------------
  if ($args->{table_name} eq EduMaps::Presets->INDICATORS_TABLE) {
    $args->{schema} = 'clean';
    my $err = _rebuild_indicators($job, $args);
    return $job->fail("Error rebuilding clean.school_indicators: $err") if $err;
  }

  my $r_function  = ALGORITHM_R_FUNCTION->{$algorithm};
  my $extra_args  = $ALGORITHM_R_ARGS{$algorithm}->($args);

  my $r_out;
  my $engine = $job->app->analytics_engine;

  # ---------------------------------------------------------------
  # Motor HTTP: Plumber/edumapsr (POST /cluster). O serviço persiste
  # cluster_id na staging e metadados em analytics.clustering_metadata.
  # ---------------------------------------------------------------
  if ($engine eq 'http') {
    try {
      $r_out = $job->app->analytics->run_cluster({
        schema     => $args->{schema},
        table_name => $args->{table_name},
        id_column  => $args->{id_column},
        features   => $args->{features},
        filter     => $args->{filter},
        parameters => {
          algorithm => $algorithm,
          (defined $args->{clusters} ? (clusters => $args->{clusters}) : ()),
          (defined $args->{eps}      ? (eps      => $args->{eps})      : ()),
          (defined $args->{min_pts}  ? (min_pts  => $args->{min_pts})  : ()),
          (defined $args->{labeling} ? (labeling => $args->{labeling}) : ()),
        },
      });
    } catch($err) {
      return $job->fail("Error running analytics ($algorithm): $err");
    }
  }

  # ---------------------------------------------------------------
  # Motor legado: R::Pipe (scripts R locais via Rscript/IPC::Run)
  # ---------------------------------------------------------------
  else {
    try {
      $r_out = $rpipe->run(
        {
          paths => $args->{paths} || $job->app->renderer->paths,
          source_file => $args->{source_file} . '.R',
          script => <<~"EOS",
            ${r_function}(
              con        = dbConnect(RPostgres::Postgres(), service = "$args->{db_service}"),
              schema     = "$args->{schema}",
              table_name = "$args->{table_name}",
              id_column  = "$args->{id_column}",
              $extra_args
            )
          EOS
        }
      );
    } catch($err) {
      return $job->fail("Error running R ($algorithm): $err");
    }
  }

  my $end = localtime;
  $job->finish(
    {
      meta => {
        name => 'clusterization',
        job_id => $job->id,
        algorithm => $algorithm,
        took => $end - $start,
      },
      cluster_info => {
        inject_args => {
          schema_name => $args->{schema},
          id_column => $args->{id_column},
          cluster_column => 'cluster_id',
          table_name => $args->{table_name},
        },
        r_meta => $r_out,
      }
    }
  );
}

# Preenche clean.school_indicators para o ano IDEB escolhido. Retorna undef em
# caso de sucesso, ou a mensagem de erro. Usa o Mojo::Pg da app (mesmo banco
# que o motor R enxerga via pg_service 'edumaps_local').
sub _rebuild_indicators($job, $args) {
  my $db = $job->app->pg->db;
  my $ano_ideb = $args->{ano_ideb};

  unless (defined $ano_ideb) {
    my $row = $db->query(
      'SELECT COALESCE(MAX(ano), 0) AS ano FROM clean.ideb_notas_escolas'
    )->hash;
    $ano_ideb = $row->{ano};
  }

  my $has_ano = $db->query(
    'SELECT 1 FROM clean.ideb_notas_escolas WHERE ano = ?', $ano_ideb
  )->hash;
  return "ano_ideb '$ano_ideb' sem dados em clean.ideb_notas_escolas" unless $has_ano;

  # Toda feature selecionada precisa existir na tabela denormalizada
  # (valida cedo: o motor R só reclamaria depois de ler a tabela inteira).
  for my $feature (@{ $args->{features} || [] }) {
    return "feature '$feature' não existe em clean.school_indicators"
      if ref $feature || !$db->query(
        "SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'clean'
              AND table_name = 'school_indicators'
              AND column_name = ?",
        $feature
      )->hash;
  }

  eval {
    $db->query('TRUNCATE TABLE clean.school_indicators');
    $db->query(_indicators_build_sql(), $ano_ideb);
    1;
  } or return "$@";

  return;
}

# INSERT multicampo que materializa censo escolar + docentes (proporções por
# qt_doc_bas) + IDEB/SAEB agregado ao nível de escola (média entre etapas).
# O único bind é o ano IDEB (2023 etc.).
sub _indicators_build_sql() {
  return <<~'EOSQL';
    INSERT INTO clean.school_indicators
    SELECT
      e.*,
      d.qt_doc_bas,
      d.qt_doc_bas_esco_sup_grad_licen::float / NULLIF(d.qt_doc_bas, 0) AS prop_licenciatura,
      d.qt_doc_bas_esco_sup_pos_mestra::float / NULLIF(d.qt_doc_bas, 0)  AS prop_mestrado,
      d.qt_doc_bas_esco_sup_pos_douto::float / NULLIF(d.qt_doc_bas, 0)   AS prop_doutorado,
      d.qt_doc_bas_vinculo_concur::float / NULLIF(d.qt_doc_bas, 0)       AS prop_efetivos,
      d.qt_doc_bas_espec_nenhum::float / NULLIF(d.qt_doc_bas, 0)         AS prop_sem_especializacao,
      i.ano AS ano_ideb,
      i.nota_media,
      i.nota_matematica,
      i.nota_portugues,
      i.ideb_observado,
      i.aprovacao_si_4
    FROM clean.censo_escolas e
    LEFT JOIN clean.censo_docentes d
      ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = e.nu_ano_censo
    LEFT JOIN (
      SELECT id_escola, ano,
             avg(nota_media)::numeric AS nota_media,
             avg(nota_matematica)::numeric AS nota_matematica,
             avg(nota_portugues)::numeric AS nota_portugues,
             avg(ideb_observado)::numeric AS ideb_observado,
             avg(aprovacao_si_4)::numeric AS aprovacao_si_4
      FROM clean.ideb_notas_escolas
      WHERE ano = ?
      GROUP BY id_escola, ano
    ) i
      ON i.id_escola = e.co_entidade
  EOSQL
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Task::Clustering - Plugin do Mojolicious para processamento assíncrono de clusterização via R

=head1 SYNOPSIS

    # No startup da aplicação EduMaps
    $self->plugin('EduMaps::Task::Clustering');

    # Em algum controller ou ação para enfileirar a tarefa
    my $job_id = $c->apply_clustering({
        id_column  => 'co_entidade',
        table_name => 'test_cluster',
        algorithm  => 'dbscan',      # opcional: kmeans, dbscan, gmm, spectral. Padrão kmeans
        schema     => 'staging',     # opcional, padrão: 'staging'
        clusters   => 5,             # opcional (kmeans/gmm/spectral), padrão: 5
        eps        => 0.5,           # opcional (dbscan), padrão: 0.5
        min_pts    => 5,             # opcional (dbscan), padrão: 5
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Task::Clustering> atua como uma ponte assíncrona entre o
gerenciador de tarefas L<Minion> e o motor estatístico R. Ele registra a
tarefa C<clusterization> para processamento em background de algoritmos de
agrupamento (K-means, DBSCAN, GMM, Spectral) sobre tabelas de dados
educacionais. O algoritmo efetivamente executado é resolvido dinamicamente
a partir do parâmetro C<algorithm>, tanto para localizar o script R
(C<{algorithm}.R>) quanto para escolher a função R chamada
(ver C<ALGORITHM_R_FUNCTION>).

=head1 HELPERS

=head2 apply_clustering

    my $job_id = $c->apply_clustering(\%args);

Enfileira um novo processo de clusterização e retorna o identificador único do Job no Minion.

=head1 SEE ALSO

L<Minion>, L<EduMaps::Analysis::R::Pipe>

=cut
