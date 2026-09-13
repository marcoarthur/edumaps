## Questão

Tenho os scripts de cluster que quero que analise e sugira as modificações para que fiquem padronizados (principalmente na resposta
json), entenda o contexto:

### Clusterização de tabelas preparadas no Pipeline Perl

O ambiente Perl possui as classes DBICS capazes de seguinte ROLE:

```perl

package EduMaps::Roles::DB::SQLUtils;
use Mojo::Base -role, -signatures;
use Mojo::Collection qw(c);
use Syntax::Keyword::Try;

sub save_in_table($self,  %opts) {
  # remove the schema part from table name
  my $name = $self->result_source->name =~ s/\w+\.//r;
  # read options
  my ($tbl_name, $schema, $is_temporary) = (
    $opts{tbl_name}       || ( $name . '_temp'),
    $opts{schema}         || 'pg_temp', 
    defined $opts{temporary} ? $opts{temporary} : 1,
  );
  # get the select statement and bindings
  my ($stmt, @binds)  = @{ $self->as_query->$* };
  @binds              = map { $_->[1] } @binds;
  my $storage         = $self->result_source->schema->storage;
  my $tbl             = "${schema}.${tbl_name}";
  # set the DDL transaction
  my $transaction     = sub ($me, $dbh, @args)
  {
    # drop any previous temp table
    my $drop_if = sprintf('DROP TABLE IF EXISTS %s', $tbl); 
    # create temp or permanent
    my $create  = $is_temporary ? 'CREATE TEMPORARY TABLE' : 'CREATE TABLE';
    # set the create sql statement
    $create     = sprintf ("%s %s AS (%s)",$create, $tbl, $stmt);
    # run drop
    $dbh->do($drop_if);
    # run create
    $dbh->do($create, undef, @binds);
  };

  # execute in a safe way
  $storage->txn_do(
    sub { 
      try { return $storage->dbh_do($transaction); }
      catch ($err) {
        warn "Error during temporary table creation: $err";
        $storage->txn_rollback;
      }
    }
  );
}
```

com isso ele cria tabelas com features prontas para serem clusterizadas através de um driver:

```perl

package EduMaps::Analysis::R::Pipe;
use Mojo::Base -base, -signatures;
use Mojo::File qw(path tempfile);
use Mojo::Collection qw(c);
use Mojo::JSON qw(decode_json);
use Carp qw(croak);
use IPC::Run;

has engine       => 'Rscript';
has default_opts => sub { [qw/--vanilla/] };
has [qw(paths source_file script cmd_str cmd_args script_tmp full_cmd)];

sub run ($self, $args) {
  $self->_set_args($args)
  ->_resolve_cmd
  ->_mount_final_script
  ->_run;
}

sub _set_args ($self, $args) {
  $self->paths(c($args->{paths}->@*)->map(sub { path($_) }));

  my $target_name = path($args->{source_file})->basename;

  # Busca o script R iterando de forma segura pelas rotas de paths
  my $file = $self->paths->map(
    sub ($dir) {
      return unless -d $dir;
      $dir->list_tree->first(sub ($f) { $f->basename eq $target_name });
    }
  )->grep(sub { defined $_ && -e $_ })->first;

  croak "R Script '$target_name' not found in paths" unless $file;

  $self->source_file($file);
  $self->script($args->{script});
  $self;
}

sub _resolve_cmd ($self) {
  $self->cmd_str($self->engine);
  $self->cmd_args(c($self->default_opts->@*));
  $self->script_tmp(tempfile( DIR => '/tmp' ));
  $self;
}

sub _mount_final_script ($self) {
  $self->script_tmp->spew(
    sprintf qq{source("%s")\n%s},
    $self->source_file->to_abs->to_string,
    $self->script
  );

  $self->full_cmd(c($self->cmd_str, $self->cmd_args->@*, $self->script_tmp));
  $self;
}

sub _run ($self) {
  my ($out, $err);
  my $ok = IPC::Run::run($self->full_cmd->to_array, \undef, \$out, \$err);

  # Força o unlink do arquivo temporário imediatamente após o término da execução
  if ($self->script_tmp && -e $self->script_tmp) {
    unlink $self->script_tmp;
  }

  croak "Rscript failed: $err" unless $ok;

  if ($out) {
    my $result;
    eval {
      $result = decode_json($out);
      1;
    } or do {
      croak "Failed to parse JSON response from R: $@. Raw output: $out";
    };
    return $result;
  }

  return { status => 'success', message => 'No output captured' };
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Analysis::R::Pipe - Pipeline de execução isolada e dinâmica de scripts R via IPC::Run

=head1 SYNOPSIS

    use EduMaps::Analysis::R::Pipe;

    my $rpipe = EduMaps::Analysis::R::Pipe->new;
    $rpipe->run({
        paths       => [qw(/path/to/r/scripts)],
        source_file => 'analytics_script.R',
        script      => 'custom_r_function(arg1 = "value")'
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Analysis::R::Pipe> gerencia o ciclo de vida de subprocessos C<Rscript>. Ele localiza dinamicamente arquivos de origem dentro dos caminhos especificados, injeta comandos customizados em tempo de execução e garante o expurgo de arquivos temporários em disco.

=head1 SEE ALSO

L<IPC::Run>, L<Mojo::File>, L<EduMaps::Task::Kmeans>

=cut
```

