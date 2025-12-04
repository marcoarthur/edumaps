use utf8;
package EduMaps::Schema::Result::InepNotasDesagregadas;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::InepNotasDesagregadas

=head1 DESCRIPTION

Tabela de notas desagregadas por ano do SAEB/Prova Brasil (2005-2023). 
  Contém as notas padronizadas de Matemática e Língua Portuguesa por escola/ano.
  Fonte: Microdados do INEP transformados de formato wide para long.
  Última atualização: DD/MM/AAAA.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.inep_notas_desagregadas>

=cut

__PACKAGE__->table("clean.inep_notas_desagregadas");

=head1 ACCESSORS

=head2 id_escola

  data_type: 'bigint'
  is_nullable: 0

Identificador único da escola no Censo Escolar (código INEP). 
  Usado como chave estrangeira para outras tabelas do sistema.

=head2 no_escola

  data_type: 'text'
  is_nullable: 1

Nome oficial da escola conforme registro no Censo Escolar.

=head2 codigo_ibge

  data_type: 'varchar'
  is_nullable: 1
  size: 7

Código IBGE do município (7 dígitos). 
  Os 2 primeiros dígitos representam a UF, os 5 restantes o município.

=head2 no_municipio

  data_type: 'text'
  is_nullable: 1

Nome do município onde a escola está localizada.

=head2 sg_uf

  data_type: 'text'
  is_nullable: 1

Sigla da Unidade Federativa (2 letras). Ex: SP, RJ, MG.

=head2 rede

  data_type: 'text'
  is_nullable: 1

Rede de ensino a que pertence a escola. 
  Valores possíveis: Pública Federal, Pública Estadual, Pública Municipal, Privada.

=head2 ano

  data_type: 'integer'
  is_nullable: 0

Ano de aplicação da prova SAEB/Prova Brasil. 
  Série histórica de 2005 a 2023 (anos ímpares). 
  Formato: YYYY.

=head2 nota_mat

  data_type: 'numeric'
  is_nullable: 1

Nota padronizada em Matemática na escala SAEB. 
  Escala: 0-500 pontos. 
  Valores nulos indicam ausência de dados para o ano/escola.

=head2 nota_por

  data_type: 'numeric'
  is_nullable: 1

Nota padronizada em Língua Portuguesa na escala SAEB. 
  Escala: 0-500 pontos. 
  Valores nulos indicam ausência de dados para o ano/escola.

=head2 nota_media

  data_type: 'numeric'
  is_nullable: 1

Média aritmética simples das notas de Matemática e Português. 
  Calculada como (nota_mat + nota_por) / 2. 
  Pode ser nula se uma das notas for nula.

=head2 linha_original

  data_type: 'integer'
  is_nullable: 1

Número da linha na tabela original clean.inep. 
  Mantido para fins de auditoria e rastreabilidade. 
  Permite vincular ao registro fonte em caso de necessidade.

=cut

__PACKAGE__->add_columns(
  "id_escola",
  { data_type => "bigint", is_nullable => 0 },
  "no_escola",
  { data_type => "text", is_nullable => 1 },
  "codigo_ibge",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "no_municipio",
  { data_type => "text", is_nullable => 1 },
  "sg_uf",
  { data_type => "text", is_nullable => 1 },
  "rede",
  { data_type => "text", is_nullable => 1 },
  "ano",
  { data_type => "integer", is_nullable => 0 },
  "nota_mat",
  { data_type => "numeric", is_nullable => 1 },
  "nota_por",
  { data_type => "numeric", is_nullable => 1 },
  "nota_media",
  { data_type => "numeric", is_nullable => 1 },
  "linha_original",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_escola>

=item * L</ano>

=back

=cut

__PACKAGE__->set_primary_key("id_escola", "ano");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-04 13:27:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6cmyeQCCvgBh+Naq/k0wsQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
