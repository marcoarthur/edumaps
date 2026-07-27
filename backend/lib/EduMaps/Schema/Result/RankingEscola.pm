use utf8;
package EduMaps::Schema::Result::RankingEscola;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::RankingEscola

=head1 DESCRIPTION

Rankings pré-computados por escola/indicador/rede. Substitui o cálculo via RANK() OVER (...) feito a cada requisição em EduMaps::Model::Rank::School. Recalculada por job batch (ver refresh_ranking_escola.sql), disparado após o refresh de clean.mv_escolas_scores e a carga do IDEB.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.ranking_escola>

=cut

__PACKAGE__->table("analytics.ranking_escola");

=head1 ACCESSORS

=head2 indicador_id

  data_type: 'text'
  is_nullable: 0

Chave do indicator_registry do model Perl (ex.: infraestrutura, ideb_anos_iniciais, nota_matematica_medio).

=head2 rede

  data_type: 'text'
  default_value: 'todas'
  is_nullable: 0

Rede de ensino usada como partição do ranking: todas | municipal | estadual | privada. "todas" = sem filtro de rede (equivalente a network=undef no model).

=head2 id_escola

  data_type: 'integer'
  is_nullable: 0

Código INEP da escola (co_entidade / id_escola conforme a fonte).

=head2 ano

  data_type: 'integer'
  is_nullable: 0

Ano de referência do dado-fonte (nu_ano_censo para indicadores "mv"; ano do IDEB para indicadores "ideb") usado para calcular esta linha.

=head2 valor

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x55ddac2e9260)"]

Valor do indicador para a escola no ano de referência (equivalente a "value" retornado pela query original).

=head2 rank_municipio

  data_type: 'integer'
  is_nullable: 1

Posição da escola no município (RANK() particionado por co_municipio, dentro da rede filtrada).

=head2 total_municipio

  data_type: 'integer'
  is_nullable: 1

Total de escolas comparadas no município para esse indicador/rede/ano.

=head2 rank_estado

  data_type: 'integer'
  is_nullable: 1

Posição da escola no estado.

=head2 total_estado

  data_type: 'integer'
  is_nullable: 1

Total de escolas comparadas no estado.

=head2 rank_nacional

  data_type: 'integer'
  is_nullable: 1

Posição da escola nacionalmente. Sempre computado no refresh, independente do opts.national usado na consulta em tempo real.

=head2 total_nacional

  data_type: 'integer'
  is_nullable: 1

Total de escolas comparadas nacionalmente.

=head2 data_atualizacao

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

Timestamp da última recomputação desta linha pelo job de refresh.

=cut

__PACKAGE__->add_columns(
  "indicador_id",
  { data_type => "text", is_nullable => 0 },
  "rede",
  { data_type => "text", default_value => "todas", is_nullable => 0 },
  "id_escola",
  { data_type => "integer", is_nullable => 0 },
  "ano",
  { data_type => "integer", is_nullable => 0 },
  "valor",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x55ddac2e9260)"],
  },
  "rank_municipio",
  { data_type => "integer", is_nullable => 1 },
  "total_municipio",
  { data_type => "integer", is_nullable => 1 },
  "rank_estado",
  { data_type => "integer", is_nullable => 1 },
  "total_estado",
  { data_type => "integer", is_nullable => 1 },
  "rank_nacional",
  { data_type => "integer", is_nullable => 1 },
  "total_nacional",
  { data_type => "integer", is_nullable => 1 },
  "data_atualizacao",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</indicador_id>

=item * L</rede>

=item * L</id_escola>

=back

=cut

__PACKAGE__->set_primary_key("indicador_id", "rede", "id_escola");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-07-26 20:57:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:C4iXSYRspqqaWCPBGGuSeg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  {'foreign.co_entidade' => 'self.id_escola'},
);

1;