que executa no contexto de uma Task

```perl

package EduMaps::Task::Kmeans;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use EduMaps::Analysis::R::Pipe;
use Time::Piece;

use constant { 
  STAGING_SCHEMA  => 'staging',
  DB_SERVICE      => 'edumaps_local',
  KMEANS_SCRIPT   => 'kmeans.R',
  CLUSTERS_SIZE   => 5,
};

sub register ($self, $app, $config) {
  # registra task
  $app->minion->add_task(
    clusterization => task {
        sub => \&_apply_kmeans,
        roles => {'+Progress' => {log => $app->log}},
      }
  );

  # adiciona o helper
  $app->helper(
    apply_kmeans => sub ($c, $args) { $app->minion->enqueue( clusterization => [$args] ) }
  );
}

sub _apply_kmeans($job, $args) {
  # verifica os argumentos
  my $v = $job->app->validator->validation;
  my $start = localtime;
  my $rpipe = EduMaps::Analysis::R::Pipe->new;

  $v->input($args);
  $v->required('id_column', 'trim')->like(qr/^\w+$/);
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('source_file', 'trim')->like(qr/^\w+\.R$/);
  $v->optional('schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('clusters', 'trim')->num(2,10);
  $v->optional('db_service', 'trim')->like(qr/^\w+$/);

  return job->fail("Invalid arguments!") if $v->has_error;

  $args->{source_file}  //= KMEANS_SCRIPT;
  $args->{schema}       //= STAGING_SCHEMA;
  $args->{clusters}     //= CLUSTERS_SIZE;
  $args->{db_service}   //= DB_SERVICE;

  # motor R para cálculo de clusters
  my $r_out;
  try {
    $r_out = $rpipe->run(
      {
        paths => $args->{paths} || $job->app->renderer->paths,
        source_file => $args->{source_file},
        script => <<~"EOS",
          compute_and_save_kmeans_with_meta(
            con        = dbConnect(RPostgres::Postgres(), service = "$args->{db_service}"),
            schema     = "$args->{schema}",
            table_name = "$args->{table_name}",
            k          = $args->{clusters},
            id_column  = "$args->{id_column}"
          )
        EOS
      }
    );
  } catch($err) {
    return $job->fail("Error running R: $err");
  }

  my $end = localtime;

  $job->finish(
    {
      meta => {
        name => 'clusterization',
        job_id => $job->id,
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

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Task::Kmeans - Plugin do Mojolicious para processamento assíncrono de clusterização K-means via R

=head1 SYNOPSIS

    # No startup da aplicação EduMaps
    $self->plugin('EduMaps::Task::Kmeans');

    # Em algum controller ou ação para enfileirar a tarefa
    my $job_id = $c->apply_kmeans({
        id_column  => 'co_entidade',
        table_name => 'test_cluster',
        schema     => 'staging',     # opcional, padrão: 'staging'
        clusters   => 5,             # opcional, padrão: 5
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Task::Kmeans> atua como uma ponte assíncrona entre o gerenciador de tarefas L<Minion> e o motor estatístico R. Ele registra a tarefa C<clusterization> para processamento em background de algoritmos de agrupamento (K-means) sobre tabelas de dados educacionais.

=head1 HELPERS

=head2 apply_kmeans

    my $job_id = $c->apply_kmeans(\%args);

Enfileira um novo processo de clusterização e retorna o identificador único do Job no Minion.

=head1 SEE ALSO

L<Minion>, L<EduMaps::Analysis::R::Pipe>

=cut
```

