use utf8;
package EduMaps::Schema::Result::Escolas;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::Escolas - Dados limpos de escolas com geometrias georreferenciadas

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<escolas>

=cut

__PACKAGE__->table("escolas");

=head1 ACCESSORS

=head2 restricao_atendimento

  data_type: 'text'
  is_nullable: 1

=head2 escola

  data_type: 'text'
  is_nullable: 1

Nome da escola

=head2 codigo_inep

  data_type: 'bigint'
  is_nullable: 0

Código INEP único da escola

=head2 uf

  data_type: 'text'
  is_nullable: 1

Unidade Federativa

=head2 municipio

  data_type: 'text'
  is_nullable: 1

Município onde a escola está localizada

=head2 localizacao

  data_type: 'text'
  is_nullable: 1

=head2 localidade_diferenciada

  data_type: 'text'
  is_nullable: 1

=head2 categoria_administrativa

  data_type: 'text'
  is_nullable: 1

=head2 endereco

  data_type: 'text'
  is_nullable: 1

=head2 telefone

  data_type: 'text'
  is_nullable: 1

=head2 dependencia_administrativa

  data_type: 'text'
  is_nullable: 1

=head2 categoria_escola_privada

  data_type: 'text'
  is_nullable: 1

=head2 conveniada_poder_publico

  data_type: 'text'
  is_nullable: 1

=head2 regulamentacao_conselho

  data_type: 'text'
  is_nullable: 1

=head2 porte_escola

  data_type: 'text'
  is_nullable: 1

=head2 etapas_modalidades

  data_type: 'text'
  is_nullable: 1

=head2 outras_ofertas

  data_type: 'text'
  is_nullable: 1

=head2 latitude

  data_type: 'double precision'
  is_nullable: 1

Latitude em graus decimais (WGS84)

=head2 longitude

  data_type: 'double precision'
  is_nullable: 1

Longitude em graus decimais (WGS84)

=head2 geometry

  data_type: 'geometry'
  is_nullable: 1
  size: '16896,18'

Geometria do ponto da escola em SIRGAS 2000 (4674)

=cut

__PACKAGE__->add_columns(
  "restricao_atendimento",
  { data_type => "text", is_nullable => 1 },
  "escola",
  { data_type => "text", is_nullable => 1 },
  "codigo_inep",
  { data_type => "bigint", is_nullable => 0 },
  "uf",
  { data_type => "text", is_nullable => 1 },
  "municipio",
  { data_type => "text", is_nullable => 1 },
  "localizacao",
  { data_type => "text", is_nullable => 1 },
  "localidade_diferenciada",
  { data_type => "text", is_nullable => 1 },
  "categoria_administrativa",
  { data_type => "text", is_nullable => 1 },
  "endereco",
  { data_type => "text", is_nullable => 1 },
  "telefone",
  { data_type => "text", is_nullable => 1 },
  "dependencia_administrativa",
  { data_type => "text", is_nullable => 1 },
  "categoria_escola_privada",
  { data_type => "text", is_nullable => 1 },
  "conveniada_poder_publico",
  { data_type => "text", is_nullable => 1 },
  "regulamentacao_conselho",
  { data_type => "text", is_nullable => 1 },
  "porte_escola",
  { data_type => "text", is_nullable => 1 },
  "etapas_modalidades",
  { data_type => "text", is_nullable => 1 },
  "outras_ofertas",
  { data_type => "text", is_nullable => 1 },
  "latitude",
  { data_type => "double precision", is_nullable => 1 },
  "longitude",
  { data_type => "double precision", is_nullable => 1 },
  "geometry",
  { data_type => "geometry", is_nullable => 1, size => "16896,18" },
);

=head1 PRIMARY KEY

=over 4

=item * L</codigo_inep>

=back

=cut

__PACKAGE__->set_primary_key("codigo_inep");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-10-30 10:55:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:x5w+zRZq3NLv+oTj8bMGLQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->might_have(
  'inep',
  'EduMaps::Schema::Result::Inep',
  {'foreign.id_escola' => 'self.codigo_inep' },
);

__PACKAGE__->has_many(
  'folha_pagamentos',
  'EduMaps::Schema::Result::RemuneracaoMunicipal',
  {'foreign.cod_inep' => 'self.codigo_inep'}
);

__PACKAGE__->belongs_to(
  'municipio',
  'EduMaps::Schema::Result::MunicipiosSp',
  sub {
    my $args = shift;
    my ($foreign_a, $self_a) = ($args->{foreign_alias}, $args->{self_alias});
    my $on_join_clause = sprintf "ST_Contains(%s.geometry::geometry, %s.geometry)", $foreign_a, $self_a;
    return \[$on_join_clause];
  },
);

1;
