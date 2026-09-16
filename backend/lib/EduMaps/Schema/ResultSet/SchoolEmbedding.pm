package EduMaps::Schema::ResultSet::SchoolEmbedding;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;

# Busca de vizinhos mais próximos por similaridade de cosseno (pgvector).
#
# Substitui o cálculo O(n²) em memória (EduMaps::Model::Role::FindSimilar,
# métrica _manhattan_distance) por uma única query com índice ANN (HNSW):
#   distance   = embedding <=> embedding_alvo   (distância de cosseno)
#   similarity = 1 - distance                   (no intervalo [0, 1])
#
# A comparação é feita no banco (sem transferir todas as escolas para o Perl)
# e devolve apenas top-k.
sub similar_to ($self, $co_entidade, $limit = 10, $co_municipio = undef) {
  # Filtro opcional por município (mantém a semântica "escola similar na
  # mesma cidade" do fluxo antigo). Montado dinamicamente para não usar
  # cast `::` (que colide com placeholders nomeados em outros helpers).
  my $muni_clause = defined $co_municipio ? 'AND ce.co_municipio = ?' : '';

  my $sql = <<~"SQL";
    SELECT s.co_entidade,
           1 - (s.embedding <=> q.embedding) AS similarity,
           s.embedding <=> q.embedding        AS distance
    FROM analytics.school_embedding s
    JOIN clean.censo_escolas ce
      ON ce.co_entidade = s.co_entidade
     AND ce.tp_situacao_funcionamento = 1
    CROSS JOIN (
      SELECT embedding FROM analytics.school_embedding WHERE co_entidade = ?
    ) q
    WHERE s.co_entidade <> ?
    $muni_clause
    ORDER BY s.embedding <=> q.embedding
    LIMIT ?
  SQL

  my @binds = ($co_entidade, $co_entidade);
  push @binds, $co_municipio if defined $co_municipio;
  push @binds, $limit;

  my $storage = $self->result_source->schema->storage;
  my $rows;
  $storage->dbh_do(
    sub ($me, $dbh) {
      $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
    }
  );

  return $rows // [];
}

1;
