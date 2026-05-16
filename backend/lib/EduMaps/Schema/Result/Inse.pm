use utf8;
package EduMaps::Schema::Result::Inse;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::Inse

=head1 DESCRIPTION

Dados do Índice de Nível Socioeconômico (INSE) das escolas, calculado a partir do SAEB 2023.
  O INSE varia de 0 a 10 e é classificado em oito níveis (I a VIII). Quanto maior o nível, maior o capital econômico, cultural e social médio dos alunos da escola.
  Fonte: Microdados do SAEB / Inep. Arquivo original: inse_2023.csv.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.inse>

=cut

__PACKAGE__->table("clean.inse");

=head1 ACCESSORS

=head2 nu_ano_saeb

  data_type: 'integer'
  is_nullable: 0

Ano de referência do SAEB (2023).

=head2 co_uf

  data_type: 'integer'
  is_nullable: 1

Código da unidade da federação (IBGE).

=head2 sg_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 2

Sigla da unidade da federação.

=head2 no_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da unidade da federação.

=head2 co_municipio

  data_type: 'integer'
  is_nullable: 1

Código do município (IBGE, 7 dígitos).

=head2 no_municipio

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome do município.

=head2 id_escola

  data_type: 'bigint'
  is_nullable: 0

Código único da escola no Censo Escolar (INEP).

=head2 no_escola

  data_type: 'varchar'
  is_nullable: 1
  size: 200

Nome da escola.

=head2 tp_tipo_rede

  data_type: 'integer'
  is_nullable: 1

Tipo de rede de ensino: 1 = Federal, 2 = Estadual, 3 = Municipal, 4 = Privada.

=head2 tp_localizacao

  data_type: 'integer'
  is_nullable: 1

Localização da escola: 1 = Urbana, 2 = Rural.

=head2 tp_capital

  data_type: 'integer'
  is_nullable: 1

Indicador de capital: 1 = Sim (escola em capital de estado), 2 = Não.

=head2 qtd_alunos_inse

  data_type: 'integer'
  is_nullable: 1

Quantidade de alunos da escola que responderam ao questionário socioeconômico e tiveram INSE calculado.

=head2 media_inse

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4ac21a8)"]

Média do INSE dos alunos da escola (0 a 10). Valores mais altos indicam maior nível socioeconômico.

=head2 inse_classificacao

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Classificação da média da escola em níveis: Nível I (mais baixo) a Nível VIII (mais alto).

=head2 pc_nivel_1

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4b0e5f8)"]

Percentual (%) de alunos da escola classificados no Nível I de INSE (muito baixo).

=head2 pc_nivel_2

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4e43b00)"]

Percentual (%) de alunos no Nível II.

=head2 pc_nivel_3

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4acfa98)"]

Percentual (%) de alunos no Nível III.

=head2 pc_nivel_4

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e5738ba0)"]

Percentual (%) de alunos no Nível IV.

=head2 pc_nivel_5

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4b5f8c0)"]

Percentual (%) de alunos no Nível V.

=head2 pc_nivel_6

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4b6a348)"]

Percentual (%) de alunos no Nível VI.

=head2 pc_nivel_7

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e534c740)"]

Percentual (%) de alunos no Nível VII.

=head2 pc_nivel_8

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5637e4d31c78)"]

Percentual (%) de alunos no Nível VIII (muito alto).

=cut

__PACKAGE__->add_columns(
  "nu_ano_saeb",
  { data_type => "integer", is_nullable => 0 },
  "co_uf",
  { data_type => "integer", is_nullable => 1 },
  "sg_uf",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "no_uf",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_municipio",
  { data_type => "integer", is_nullable => 1 },
  "no_municipio",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "id_escola",
  { data_type => "bigint", is_nullable => 0 },
  "no_escola",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "tp_tipo_rede",
  { data_type => "integer", is_nullable => 1 },
  "tp_localizacao",
  { data_type => "integer", is_nullable => 1 },
  "tp_capital",
  { data_type => "integer", is_nullable => 1 },
  "qtd_alunos_inse",
  { data_type => "integer", is_nullable => 1 },
  "media_inse",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4ac21a8)"],
  },
  "inse_classificacao",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "pc_nivel_1",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4b0e5f8)"],
  },
  "pc_nivel_2",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4e43b00)"],
  },
  "pc_nivel_3",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4acfa98)"],
  },
  "pc_nivel_4",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e5738ba0)"],
  },
  "pc_nivel_5",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4b5f8c0)"],
  },
  "pc_nivel_6",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4b6a348)"],
  },
  "pc_nivel_7",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e534c740)"],
  },
  "pc_nivel_8",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5637e4d31c78)"],
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</nu_ano_saeb>

=item * L</id_escola>

=back

=cut

__PACKAGE__->set_primary_key("nu_ano_saeb", "id_escola");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-16 16:27:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WRliq4Ocr9a3hW8w57h5Ww


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.id_escola' },
);

1;
