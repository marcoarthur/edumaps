package EduMaps::Roles::DB::InjectSimilarityRelation;
use Mojo::Base -role, -signatures;
use Carp qw(croak);
use Mojo::Collection qw(c);
use List::Util qw(min);

# Nome fixo do Source DBIC injetado para representar analytics.similarity_pairs.
# E UMA UNICA classe compartilhada por todo o schema - ao contrario de
# inject_cluster_class (uma classe nova por tabela clusterizada),
# similarity_pairs e sempre a MESMA tabela fisica para qualquer
# target_source/metrica. O que varia por chamada sao os relacionamentos
# (ver inject_similarity_relation), nao a classe.
use constant SIMILARITY_PAIRS_SOURCE_NAME => 'SimilarityPair';

# Registro (nivel de arquivo/processo) dos metodos de conveniencia tipo
# "top_similars" ja instalados em classes Result, no formato:
#   "${result_class}::${method_name}" => "${target_table}|${metric}"
# Usado so para detectar colisao (mesmo metodo instalado 2x com
# target_table/metric diferentes) - ver inject_similarity_relation.
my %TOP_SIMILARS_REGISTRY;

# Registra (uma unica vez, idempotente) a classe proxy para
# analytics.similarity_pairs.
#
# @param $self       EduMaps::Schema
# @param %opts       schema_name (default 'analytics'), source_name
#                     (default 'SimilarityPair')
# @return nome completo da classe registrada
sub inject_similarity_pairs_class ($self, %opts) {
  my $source_name = $opts{source_name} // SIMILARITY_PAIRS_SOURCE_NAME;
  my $schema_name = $opts{schema_name} // 'analytics';
  my $new_class = "EduMaps::Schema::Result::$source_name";

  # Idempotente: se ja foi injetada, apenas devolve - nao ha "estrutura
  # diferente" possivel aqui como havia em inject_cluster_class, ja que so
  # existe UMA tabela fisica de origem (analytics.similarity_pairs) para
  # essa classe, entao nao precisa da checagem de colisao de table_name
  # que fizemos em InjectRelation.pm.
  return $new_class if grep { $_ eq $source_name } $self->sources;

  {
    no strict 'refs';
    @{"${new_class}::ISA"} = qw(DBIx::Class::Core);
  }

  $new_class->table("$schema_name.similarity_pairs");
  $new_class->add_columns(
    run_id       => { data_type => 'text' },
    metric       => { data_type => 'text' },
    target_table => { data_type => 'text' },
    id_column    => { data_type => 'text' },
    params_json  => { data_type => 'text', is_nullable => 1 },
    entity_1     => { data_type => 'text' },
    entity_2     => { data_type => 'text' },
    distance     => { data_type => 'double precision' },
    similarity   => { data_type => 'double precision' },
    computed_at  => { data_type => 'timestamp' },
  );
  # Nao ha chave primaria natural de coluna unica; (run_id, entity_1,
  # entity_2) e unico por execucao e serve so para satisfazer o DBIC
  # (necessario para ->find/->update em linhas individuais, se algum dia
  # precisar).
  $new_class->set_primary_key(qw/run_id entity_1 entity_2/);

  $self->register_class($source_name => $new_class);
  return $new_class;
}

