package EduMaps::Roles::DB::InjectRelation;
use Mojo::Base -role, -signatures;

sub inject_cluster_class ($self, $table_name, $args) {
  # Ex: se table_name for 'cluster_censo_escolas', 
  # source_name vira 'ClusterCensoEscolas'
  $args->{source_name} //= join('', map { ucfirst } split(/_/, $table_name));

  my $new_class = "EduMaps::Schema::Result::$args->{source_name}";

  # 1. Se a classe já foi injetada antes, não faz nada
  return $new_class if grep {$args->{source_name} eq $_ } $self->sources;

  # 2. Cria a classe dinamicamente definindo o pacote em tempo de execução
  {
    no strict 'refs';
    @{"${new_class}::ISA"} = qw(DBIx::Class::Core);
  }

  # 3. Configura a estrutura da nova tabela do cluster
  $args->{cluster_id}       //= 'cluster_id';
  $args->{dbic_type_for_id} //= { data_type => 'integer', is_numeric => 1 };

  $table_name = $args->{schema_name} . "." . $table_name if $args->{schema_name};

  $new_class->table($table_name);
  $new_class->add_columns(
    $args->{id_column}  => $args->{dbic_type_for_id},
    $args->{cluster_id} => { data_type => 'integer', is_numeric => 1 },
  );
  $new_class->set_primary_key($args->{id_column});

  # 4. Registra a nova classe gerada no Schema ativo do DBIC
  $self->register_class($args->{source_name} => $new_class);

  # 5. Cria a relação usando a estrutura dinâmica montada
  my $id = $args->{id_column};
  my $relation = { "foreign.$id" => "self.$id" }; # Usando a variável dinâmica de forma correta

  $self->source($args->{target_source})->add_relationship(
    cluster_info => $args->{source_name},
    $relation,               # CORRIGIDO: Passando a estrutura dinâmica
    { join_type => 'INNER' } # Força o comportamento de has_one/might_have
  );

  return $new_class;
}

1;
