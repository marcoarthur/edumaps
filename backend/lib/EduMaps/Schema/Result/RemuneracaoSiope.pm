use utf8;
package EduMaps::Schema::Result::RemuneracaoSiope;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::RemuneracaoSiope

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<remuneracao_siope>

=cut

__PACKAGE__->table("remuneracao_siope");

=head1 ACCESSORS

=head2 linha_original

  data_type: 'integer'
  is_nullable: 0

=head2 tipo

  data_type: 'text'
  is_nullable: 1

=head2 nu_periodo

  data_type: 'integer'
  is_nullable: 1

=head2 sig_uf

  data_type: 'text'
  is_nullable: 1

=head2 cod_municipio

  data_type: 'text'
  is_nullable: 1

=head2 no_profissional

  data_type: 'text'
  is_nullable: 1

=head2 codigo_inep

  data_type: 'bigint'
  is_nullable: 1

=head2 no_razao_social

  data_type: 'text'
  is_nullable: 1

=head2 situacao_profissional

  data_type: 'text'
  is_nullable: 1

=head2 tipo_categoria

  data_type: 'text'
  is_nullable: 1

=head2 carga_horaria

  data_type: 'integer'
  is_nullable: 1

=head2 salario

  data_type: 'numeric'
  is_nullable: 1

=head2 valor_minimo_fundeb

  data_type: 'numeric'
  is_nullable: 1

=head2 valor_maximo_fundeb

  data_type: 'numeric'
  is_nullable: 1

=head2 valor_outros

  data_type: 'numeric'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "linha_original",
  { data_type => "integer", is_nullable => 0 },
  "tipo",
  { data_type => "text", is_nullable => 1 },
  "nu_periodo",
  { data_type => "integer", is_nullable => 1 },
  "sig_uf",
  { data_type => "text", is_nullable => 1 },
  "cod_municipio",
  { data_type => "text", is_nullable => 1 },
  "no_profissional",
  { data_type => "text", is_nullable => 1 },
  "codigo_inep",
  { data_type => "bigint", is_nullable => 1 },
  "no_razao_social",
  { data_type => "text", is_nullable => 1 },
  "situacao_profissional",
  { data_type => "text", is_nullable => 1 },
  "tipo_categoria",
  { data_type => "text", is_nullable => 1 },
  "carga_horaria",
  { data_type => "integer", is_nullable => 1 },
  "salario",
  { data_type => "numeric", is_nullable => 1 },
  "valor_minimo_fundeb",
  { data_type => "numeric", is_nullable => 1 },
  "valor_maximo_fundeb",
  { data_type => "numeric", is_nullable => 1 },
  "valor_outros",
  { data_type => "numeric", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</linha_original>

=back

=cut

__PACKAGE__->set_primary_key("linha_original");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-11-02 23:39:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:i7CEXijElQSxhWilXKx6jw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
