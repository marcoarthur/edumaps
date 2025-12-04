use utf8;
package EduMaps::Schema::Result::Inep;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::Inep

=head1 DESCRIPTION

Dados limpos do INEP - Indicadores educacionais por escola e município

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.inep>

=cut

__PACKAGE__->table("clean.inep");

=head1 ACCESSORS

=head2 linha_original

  data_type: 'integer'
  is_nullable: 1

Número da linha original no CSV para auditoria

=head2 sg_uf

  data_type: 'text'
  is_nullable: 1

=head2 codigo_ibge

  data_type: 'varchar'
  is_nullable: 1
  size: 7

Código completo do município no padrão IBGE (7 dígitos)

=head2 no_municipio

  data_type: 'text'
  is_nullable: 1

=head2 id_escola

  data_type: 'bigint'
  is_nullable: 0

=head2 no_escola

  data_type: 'text'
  is_nullable: 1

=head2 rede

  data_type: 'text'
  is_nullable: 1

=head2 vl_aprovacao_2005_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2005_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2005_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2005_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2005_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2005_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2005

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2007_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2007_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2007_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2007_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2007_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2007_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2007

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2009_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2009_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2009_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2009_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2009_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2009_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2009

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2011_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2011_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2011_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2011_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2011_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2011_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2011

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2013_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2013_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2013_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2013_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2013_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2013_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2013

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2015_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2015_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2015_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2015_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2015_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2015_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2015

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2017_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2017_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2017_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2017_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2017_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2017_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2017

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2019_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2019_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2019_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2019_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2019_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2019_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2019

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2021_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2021_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2021_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2021_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2021_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2021_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2021

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2023_si_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2023_si

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2023_1

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2023_2

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2023_3

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_aprovacao_2023_4

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_indicador_rend_2023

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2005

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2005

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2005

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2007

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2007

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2007

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2009

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2009

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2009

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2011

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2011

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2011

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2013

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2013

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2013

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2015

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2015

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2015

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2017

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2017

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2017

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2019

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2019

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2019

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2021

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2021

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2021

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_matematica_2023

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_portugues_2023

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_nota_media_2023

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2005

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2007

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2009

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2011

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2013

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2015

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2017

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2019

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2021

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_observado_2023

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2007

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2009

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2011

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2013

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2015

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2017

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2019

  data_type: 'numeric'
  is_nullable: 1

=head2 vl_projecao_2021

  data_type: 'numeric'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "linha_original",
  { data_type => "integer", is_nullable => 1 },
  "sg_uf",
  { data_type => "text", is_nullable => 1 },
  "codigo_ibge",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "no_municipio",
  { data_type => "text", is_nullable => 1 },
  "id_escola",
  { data_type => "bigint", is_nullable => 0 },
  "no_escola",
  { data_type => "text", is_nullable => 1 },
  "rede",
  { data_type => "text", is_nullable => 1 },
  "vl_aprovacao_2005_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2005_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2005_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2005_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2005_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2005_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2005",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2007_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2007_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2007_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2007_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2007_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2007_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2007",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2009_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2009_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2009_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2009_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2009_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2009_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2009",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2011_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2011_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2011_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2011_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2011_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2011_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2011",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2013_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2013_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2013_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2013_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2013_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2013_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2013",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2015_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2015_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2015_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2015_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2015_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2015_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2015",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2017_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2017_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2017_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2017_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2017_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2017_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2017",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2019_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2019_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2019_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2019_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2019_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2019_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2019",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2021_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2021_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2021_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2021_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2021_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2021_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2021",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2023_si_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2023_si",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2023_1",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2023_2",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2023_3",
  { data_type => "numeric", is_nullable => 1 },
  "vl_aprovacao_2023_4",
  { data_type => "numeric", is_nullable => 1 },
  "vl_indicador_rend_2023",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2005",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2005",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2005",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2007",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2007",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2007",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2009",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2009",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2009",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2011",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2011",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2011",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2013",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2013",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2013",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2015",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2015",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2015",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2017",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2017",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2017",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2019",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2019",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2019",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2021",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2021",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2021",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_matematica_2023",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_portugues_2023",
  { data_type => "numeric", is_nullable => 1 },
  "vl_nota_media_2023",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2005",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2007",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2009",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2011",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2013",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2015",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2017",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2019",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2021",
  { data_type => "numeric", is_nullable => 1 },
  "vl_observado_2023",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2007",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2009",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2011",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2013",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2015",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2017",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2019",
  { data_type => "numeric", is_nullable => 1 },
  "vl_projecao_2021",
  { data_type => "numeric", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_escola>

=back

=cut

__PACKAGE__->set_primary_key("id_escola");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-03 21:38:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6kdtiVt1Ks6/+1zIKNA0BQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::Escolas',
  { 'foreign.codigo_inep' => 'self.id_escola' },
);

__PACKAGE__->belongs_to(
  'municipio',
  'EduMaps::Schema::Result::MunicipiosSp',
  { 'foreign.codigo_ibge' => 'self.codigo_ibge' },
);

1;