Desse modo eu criei os scripts (o mais completo que server de referência) R cuja tarefa é apenas criar o cluster e salvar metadados

```R
#' Compute K-means, Save Cluster IDs and Centroid Metadata to Postgres
#'
#' @param con Conexão ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "analytics")
#' @param table_name Nome da tabela alvo
#' @param k Número de clusters para o K-means
#' @param id_column Nome da chave primária da tabela
#'
compute_and_save_kmeans_with_meta <- function(con, schema, table_name, k, id_column) {
  # Carrega os pacotes em silêncio, mas falha explicitamente se não existirem
  suppressPackageStartupMessages({
    library(tidyverse, quietly = TRUE)
    library(DBI, quietly = TRUE)
    library(dbplyr, quietly = TRUE)
    library(jsonlite, quietly = TRUE)
  })

  # Gerar um ID único para esta execução baseado no timestamp
  run_id <- paste0("run_", as.integer(Sys.time()))
  
  # 1. Referência preguiçosa e introspecção de colunas numéricas
  db_table <- tbl(con, in_schema(schema, table_name))
  sample_data <- db_table %>% head(1) %>% collect()
  
  numeric_features <- sample_data %>% 
    select(where(is.numeric)) %>% 
    colnames()
  
  # Ignora colunas de ID ou clusters anteriores
  numeric_features <- setdiff(numeric_features, c(id_column, "cluster_id"))
  
  if (length(numeric_features) == 0) {
    stop("Nenhuma coluna numérica encontrada para computar o K-means.")
  }
  
  # 2. Coleta e limpeza dos dados locais
  local_data <- db_table %>% 
    select(all_of(c(id_column, numeric_features))) %>% 
    collect() %>% 
    drop_na()
  
  # Dados para o algoritmo (K-means necessita de escala normalizada)
  kmeans_input <- local_data %>% 
    select(all_of(numeric_features)) %>% 
    scale()
  
  # Salva os atributos de escala (média e desvio padrão) para desnormalizar os centróides depois
  scale_center <- attr(kmeans_input, "scaled:center")
  scale_scale  <- attr(kmeans_input, "scaled:scale")
  
  # 3. Executa o K-means
  set.seed(42)
  kmeans_result <- kmeans(kmeans_input, centers = k, nstart = 25)
  
  
  # 4. PREPARAÇÃO DOS METADADOS (Transformação em JSON por linha)
  centroids_scaled <- kmeans_result$centers
  centroids_original <- t(apply(centroids_scaled, 1, function(row) row * scale_scale + scale_center))
  centroids_df <- as_tibble(centroids_original)

  centroids_json <- sapply(seq_len(nrow(centroids_df)), function(i) {
    # jsonlite::toJSON de um dataframe de 1 linha gera um array contendo um objeto: [{...}]
    # Usando auto_unbox e simplificando para extrair apenas o objeto literal: {...}
    jsonlite::toJSON(centroids_df[i, ], auto_unbox = TRUE) %>% 
      # Remove os colchetes externos se o R insistir em envelopar como array de 1 elemento
      stringr::str_remove_all("^\\[|\\]$") 
  })
  # Monta o dataframe final com estrutura genérica e fixa
  metadata_tb <- tibble(
    run_id       = run_id,
    target_table = paste0(schema, ".", table_name),
    cluster_id   = 1:k,
    cluster_size = kmeans_result$size,
    within_ss    = kmeans_result$withinss,
    centroids    = centroids_json  # Texto JSON que o Postgres interpretará como JSONB
  )
  # 5. SALVAMENTO DOS METADADOS
  meta_table_name <- "kmeans_metadata"
  
  # Garante que a tabela de metadados exista (adiciona se não existir)
  dbWriteTable(con, Id(schema = schema, table = meta_table_name), metadata_tb, append = TRUE)
  
  # 6. ATUALIZAÇÃO DA TABELA ORIGINAL (IDs dos Clusters)
  output_data <- tibble(
    !!sym(id_column) := local_data[[id_column]],
    cluster_id       = kmeans_result$cluster
  )
  
  temp_table_name <- paste0("temp_kmeans_", as.integer(Sys.time()))
  dbWriteTable(con, temp_table_name, output_data, row.names = FALSE, temporary = TRUE)
  
  # Adiciona a coluna cluster_id se não existir
  sql_add_col <- sprintf("ALTER TABLE %s.%s ADD COLUMN IF NOT EXISTS cluster_id INTEGER;", schema, table_name)
  dbExecute(con, sql_add_col)
  
  # Executa o Join Update massivo
  sql_update <- sprintf(
    "UPDATE %s.%s AS t SET cluster_id = temp.cluster_id FROM %s AS temp WHERE t.%s = temp.%s;",
    schema, table_name, temp_table_name, id_column, id_column
  )
  rows_affected <- dbExecute(con, sql_update)
  
  response_payload <- list(
    status      = "success",
    algorithm   = "kmeans",
    schema      = as.character(schema),
    table_name  = as.character(table_name),
    metadata    = meta_table_name,
    k_param     = as.integer(k),
    timestamp   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    run_id      = as.character(run_id),
    centroids   = centroids_df
  )

  # cat envia texto puro ao stdout sem os índices [1] do print clássico do R
  cat(jsonlite::toJSON(response_payload, auto_unbox = TRUE))

  quit(status = 0)
}

```

