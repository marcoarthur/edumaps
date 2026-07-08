package EduMaps::Roles::DB::InjectRelation;
use Mojo::Base -role, -signatures;
use Carp qw(croak);

# Args sempre obrigatorios em inject_cluster_class, independente de quantos
# defaults existam para o resto.
use constant REQUIRED_ARGS => qw(target_source id_column);

sub inject_cluster_class ($self, $table_name, $args) {
  croak "inject_cluster_class: table_name e obrigatorio" unless $table_name;
  for my $required (REQUIRED_ARGS) {
    croak "inject_cluster_class: '$required' e obrigatorio em \$args"
      unless defined $args->{$required};
  }

  # Ex: se table_name for 'cluster_censo_escolas',
  # source_name vira 'ClusterCensoEscolas'
  $args->{source_name} //= join('', map { ucfirst } split(/_/, $table_name));

  # 'cluster_column' e o nome usado no contrato retornado por
  # EduMaps::Task::Clustering (cluster_info.inject_args.cluster_column).
  # Mantemos 'cluster_id' como fallback para nao quebrar chamadas antigas
  # que ainda passem esse nome de chave diretamente.
  my $cluster_column = $args->{cluster_column} // $args->{cluster_id} // 'cluster_id';

  # Nome da relacao tambem parametrizavel: hardcoded como 'cluster_info'
  # antes, o que colide se voce quiser injetar duas tabelas de cluster
  # diferentes (ex: resultado de kmeans E de dbscan) para a MESMA
  # target_source ao mesmo tempo.
  my $relation_name = $args->{relation_name} // 'cluster_info';

  my $new_class = "EduMaps::Schema::Result::$args->{source_name}";
  my $full_table_name = $args->{schema_name} ? "$args->{schema_name}.$table_name" : $table_name;

  # 1. Se a classe ja foi injetada antes...
  if (grep { $args->{source_name} eq $_ } $self->sources) {
    # ...confirma que aponta para a MESMA tabela antes de reaproveitar.
    # Sem essa checagem, duas chamadas com o mesmo source_name (derivado
    # automaticamente do table_name) mas apontando para tabelas/colunas
    # diferentes fariam a segunda chamada devolver silenciosamente a
    # classe antiga - um bug dificil de perceber.
    my $existing_table = $self->source($args->{source_name})->name;
    croak sprintf(
      "inject_cluster_class: '%s' ja esta registrada apontando para '%s', "
        . "nao para '%s'. Use um 'source_name' diferente para evitar colisao.",
      $args->{source_name}, $existing_table, $full_table_name
    ) if $existing_table ne $full_table_name;

    return $new_class;
  }

  # 2. Cria a classe dinamicamente definindo o pacote em tempo de execução
  {
    no strict 'refs';
    @{"${new_class}::ISA"} = qw(DBIx::Class::Core);
  }

  # 3. Configura a estrutura da nova tabela do cluster
  $args->{dbic_type_for_id} //= { data_type => 'integer', is_numeric => 1 };
  $new_class->table($full_table_name);
  $new_class->add_columns(
    $args->{id_column} => $args->{dbic_type_for_id},
    $cluster_column    => { data_type => 'integer', is_numeric => 1 },
  );
  $new_class->set_primary_key($args->{id_column});

  # 4. Registra a nova classe gerada no Schema ativo do DBIC
  $self->register_class($args->{source_name} => $new_class);

  # 5. Cria a relação usando a estrutura dinâmica montada
  my $id = $args->{id_column};
  my $relation = { "foreign.$id" => "self.$id" };

  if (grep { $_ eq $relation_name } $self->source($args->{target_source})->relationships) {
    croak sprintf(
      "inject_cluster_class: a relacao '%s' ja existe em '%s'. "
        . "Passe 'relation_name' para dar um nome diferente.",
      $relation_name, $args->{target_source}
    );
  }

  $self->source($args->{target_source})->add_relationship(
    $relation_name => $args->{source_name},
    $relation,
    { join_type => 'INNER' } # Força o comportamento de has_one/might_have
  );

  return $new_class;
}

# Atalho para injetar a relacao diretamente a partir do resultado de um job
# finalizado de EduMaps::Task::Clustering (job->info->{result}), sem precisar
# traduzir manualmente as chaves de cluster_info.inject_args toda vez.
#
# $target_source continua obrigatorio e precisa ser passado explicitamente:
# o job sabe qual schema/tabela/coluna foram usados na clusterizacao, mas
# nao sabe (nem deveria saber) a qual Source/entidade de negocio essa
# tabela corresponde - isso e conhecimento da camada de negocio (ex:
# EduMaps::Roles::Business::School::Clustering), nao do worker do Minion.
#
# @param $self          EduMaps::Schema
# @param $job_result    hashref: job->info->{result} de um job 'clusterization'
# @param $target_source nome do Source DBIC que recebera a relacao (ex: 'CensoEscolas')
# @param %opts          source_name / relation_name opcionais, repassados a
#                        inject_cluster_class (ver acima)
sub inject_cluster_class_from_job ($self, $job_result, $target_source, %opts) {
  my $inject_args = $job_result->{cluster_info}{inject_args}
    // croak "inject_cluster_class_from_job: job_result sem cluster_info.inject_args";

  return $self->inject_cluster_class(
    $inject_args->{table_name},
    {
      schema_name    => $inject_args->{schema_name},
      id_column      => $inject_args->{id_column},
      cluster_column => $inject_args->{cluster_column},
      target_source  => $target_source,
      %opts,
    }
  );
}

1;
