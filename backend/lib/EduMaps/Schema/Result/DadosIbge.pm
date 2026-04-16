use utf8;
package EduMaps::Schema::Result::DadosIbge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::DadosIbge

=head1 DESCRIPTION

Dados do PIB municipal (SIDRA/IBGE), incluindo valores absolutos e participação percentual por setor econômico.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<dados_ibge>

=cut

__PACKAGE__->table("dados_ibge");

=head1 ACCESSORS

=head2 codigo_ibge

  data_type: 'text'
  is_nullable: 0

Código IBGE do município (7 dígitos), usado como chave de integração com outras tabelas geográficas.

=head2 ano

  data_type: 'integer'
  is_nullable: 0

Ano de referência dos dados do PIB municipal.

=head2 pib_total

  data_type: 'numeric'
  is_nullable: 1

Produto Interno Bruto total do município no ano, em reais correntes.

=head2 governo

  data_type: 'numeric'
  is_nullable: 1

Valor adicionado bruto da administração pública (setor governo), em reais correntes.

=head2 industria

  data_type: 'numeric'
  is_nullable: 1

Valor adicionado bruto do setor industrial, em reais correntes.

=head2 agro

  data_type: 'numeric'
  is_nullable: 1

Valor adicionado bruto da agropecuária, em reais correntes.

=head2 data_acessada

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

Timestamp indicando quando os dados foram coletados do SIDRA.

=head2 industria_percent

  data_type: 'numeric'
  is_nullable: 1

Participação do setor industrial no PIB municipal (industria / pib_total).

=head2 agro_percent

  data_type: 'numeric'
  is_nullable: 1

Participação da agropecuária no PIB municipal (agro / pib_total).

=head2 governo_percent

  data_type: 'numeric'
  is_nullable: 1

Participação da administração pública no PIB municipal (governo / pib_total).

=head2 servicos_percent

  data_type: 'numeric'
  is_nullable: 1

Participação estimada do setor de serviços no PIB municipal, calculada como complemento dos demais setores (1 - soma dos percentuais conhecidos).

=cut

__PACKAGE__->add_columns(
  "codigo_ibge",
  { data_type => "text", is_nullable => 0 },
  "ano",
  { data_type => "integer", is_nullable => 0 },
  "pib_total",
  { data_type => "numeric", is_nullable => 1 },
  "governo",
  { data_type => "numeric", is_nullable => 1 },
  "industria",
  { data_type => "numeric", is_nullable => 1 },
  "agro",
  { data_type => "numeric", is_nullable => 1 },
  "data_acessada",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "industria_percent",
  { data_type => "numeric", is_nullable => 1 },
  "agro_percent",
  { data_type => "numeric", is_nullable => 1 },
  "governo_percent",
  { data_type => "numeric", is_nullable => 1 },
  "servicos_percent",
  { data_type => "numeric", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</ano>

=item * L</codigo_ibge>

=back

=cut

__PACKAGE__->set_primary_key("ano", "codigo_ibge");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-16 12:31:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+KDNyYHcJu2LxGUwuwldiw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'municipio',
  'EduMaps::Schema::Result::MunicipiosSp',
  { 'foreign.codigo_ibge' => 'self.codigo_ibge' },
);
1;
