use utf8;
package MyApp::Schema::Result::Escola;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MyApp::Schema::Result::Escola

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

=head2 codigo_inep

  data_type: 'bigint'
  is_nullable: 0

=head2 uf

  data_type: 'text'
  is_nullable: 1

=head2 municipio

  data_type: 'text'
  is_nullable: 1

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

=head2 longitude

  data_type: 'double precision'
  is_nullable: 1

=head2 geom

  data_type: 'geometry'
  is_nullable: 1
  size: '16896,18'

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
  "geom",
  { data_type => "geometry", is_nullable => 1, size => "16896,18" },
);

=head1 PRIMARY KEY

=over 4

=item * L</codigo_inep>

=back

=cut

__PACKAGE__->set_primary_key("codigo_inep");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-09-29 09:05:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6DuRjPM9zwUQrs3MSlShhA


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'municipio',
  'MyApp::Schema::Result::MunicipiosSp',
  sub {
    my $args = shift;
    my $f_alias = $args->{foreign_alias};
    my $s_alias = $args->{self_alias};
    my $on_clause = sprintf "ST_Contains(%s.geog::geometry, %s.geom)", $f_alias, $s_alias;

    return \["$on_clause"];
  },
);

1;
