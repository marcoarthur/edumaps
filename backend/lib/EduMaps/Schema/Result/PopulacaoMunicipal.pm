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

=head1 TABLE: C<clean.populacao_municipal>

=cut

__PACKAGE__->table("clean.populacao_municipal");

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

=head2 faixa_0_4_anos

  data_type: 'integer'
  is_nullable: 1

População de 0 a 4 anos - Fonte: IBGE

=head2 faixa_5_9_anos

  data_type: 'integer'
  is_nullable: 1

População de 5 a 9 anos - Fonte: IBGE

=head2 faixa_10_14_anos

  data_type: 'integer'
  is_nullable: 1

População de 10 a 14 anos - Fonte: IBGE

=head2 faixa_15_19_anos

  data_type: 'integer'
  is_nullable: 1

População de 15 a 19 anos - Fonte: IBGE

=head2 faixa_20_24_anos

  data_type: 'integer'
  is_nullable: 1

População de 20 a 24 anos - Fonte: IBGE

=head2 faixa_30_34_anos

  data_type: 'integer'
  is_nullable: 1

População de 30 a 34 anos - Fonte: IBGE

=head2 faixa_35_39_anos

  data_type: 'integer'
  is_nullable: 1

População de 35 a 39 anos - Fonte: IBGE

=head2 faixa_40_44_anos

  data_type: 'integer'
  is_nullable: 1

População de 40 a 44 anos - Fonte: IBGE

=head2 faixa_45_49_anos

  data_type: 'integer'
  is_nullable: 1

População de 45 a 49 anos - Fonte: IBGE

=head2 faixa_50_54_anos

  data_type: 'integer'
  is_nullable: 1

População de 50 a 54 anos - Fonte: IBGE

=head2 faixa_55_59_anos

  data_type: 'integer'
  is_nullable: 1

População de 55 a 59 anos - Fonte: IBGE

=head2 faixa_60_64_anos

  data_type: 'integer'
  is_nullable: 1

População de 60 a 64 anos - Fonte: IBGE

=head2 faixa_65_69_anos

  data_type: 'integer'
  is_nullable: 1

População de 65 a 69 anos - Fonte: IBGE

=head2 faixa_70_74_anos

  data_type: 'integer'
  is_nullable: 1

População de 70 a 74 anos - Fonte: IBGE

=head2 faixa_75_79_anos

  data_type: 'integer'
  is_nullable: 1

População de 75 a 79 anos - Fonte: IBGE

=head2 faixa_80_84_anos

  data_type: 'integer'
  is_nullable: 1

População de 80 a 84 anos - Fonte: IBGE

=head2 faixa_85_89_anos

  data_type: 'integer'
  is_nullable: 1

População de 85 a 89 anos - Fonte: IBGE

=head2 faixa_95_99_anos

  data_type: 'integer'
  is_nullable: 1

População de 95 a 99 anos - Fonte: IBGE

=head2 faixa_100_mais

  data_type: 'integer'
  is_nullable: 1

População de 100 anos ou mais - Fonte: IBGE

=head2 pop_0_a_14

  data_type: 'integer'
  is_nullable: 1

População consolidada de 0 a 14 anos (soma das faixas)

=head2 pop_15_a_24

  data_type: 'integer'
  is_nullable: 1

População consolidada de 15 a 24 anos (soma das faixas)

=head2 pop_25_a_59

  data_type: 'integer'
  is_nullable: 1

População consolidada de 25 a 59 anos (soma das faixas 30-59)

=head2 pop_60_mais

  data_type: 'integer'
  is_nullable: 1

População consolidada de 60 anos ou mais (soma das faixas)

=head2 total_soma_faixas

  data_type: 'integer'
  is_nullable: 1

Soma total de todas as faixas etárias (para validação)

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
  "faixa_0_4_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_5_9_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_10_14_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_15_19_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_20_24_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_30_34_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_35_39_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_40_44_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_45_49_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_50_54_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_55_59_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_60_64_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_65_69_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_70_74_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_75_79_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_80_84_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_85_89_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_95_99_anos",
  { data_type => "integer", is_nullable => 1 },
  "faixa_100_mais",
  { data_type => "integer", is_nullable => 1 },
  "pop_0_a_14",
  { data_type => "integer", is_nullable => 1 },
  "pop_15_a_24",
  { data_type => "integer", is_nullable => 1 },
  "pop_25_a_59",
  { data_type => "integer", is_nullable => 1 },
  "pop_60_mais",
  { data_type => "integer", is_nullable => 1 },
  "total_soma_faixas",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</codigo_ibge>

=back

=cut

__PACKAGE__->set_primary_key("codigo_ibge");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-19 08:55:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HUnW+IPL2+NFt4FQqbP7zA


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->has_one(
  'municipio',
  'EduMaps::Schema::Result::MunicipiosSp',
  'codigo_ibge'
);

__PACKAGE__->might_have(
  'metrica',
  'EduMaps::Schema::Result::MetricasAcessibilidadeMunicipios',
  'codigo_ibge'
);

1;
