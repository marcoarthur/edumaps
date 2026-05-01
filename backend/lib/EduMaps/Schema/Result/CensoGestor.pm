use utf8;
package EduMaps::Schema::Result::CensoGestor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::CensoGestor - Gestores Escolares da Educação Básica - Censo Escolar 2025

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<censo_gestor>

=cut

__PACKAGE__->table("censo_gestor");

=head1 ACCESSORS

=head2 nu_ano_censo

  data_type: 'integer'
  is_nullable: 0

Ano do Censo Escolar

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 0

Código único da escola no Censo Escolar (INEP)

=head2 qt_gest_bas

  data_type: 'integer'
  is_nullable: 1

Número total de gestores escolares da educação básica

=head2 qt_gest_bas_fem

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - sexo feminino

=head2 qt_gest_bas_masc

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - sexo masculino

=head2 qt_gest_bas_nd

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - cor/raça não declarada

=head2 qt_gest_bas_branca

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - cor/raça branca

=head2 qt_gest_bas_preta

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - cor/raça preta

=head2 qt_gest_bas_parda

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - cor/raça parda

=head2 qt_gest_bas_amarela

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - cor/raça amarela

=head2 qt_gest_bas_indigena

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - cor/raça indígena

=head2 qt_gest_bas_nacio_brasileira

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - nacionalidade brasileira

=head2 qt_gest_bas_nacio_estrang

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - nacionalidade estrangeira

=head2 qt_gest_bas_0_24

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade até 24 anos (ref: última quarta-feira de maio)

=head2 qt_gest_bas_25_29

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade entre 25 e 29 anos

=head2 qt_gest_bas_30_39

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade entre 30 e 39 anos

=head2 qt_gest_bas_40_49

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade entre 40 e 49 anos

=head2 qt_gest_bas_50_54

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade entre 50 e 54 anos

=head2 qt_gest_bas_55_59

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade entre 55 e 59 anos

=head2 qt_gest_bas_60_mais

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - idade 60 anos ou mais

=head2 qt_gest_bas_pcd

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares com deficiência, TEA ou superdotação

=head2 qt_gest_bas_zr_urb

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - residentes em zona urbana

=head2 qt_gest_bas_zr_rur

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - residentes em zona rural

=head2 qt_gest_bas_zr_na

  data_type: 'integer'
  is_nullable: 1

Número de gestores escolares - residentes no exterior (não aplicável)

=head2 qt_gest_bas_esco_ef

  data_type: 'integer'
  is_nullable: 1

Maior escolaridade concluída - Ensino Fundamental

=head2 qt_gest_bas_esco_em

  data_type: 'integer'
  is_nullable: 1

Maior escolaridade concluída - Ensino Médio

=head2 qt_gest_bas_esco_sup_grad

  data_type: 'integer'
  is_nullable: 1

Maior escolaridade concluída - Educação Superior (Graduação)

=head2 qt_gest_bas_esco_sup_grad_licen

  data_type: 'integer'
  is_nullable: 1

Maior escolaridade concluída - Educação Superior (Licenciatura)

=head2 qt_gest_bas_esco_sup_grad_slicen

  data_type: 'integer'
  is_nullable: 1

Maior escolaridade concluída - Educação Superior (Sem Licenciatura)

=head2 qt_gest_bas_esco_sup_pos_espec

  data_type: 'integer'
  is_nullable: 1

Pós-Graduação concluída - Especialização

=head2 qt_gest_bas_esco_sup_pos_mestra

  data_type: 'integer'
  is_nullable: 1

Pós-Graduação concluída - Mestrado

=head2 qt_gest_bas_esco_sup_pos_douto

  data_type: 'integer'
  is_nullable: 1

Pós-Graduação concluída - Doutorado

=head2 qt_gest_bas_esco_sup_pos_nenhum

  data_type: 'integer'
  is_nullable: 1

Pós-Graduação concluída - Não tem pós-graduação

=head2 qt_gest_bas_vinculo_concur

  data_type: 'integer'
  is_nullable: 1

Vínculo (escola pública) - Concursado/efetivo/estável

=head2 qt_gest_bas_vinculo_contra

  data_type: 'integer'
  is_nullable: 1

Vínculo (escola pública) - Contrato temporário

=head2 qt_gest_bas_vinculo_terceir

  data_type: 'integer'
  is_nullable: 1

