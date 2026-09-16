use utf8;
package EduMaps::Schema::Result::SchoolEmbedding;

=head1 NAME

EduMaps::Schema::Result::SchoolEmbedding

=head1 DESCRIPTION

Embedding de 6 dimensões por escola (pgvector), usado para busca de
similaridade por cosseno. Derivado de C<clean.mv_escolas_scores>.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.school_embedding>

=cut

__PACKAGE__->table("analytics.school_embedding");

=head1 ACCESSORS

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 0

Código INEP (entidade) da escola.

=head2 embedding

  data_type: 'vector'
  is_nullable: 0

Vetor de 6 dimensões com os scores consolidados da escola.

=cut

__PACKAGE__->add_columns(
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "embedding",
  { data_type => "vector", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("co_entidade");

1;
