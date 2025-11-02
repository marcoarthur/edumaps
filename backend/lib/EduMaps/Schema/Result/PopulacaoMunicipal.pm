use utf8;
package EduMaps::Schema::Result::PopulacaoMunicipal;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::PopulacaoMunicipal - Dados limpos de população municipal estimada - Fonte: IBGE

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<populacao_municipal>

=cut

__PACKAGE__->table("populacao_municipal");

=head1 ACCESSORS

=head2 linha_original

  data_type: 'integer'
  is_nullable: 1

Número da linha original no CSV para auditoria

=head2 nome_municipio

  data_type: 'text'
  is_nullable: 1

Nome do município

=head2 populacao_estimada

  data_type: 'integer'
  is_nullable: 1

População estimada do município (pode ser NULL para valores faltantes)

=head2 codigo_ibge

  data_type: 'varchar'
  is_nullable: 0
  size: 7

Código completo do município no padrão IBGE (UF + MUNIC) como varchar(7)

=cut

__PACKAGE__->add_columns(
  "linha_original",
  { data_type => "integer", is_nullable => 1 },
  "nome_municipio",
  { data_type => "text", is_nullable => 1 },
  "populacao_estimada",
  { data_type => "integer", is_nullable => 1 },
  "codigo_ibge",
  { data_type => "varchar", is_nullable => 0, size => 7 },
);

=head1 PRIMARY KEY

=over 4

=item * L</codigo_ibge>

=back

=cut

__PACKAGE__->set_primary_key("codigo_ibge");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-11-01 19:24:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lW4ee7eTUo2L7q2SLIkvEg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