Vínculo (escola pública) - Contrato terceirizado

=head2 qt_gest_bas_vinculo_clt

  data_type: 'integer'
  is_nullable: 1

Vínculo (escola pública) - Contrato CLT

=head2 qt_gest_bas_diretor

  data_type: 'integer'
  is_nullable: 1

Cargo do gestor - Diretor

=head2 qt_gest_bas_outro

  data_type: 'integer'
  is_nullable: 1

Cargo do gestor - Outro cargo

=head2 qt_gest_bas_acesso_cargo_prop

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Proprietário/sócio (escola privada)

=head2 qt_gest_bas_acesso_cargo_indic

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Indicação/escolha da gestão

=head2 qt_gest_bas_acesso_cargo_sel

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Processo seletivo + nomeação

=head2 qt_gest_bas_acesso_cargo_conca

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Concurso público (escola pública)

=head2 qt_gest_bas_acesso_cargo_eleic

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Processo eleitoral com comunidade (escola pública)

=head2 qt_gest_bas_acesso_cargo_p_sel

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Processo seletivo + eleição com comunidade

=head2 qt_gest_bas_acesso_cargo_outro

  data_type: 'integer'
  is_nullable: 1

Critério de acesso - Outro critério

=head2 qt_gest_bas_espec_cre

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para creche (0-3 anos)

=head2 qt_gest_bas_espec_pre_escola

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para pré-escola (4-5 anos)

=head2 qt_gest_bas_espec_anos_iniciais

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para anos iniciais do EF

=head2 qt_gest_bas_espec_anos_finais

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para anos finais do EF

=head2 qt_gest_bas_espec_ens_medio

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para ensino médio

=head2 qt_gest_bas_espec_eja

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para EJA

=head2 qt_gest_bas_espec_ed_especial

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para educação especial

=head2 qt_gest_bas_espec_bil_surdos

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Educação bilíngue de surdos

=head2 qt_gest_bas_espec_ed_indigena

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Específico para educação indígena

=head2 qt_gest_bas_espec_campo

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Educação do Campo

=head2 qt_gest_bas_espec_ambiental

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Educação Ambiental

=head2 qt_gest_bas_espec_dir_humanos

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Educação em direitos humanos

=head2 qt_gest_bas_espec_div_sexual

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Gênero e Diversidade Sexual

=head2 qt_gest_bas_espec_dir_adolesc

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Direitos de criança e adolescente

=head2 qt_gest_bas_espec_afro

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Relações étnico-raciais e cultura afro

=head2 qt_gest_bas_espec_gestao

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Gestão escolar

=head2 qt_gest_bas_espec_educ_tic

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Educação e TIC

=head2 qt_gest_bas_espec_outros

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Outros cursos

=head2 qt_gest_bas_espec_nenhum

  data_type: 'integer'
  is_nullable: 1

Formação continuada (≥80h) - Nenhum curso

=cut

__PACKAGE__->add_columns(
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 0 },
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "qt_gest_bas",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_fem",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_masc",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_nd",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_branca",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_preta",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_parda",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_amarela",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_indigena",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_nacio_brasileira",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_nacio_estrang",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_0_24",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_25_29",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_30_39",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_40_49",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_50_54",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_55_59",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_60_mais",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_pcd",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_zr_urb",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_zr_rur",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_zr_na",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_ef",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_em",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_grad",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_grad_licen",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_grad_slicen",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_pos_espec",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_pos_mestra",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_pos_douto",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_pos_nenhum",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_vinculo_concur",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_vinculo_contra",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_vinculo_terceir",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_vinculo_clt",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_diretor",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_outro",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_prop",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_indic",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_sel",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_conca",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_eleic",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_p_sel",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_outro",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_pre_escola",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_anos_iniciais",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_anos_finais",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_ens_medio",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_ed_especial",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_bil_surdos",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_ed_indigena",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_campo",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_ambiental",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_dir_humanos",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_div_sexual",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_dir_adolesc",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_afro",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_gestao",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_educ_tic",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_outros",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_espec_nenhum",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</nu_ano_censo>

=item * L</co_entidade>

=back

=cut

__PACKAGE__->set_primary_key("nu_ano_censo", "co_entidade");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-29 08:53:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aNQnK4Nl3JLUFTFYs5pmLQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.co_entidade' },
);

1;
