use utf8;
package EduMaps::Schema::Result::RemuneracaoMunicipal;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::RemuneracaoMunicipal

=head1 DESCRIPTION

Dados com as remunerações dos profissionais da educação da rede municipal

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<remuneracao_municipal>

=cut

__PACKAGE__->table("remuneracao_municipal");

=head1 ACCESSORS

=head2 categoria

  data_type: 'text'
  is_nullable: 1

Categoria do profissional com detalhes

=head2 tipo

  data_type: 'text'
  is_nullable: 1

Categoria tipificada

=head2 ano

  data_type: 'integer'
  is_nullable: 1

Ano do pagamento

=head2 mes

  data_type: 'text'
  is_nullable: 1

Mês do pagamento

=head2 nome_profissional

  data_type: 'text'
  is_nullable: 1

Nome completo do profissional

=head2 cod_municipio

  data_type: 'bigint'
  is_nullable: 1

Código do município formato antigo 6 dígitos do IBGE

=head2 cod_inep

  data_type: 'bigint'
  is_nullable: 1

Código do INEP referente à escola

=head2 escola

  data_type: 'text'
  is_nullable: 1

Nome da Escola

=head2 carga_horaria

  data_type: 'integer'
  is_nullable: 1

Carga horária semanal do profissional

=head2 cpf

  data_type: 'text'
  is_nullable: 1

CPF do profissional

=head2 situacao

  data_type: 'text'
  is_nullable: 1

Situação de contrato

=head2 segmento_ensino

  data_type: 'text'
  is_nullable: 1

Segmento do ensino onde atua

=head2 salario_base

  data_type: 'numeric'
  is_nullable: 1

Salário Base do profissional

=head2 salario_fundeb_max

  data_type: 'numeric'
  is_nullable: 1

Com participação de 70% do Fundeb

=head2 salario_fundeb_min

  data_type: 'numeric'
  is_nullable: 1

Com participação de 30% do Fundeb

=head2 salario_outros

  data_type: 'numeric'
  is_nullable: 1

Outras fontes de receita no salário

=head2 salario_total

  data_type: 'numeric'
  is_nullable: 1

Total Salarial do profissional

=head2 rede

  data_type: 'varchar'
  is_nullable: 1
  size: 12

=cut

__PACKAGE__->add_columns(
  "categoria",
  { data_type => "text", is_nullable => 1 },
  "tipo",
  { data_type => "text", is_nullable => 1 },
  "ano",
  { data_type => "integer", is_nullable => 1 },
  "mes",
  { data_type => "text", is_nullable => 1 },
  "nome_profissional",
  { data_type => "text", is_nullable => 1 },
  "cod_municipio",
  { data_type => "bigint", is_nullable => 1 },
  "cod_inep",
  { data_type => "bigint", is_nullable => 1 },
  "escola",
  { data_type => "text", is_nullable => 1 },
  "carga_horaria",
  { data_type => "integer", is_nullable => 1 },
  "cpf",
  { data_type => "text", is_nullable => 1 },
  "situacao",
  { data_type => "text", is_nullable => 1 },
  "segmento_ensino",
  { data_type => "text", is_nullable => 1 },
  "salario_base",
  { data_type => "numeric", is_nullable => 1 },
  "salario_fundeb_max",
  { data_type => "numeric", is_nullable => 1 },
  "salario_fundeb_min",
  { data_type => "numeric", is_nullable => 1 },
  "salario_outros",
  { data_type => "numeric", is_nullable => 1 },
  "salario_total",
  { data_type => "numeric", is_nullable => 1 },
  "rede",
  { data_type => "varchar", is_nullable => 1, size => 12 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-11-14 10:03:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dGHWQhmTaYwAWtXFySOvyQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::Escolas',
  {'foreign.codigo_inep' => 'self.cod_inep'},
);

1;