---

Demais similares são dbscan.R , gmm.R e spectral.R, que para não alongar vou apresentar no momento o dbscan.R e quero que faça a análise sobre uniformidade nas interfaces (outputs) e salvamento dos metadados, indexação de resultados formação de chaves e conformidades práticas para que fiquem todos alinhados

```R
#' Compute DBSCAN, Save Cluster IDs and Cluster Metadata to Postgres
#'
#' @param con Conexão ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "analytics")
#' @param table_name Nome da tabela alvo
#' @param eps Raio máximo da vizinhança (tamanho do passo)
#' @param min_pts Número mínimo de pontos para região densa
#' @param id_column Nome da chave primária da tabela
#'
compute_and_save_dbscan_with_meta <- function(con, schema, table_name, eps, min_pts, id_column) {
  suppressPackageStartupMessages({
    library(DBI, quietly = TRUE)
    library(dbplyr, quietly = TRUE)
    library(dbscan)
    library(jsonlite, quietly = TRUE)
  })

  # 1. Leitura dos dados do PostgreSQL
  full_table_target <- DBI::Id(schema = schema, table = table_name)
  df_raw <- DBI::dbReadTable(con, full_table_target)
  

  # 2. Preparar matriz numérica e PADRONIZAR (Z-score)
  numeric_matrix <- df_raw %>%
    dplyr::select(where(is.numeric), -any_of(c(id_column, "cluster_id"))) %>%
    as.matrix()

  # ESCALONAR: Garante que "10 professores" não pese menos que "400 alunos"
  numeric_matrix_scaled <- scale(numeric_matrix)

  # 2. Execução do DBSCAN
  # dbscan::dbscan é altamente otimizado usando árvores kd
  dbscan_result <- dbscan::dbscan(numeric_matrix, eps = eps, minPts = min_pts)
  
  # 3. Preparação da tabela de mapeamento de IDs -> Clusters
  # No dbscan, a classe '0' é explicitamente atribuída a ruídos/outliers
  df_clusters <- data.frame(
    id = df_raw[[id_column]],
    cluster_id = dbscan_result$cluster
  )
  colnames(df_clusters)[1] <- id_column
  
  # 4. Geração de Metadados dos Clusters
  # Calcula tamanho e proporção de cada cluster, identificando o ruído
  df_meta <- df_clusters %>%
    dplyr::group_by(cluster_id) %>%
    dplyr::summarise(
      cluster_size = n(),
      is_noise = ifelse(cluster_id == 0, TRUE, FALSE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      eps_param = eps,
      min_pts_param = min_pts
    )
  
  # 5. Escrita no Banco de Dados (Postgres)
  # Salvando os resultados em tabelas derivadas no mesmo esquema
  table_clusters_output <- DBI::Id(schema = schema, table = paste0(table_name, "_dbscan_assignments"))
  table_meta_output     <- DBI::Id(schema = schema, table = paste0(table_name, "_dbscan_metadata"))
  
  DBI::dbWriteTable(con, table_clusters_output, df_clusters, overwrite = TRUE, row.names = FALSE)
  DBI::dbWriteTable(con, table_meta_output, df_meta, overwrite = TRUE, row.names = FALSE)
  
  message("DBSCAN computado com sucesso. Tabelas de mapeamento e metadados atualizadas no banco.")
  
  return(TRUE)
}

```
