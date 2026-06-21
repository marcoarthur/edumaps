package EduMaps::Roles::Joins;
use Mojo::Base -role, -signatures;
use Mojo::Collection qw(c);

requires qw(search_rs);

sub join($self, $relations) {
  $relations = ref $relations ? $relations : [ $relations ];
  $self->search_rs( undef, { join => $relations } );
}

# TODO: entender o que fazer e o proposito específico de anti_joins
sub anti_join($self, $related) {
  my $rels = $self->result_source->relationship_info($related);
  my $join_cond = {};

  if ( ref $rels->{cond} eq 'HASH' ) {
    $join_cond = $rels->{cond};
  } else {
    ...; # não implementado
  }

  # Obter o alias atual da resultset principal
  my $current_alias = $self->current_source_alias;
  
  # Extrair as partes da condição de join
  my ($foreign_col, $self_col);
  
  if (ref $rels->{cond} eq 'HASH') {
    # Para condições do tipo: { 'foreign.id' => 'self.foreign_id' }
    ($foreign_col, $self_col) = each %{$rels->{cond}};
  } else {
    die "Cannot calculate the JOIN condition";
  }
  
  # Remover prefixos de alias (ex: "foreign." ou "self.")
  $foreign_col =~ s/^\w+\.//;
  $self_col =~ s/^\w+\.//;
  
  # Obter a resultset relacionada
  my ($rs_name) = ($rels->{source} =~ m/::(\w+)$/);
  my $rel_rs = $self->result_source->schema->resultset($rs_name);
  
  # Criar a condição para a subquery
  # Usamos -ident para criar uma referência à coluna da query externa
  my $rs_param = { 
    $foreign_col => { -ident => "$current_alias.$self_col" }
  };
  
  my $rs_attrs = { 
    select => [\1],
    alias => "${related}_subq"  # Alias único para a subquery
  };
  
  # Retornar nova resultset com NOT EXISTS
  return $self->search_rs(
    { 
      -not_exists => $rel_rs->search_rs($rs_param, $rs_attrs)->as_query 
    }
  );
}

sub prefetch($self, $relations) {
  $relations = ref $relations ? $relations : [ $relations ];
  $self->search_rs( undef, { prefetch => $relations } );
}

sub relations($self) {  
  c($self->result_source->relationships)
  ->map( sub { +{ $_ => $self->result_source->relationship_info($_) } } );
}

1;
