use utf8;
package EduMaps::Schema::Result::MvEscolasScores;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::MvEscolasScores

=head1 DESCRIPTION

Scores das escolas ativas calculados a partir do Censo Escolar. Escala 0-10, quanto maior melhor. Atualizar com REFRESH MATERIALIZED VIEW.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.mv_escolas_scores>

=cut

__PACKAGE__->table("clean.mv_escolas_scores");

=head1 ACCESSORS

=head2 nu_ano_censo

  data_type: 'integer'
  is_nullable: 1

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 1

=head2 score_capacidade_atendimento

  data_type: 'numeric'
  is_nullable: 1

Base: densidade aluno-sala, diversidade de etapas, tempo integral, alimentação.

=head2 score_infraestrutura

  data_type: 'numeric'
  is_nullable: 1

Média de quatro categorias: básico, pedagógico, acessibilidade, tecnologia.

=head2 score_capacitacao_docente

  data_type: 'numeric'
  is_nullable: 1

Formação superior, pós-graduação, vínculo efetivo, especializações.

=head2 score_diversidade_discente

  data_type: 'numeric'
  is_nullable: 1

Diversidade racial, gênero, inclusão PcD, oferta EJA.

=head2 score_capacidade_gestora

  data_type: 'numeric'
  is_nullable: 1

Qualificação dos gestores, formação em gestão, proporção gestor/aluno, órgãos colegiados, acesso meritocrático.

=head2 score_sustentabilidade

  data_type: 'numeric'
  is_nullable: 1

Energia renovável, gestão de resíduos, área verde/plantio, educação ambiental.

=head2 data_atualizacao

  data_type: 'timestamp with time zone'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 1 },
  "co_entidade",
  { data_type => "bigint", is_nullable => 1 },
  "score_capacidade_atendimento",
  { data_type => "numeric", is_nullable => 1 },
  "score_infraestrutura",
  { data_type => "numeric", is_nullable => 1 },
  "score_capacitacao_docente",
  { data_type => "numeric", is_nullable => 1 },
  "score_diversidade_discente",
  { data_type => "numeric", is_nullable => 1 },
  "score_capacidade_gestora",
  { data_type => "numeric", is_nullable => 1 },
  "score_sustentabilidade",
  { data_type => "numeric", is_nullable => 1 },
  "data_atualizacao",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<idx_mv_scores_pk>

=over 4

=item * L</nu_ano_censo>

=item * L</co_entidade>

=back

=cut

__PACKAGE__->add_unique_constraint("idx_mv_scores_pk", ["nu_ano_censo", "co_entidade"]);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-25 15:03:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:S9xJ8wfUzBEPadkaSfydtA


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 
    'foreign.co_entidade' => 'self.co_entidade',
    'foreign.nu_ano_censo' => 'self.nu_ano_censo',
  },
);

1;