# Injeta duas relacoes has_many em $args->{target_source}, apontando para
# a classe compartilhada de similarity_pairs, filtradas por target_table
# (e opcionalmente por metric) via condicao em coderef.
#
# Sintaxe do coderef confirmada contra a documentacao do
# DBIx::Class::Relationship::Base (self_alias/foreign_alias sao as chaves
# corretas). Alem da condicao de JOIN completa, tambem devolvemos a forma
# "join-free" opcional (via $args->{self_result_object}), que permite ao
# DBIC pular o JOIN e ir direto ao WHERE quando a relacao e acessada a
# partir de uma linha ja carregada (ex: $escola_row->similarity_pairs_as_1),
# em vez de sempre montar um LEFT JOIN mesmo para esse caso comum.
#
# IMPORTANTE: $args->{target_table} precisa bater EXATAMENTE com o valor
# gravado na coluna target_table pelo script R (ver similarity_utils.R:
# write_similarity_pairs usa paste0(schema, ".", table_name)) - ou seja,
# e a tabela de ORIGEM dos dados usados para calcular a similaridade
# (ex: 'staging.test_similarity'), NAO necessariamente a mesma tabela de
# $args->{target_source} (ex: CensoEscolas pode viver em censo_escolas,
# mas a similaridade foi calculada sobre uma tabela derivada em staging).
# Por isso NAO tentamos auto-derivar target_table a partir do proprio
# target_source - precisa ser passado explicitamente, do mesmo jeito que
# EduMaps::Task::Similarity ja devolve em similarity_info.query_args.
#
# @param $self  EduMaps::Schema
# @param $args  hashref:
#   target_source  (obrigatorio) nome do Source DBIC que recebera as relacoes
#   id_column      (obrigatorio) coluna de identificacao em target_source
#   target_table   (obrigatorio) "schema.tabela" de origem, igual ao
#                  gravado em similarity_pairs.target_table
#   metric         (opcional) se definido, restringe as relacoes a essa
#                  metrica; se omitido, todas as metricas calculadas para
#                  target_table aparecem juntas
#   relation_name  (opcional) prefixo do nome das relacoes injetadas
#                  (default 'similarity_pairs' -> similarity_pairs_as_1 /
#                  similarity_pairs_as_2)
#   method_name    (opcional) nome do metodo de conveniencia instalado
#                  diretamente na classe Result de target_source, ex:
#                  $escola->top_similars(10) (default 'top_similars').
#                  Se voce injetar mais de uma metrica para o mesmo
#                  target_source, passe um method_name diferente por
#                  metrica (ex: 'top_similars_gower', 'top_similars_dtw')
#                  - senao a segunda chamada faz croak por colisao (ver
#                  %TOP_SIMILARS_REGISTRY abaixo).
#   install_top_similars (opcional, default true) desliga a instalacao
#                  do metodo de conveniencia, caso voce so queira as
#                  relacoes as_1/as_2 "cruas"
# @return nome completo da classe de similarity_pairs (mesmo retorno de
#   inject_similarity_pairs_class)
sub inject_similarity_relation ($self, $args) {
  for my $required (qw/target_source id_column target_table/) {
    croak "inject_similarity_relation: '$required' e obrigatorio"
      unless defined $args->{$required};
  }

  my $target_source = $args->{target_source};
  my $id_column     = $args->{id_column};
  my $target_table  = $args->{target_table};
  my $metric        = $args->{metric};
  my $relation_name = $args->{relation_name} // 'similarity_pairs';

  my $pairs_class = $self->inject_similarity_pairs_class(
    schema_name => $args->{pairs_schema_name} // 'analytics',
    source_name => $args->{pairs_source_name} // SIMILARITY_PAIRS_SOURCE_NAME,
  );
  my ($pairs_source_name) = $pairs_class =~ /::([^:]+)$/;

  for my $side (['1', 'entity_1'], ['2', 'entity_2']) {
    my ($n, $col) = @$side;
    my $rel_name = "${relation_name}_as_${n}";

    # idempotente: nao reinjeta se ja existir
    next if grep { $_ eq $rel_name } $self->source($target_source)->relationships;

    $self->source($target_source)->add_relationship(
      $rel_name => $pairs_source_name,
      sub {
        my $rel_args = shift;
        my $self_alias    = $rel_args->{self_alias};
        my $foreign_alias = $rel_args->{foreign_alias};

        my $join_cond = {
          "${foreign_alias}.${col}"       => { -ident => "${self_alias}.${id_column}" },
          "${foreign_alias}.target_table" => $target_table,
        };
        $join_cond->{"${foreign_alias}.metric"} = $metric if defined $metric;

        # forma "join-free": quando a relacao e resolvida a partir de uma
        # linha ja carregada ($row->$rel_name), usamos o valor real da
        # coluna em vez de montar um JOIN
        return $join_cond unless $rel_args->{self_result_object};

        my $direct_cond = {
          "${foreign_alias}.${col}"       => $rel_args->{self_result_object}->get_column($id_column),
          "${foreign_alias}.target_table" => $target_table,
        };
        $direct_cond->{"${foreign_alias}.metric"} = $metric if defined $metric;

        return ($join_cond, $direct_cond);
      },
      {
        join_type => 'LEFT', # a entidade pode nao ter nenhum par calculado ainda
        accessor  => 'multi',
      }
    );

    # add_relationship() sozinho so registra os metadados da relacao
    # (visiveis via ->relationships) - ao contrario do que a doc do attr
    # 'accessor' sugere, ele NAO instala de forma confiavel o metodo
    # $row->$rel_name quando chamado fora do fluxo normal de has_many/
    # belongs_to (que fazem processamento adicional alem de chamar
    # add_relationship). Por isso instalamos o metodo manualmente aqui,
    # replicando o que o accessor 'multi' do DBIC faz: sem argumentos,
    # devolve o ResultSet relacionado (cacheable via related_resultset);
    # com argumentos, aplica um search_related adicional.
    my $result_class = $self->source($target_source)->result_class;
    my $rel_name_captured = $rel_name; # fixa o valor por closure, uma copia por iteracao
    {
      no strict 'refs';
      *{"${result_class}::${rel_name_captured}"} = sub {
        my $row = shift;
        return @_
          ? $row->search_related($rel_name_captured, @_)
          : $row->related_resultset($rel_name_captured);
      };
    }
  }

  # ------------------------------------------------------------------
  # Metodo de conveniencia: $row->top_similars($limit) instalado direto
  # na classe Result de target_source (ex: EduMaps::Schema::Result::
  # CensoEscolas), combinando os dois lados do par (entity_1/entity_2)
  # e resolvendo qual e a "outra" entidade - sem o chamador precisar
  # saber nada sobre target_table/metric/id_column, ja fixados por
  # closure no momento da injecao.
  #
  # Resolve o schema em tempo de chamada via $row->result_source->schema
  # (nao via $self capturado na closure), para nao prender o metodo a
  # uma instancia de schema especifica caso a app troque de conexao
  # entre o momento da injecao e o momento da chamada.
  # ------------------------------------------------------------------
  if ($args->{install_top_similars} // 1) {
    my $method_name = $args->{method_name} // 'top_similars';
    my $result_class = $self->source($target_source)->result_class;
    my $registry_key = "${result_class}::${method_name}";
    my $registry_value = "$target_table|" . ($metric // '');

    if (exists $TOP_SIMILARS_REGISTRY{$registry_key}) {
      croak sprintf(
        "inject_similarity_relation: metodo '%s' ja foi instalado em '%s' para "
          . "target_table/metric '%s', nao para '%s'. Passe 'method_name' "
          . "diferente para injetar mais de uma metrica/tabela no mesmo target_source.",
        $method_name, $result_class, $TOP_SIMILARS_REGISTRY{$registry_key}, $registry_value
      ) if $TOP_SIMILARS_REGISTRY{$registry_key} ne $registry_value;
    } else {
      $TOP_SIMILARS_REGISTRY{$registry_key} = $registry_value;

      no strict 'refs';
      *{"${result_class}::${method_name}"} = sub {
        my ($row, $limit) = @_;
        $limit //= 10;
        my $schema = $row->result_source->schema;
        return $schema->similar_entities(
          target_table      => $target_table,
          metric            => $metric,
          entity_id         => $row->get_column($id_column),
          limit             => $limit,
          pairs_source_name => $pairs_source_name,
          result_class      => $result_class,
          id_column         => $id_column,
        );
      };
    }
  }

  return $pairs_class;
}

# Atalho: injeta a relacao diretamente a partir do resultado de um job
# finalizado de EduMaps::Task::Similarity (job->info->{result}), sem
# precisar montar target_table/metric na mao.
#
# @param $self          EduMaps::Schema
# @param $job_result    hashref: job->info->{result} de um job 'similarity'
# @param $target_source nome do Source DBIC que recebera as relacoes
# @param %opts          id_column (default: le de r_meta.id_column),
#                        relation_name (opcional)
sub inject_similarity_relation_from_job ($self, $job_result, $target_source, %opts) {
  my $query_args = $job_result->{similarity_info}{query_args}
    // croak "inject_similarity_relation_from_job: job_result sem similarity_info.query_args";
  my $r_meta = $job_result->{similarity_info}{r_meta} // {};

  my $id_column = $opts{id_column} // $r_meta->{id_column}
    // croak "inject_similarity_relation_from_job: id_column nao informado e ausente em r_meta";

  return $self->inject_similarity_relation({
    target_source     => $target_source,
    id_column         => $id_column,
    target_table      => $query_args->{target_table},
    metric            => $query_args->{metric},
    pairs_schema_name => $query_args->{schema_name},
    %opts,
  });
}

# Metodo de conveniencia: devolve as N entidades mais similares a
# $entity_id, ja resolvendo o lado do par (entity_1 vs entity_2) e
# considerando apenas a execucao (run_id) MAIS RECENTE para o
# target_table/metric pedidos - sem isso, execucoes antigas (historico
# preservado de proposito em write_similarity_pairs) apareceriam
# duplicadas/misturadas.
#
# @param $self         EduMaps::Schema
# @param %args         target_table, metric, entity_id (obrigatorios),
#                       limit (default 10), pairs_source_name (opcional)
# @return arrayref de { entity_id, similarity, distance }, ordenado por
#   similarity decrescente
sub similar_entities ($self, %args) {
  for my $required (qw/target_table metric entity_id/) {
    croak "similar_entities: '$required' e obrigatorio" unless defined $args{$required};
  }

  my $limit = $args{limit} // 10;
  my $pairs_source_name = $args{pairs_source_name} // SIMILARITY_PAIRS_SOURCE_NAME;
  my $pairs_rs = $self->resultset($pairs_source_name);

  # Ultimo run_id para esse target_table+metric (evita misturar execucoes
  # diferentes, ja que write_similarity_pairs sempre faz append/historico)
  my $latest_run = $pairs_rs->search(
    { target_table => $args{target_table}, metric => $args{metric} },
    { order_by => { -desc => 'computed_at' }, rows => 1, columns => ['run_id'] }
  )->first;
  return c() unless $latest_run;

  my @rows = $pairs_rs->search(
    {
      target_table => $args{target_table},
      metric       => $args{metric},
      run_id       => $latest_run->run_id,
      -or          => [ entity_1 => $args{entity_id}, entity_2 => $args{entity_id} ],
    },
    { order_by => { -desc => 'similarity' } }
  )->all;

  my @result = map {
    my $other = $_->entity_1 eq $args{entity_id} ? $_->entity_2 : $_->entity_1;
    { entity_id => $other, similarity => $_->similarity, distance => $_->distance };
  } @rows;

  @result = sort { $b->{similarity} <=> $a->{similarity} } @result;
  my $last_idx = min($limit - 1, $#result);
  return $last_idx < 0 ? c() : c( @result[0 .. $last_idx] );
}

1;
