use utf8;
package EduMaps::Schema::Result::CensoMatriculas;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::CensoMatriculas

=head1 DESCRIPTION

Matrículas do Censo Escolar 2025 por escola (CO_ENTIDADE) e ano

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<censo_matriculas>

=cut

__PACKAGE__->table("censo_matriculas");

=head1 ACCESSORS

=head2 nu_ano_censo

  data_type: 'integer'
  is_nullable: 0

Ano do censo (2025)

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 0

Código único da escola (mesmo da tabela clean.censo_escolas)

=head2 qt_mat_bas

  data_type: 'integer'
  is_nullable: 1

Total de matrículas na educação básica

=head2 qt_mat_inf

  data_type: 'integer'
  is_nullable: 1

Matrículas na educação infantil

=head2 qt_mat_inf_cre

  data_type: 'integer'
  is_nullable: 1

Matrículas em creche (educação infantil)

=head2 qt_mat_inf_pre

  data_type: 'integer'
  is_nullable: 1

Matrículas na pré-escola

=head2 qt_mat_fund

  data_type: 'integer'
  is_nullable: 1

Matrículas no ensino fundamental

=head2 qt_mat_fund_ai

  data_type: 'integer'
  is_nullable: 1

Matrículas nos anos iniciais do fundamental

=head2 qt_mat_fund_ai_1

  data_type: 'integer'
  is_nullable: 1

1º ano do fundamental (anos iniciais)

=head2 qt_mat_fund_ai_2

  data_type: 'integer'
  is_nullable: 1

2º ano do fundamental (anos iniciais)

=head2 qt_mat_fund_ai_3

  data_type: 'integer'
  is_nullable: 1

3º ano do fundamental (anos iniciais)

=head2 qt_mat_fund_ai_4

  data_type: 'integer'
  is_nullable: 1

4º ano do fundamental (anos iniciais)

=head2 qt_mat_fund_ai_5

  data_type: 'integer'
  is_nullable: 1

5º ano do fundamental (anos iniciais)

=head2 qt_mat_fund_af

  data_type: 'integer'
  is_nullable: 1

Matrículas nos anos finais do fundamental

=head2 qt_mat_fund_af_6

  data_type: 'integer'
  is_nullable: 1

6º ano do fundamental (anos finais)

=head2 qt_mat_fund_af_7

  data_type: 'integer'
  is_nullable: 1

7º ano do fundamental (anos finais)

=head2 qt_mat_fund_af_8

  data_type: 'integer'
  is_nullable: 1

8º ano do fundamental (anos finais)

=head2 qt_mat_fund_af_9

  data_type: 'integer'
  is_nullable: 1

9º ano do fundamental (anos finais)

=head2 qt_mat_med

  data_type: 'integer'
  is_nullable: 1

Matrículas no ensino médio

=head2 qt_mat_med_prop

  data_type: 'integer'
  is_nullable: 1

Ensino médio – proposta pedagógica

=head2 qt_mat_med_prop_1

  data_type: 'integer'
  is_nullable: 1

Ensino médio – 1ª série (proposta)

=head2 qt_mat_med_prop_2

  data_type: 'integer'
  is_nullable: 1

Ensino médio – 2ª série (proposta)

=head2 qt_mat_med_prop_3

  data_type: 'integer'
  is_nullable: 1

Ensino médio – 3ª série (proposta)

=head2 qt_mat_med_prop_4

  data_type: 'integer'
  is_nullable: 1

Ensino médio – 4ª série (proposta)

=head2 qt_mat_med_prop_ns

  data_type: 'integer'
  is_nullable: 1

Ensino médio – série não especificada

=head2 qt_mat_med_iftp_ct

  data_type: 'integer'
  is_nullable: 1

Ensino médio integrado à formação técnica – curso técnico

=head2 qt_mat_med_iftp_ct_1

  data_type: 'integer'
  is_nullable: 1

IFTP/CT – 1ª série

=head2 qt_mat_med_iftp_ct_2

  data_type: 'integer'
  is_nullable: 1

IFTP/CT – 2ª série

=head2 qt_mat_med_iftp_ct_3

  data_type: 'integer'
  is_nullable: 1

IFTP/CT – 3ª série

=head2 qt_mat_med_iftp_ct_4

  data_type: 'integer'
  is_nullable: 1

IFTP/CT – 4ª série

=head2 qt_mat_med_iftp_ct_ns

  data_type: 'integer'
  is_nullable: 1

IFTP/CT – série não especificada

=head2 qt_mat_med_iftp_qp

  data_type: 'integer'
  is_nullable: 1

Ensino médio integrado à formação técnica – qualificação profissional

=head2 qt_mat_med_iftp_qp_1

  data_type: 'integer'
  is_nullable: 1

IFTP/QP – 1ª série

=head2 qt_mat_med_iftp_qp_2

  data_type: 'integer'
  is_nullable: 1

IFTP/QP – 2ª série

=head2 qt_mat_med_iftp_qp_3

  data_type: 'integer'
  is_nullable: 1

IFTP/QP – 3ª série

=head2 qt_mat_med_iftp_qp_4

  data_type: 'integer'
  is_nullable: 1

IFTP/QP – 4ª série

=head2 qt_mat_med_iftp_qp_ns

  data_type: 'integer'
  is_nullable: 1

IFTP/QP – série não especificada

=head2 qt_mat_med_nm

  data_type: 'integer'
  is_nullable: 1

Ensino médio – normal/magistério

=head2 qt_mat_med_nm_1

  data_type: 'integer'
  is_nullable: 1

Normal/magistério – 1ª série

=head2 qt_mat_med_nm_2

  data_type: 'integer'
  is_nullable: 1

Normal/magistério – 2ª série

=head2 qt_mat_med_nm_3

  data_type: 'integer'
  is_nullable: 1

Normal/magistério – 3ª série

=head2 qt_mat_med_nm_4

  data_type: 'integer'
  is_nullable: 1

Normal/magistério – 4ª série

=head2 qt_mat_med_ifa

  data_type: 'integer'
  is_nullable: 1

Ensino médio – itinerários formativos articulados (IFA)

=head2 qt_mat_med_ifa_ling

  data_type: 'integer'
  is_nullable: 1

IFA – Linguagens

=head2 qt_mat_med_ifa_ling_mt

  data_type: 'integer'
  is_nullable: 1

IFA/Linguagens – ofertado em mais de um turno

=head2 qt_mat_med_ifa_ling_otme

  data_type: 'integer'
  is_nullable: 1

IFA/Linguagens – ofertado em um turno (manhã/tarde) em mais de uma escola

=head2 qt_mat_med_ifa_ling_oe

  data_type: 'integer'
  is_nullable: 1

IFA/Linguagens – ofertado em uma única escola

=head2 qt_mat_med_ifa_mate

  data_type: 'integer'
  is_nullable: 1

IFA – Matemática

=head2 qt_mat_med_ifa_mate_mt

  data_type: 'integer'
  is_nullable: 1

IFA/Matemática – mais de um turno

=head2 qt_mat_med_ifa_mate_otme

  data_type: 'integer'
  is_nullable: 1

IFA/Matemática – um turno em mais de uma escola

=head2 qt_mat_med_ifa_mate_oe

  data_type: 'integer'
  is_nullable: 1

IFA/Matemática – uma única escola

=head2 qt_mat_med_ifa_cienc

  data_type: 'integer'
  is_nullable: 1

IFA – Ciências da natureza

=head2 qt_mat_med_ifa_cienc_mt

  data_type: 'integer'
  is_nullable: 1

IFA/Ciências – mais de um turno

=head2 qt_mat_med_ifa_cienc_otme

  data_type: 'integer'
  is_nullable: 1

IFA/Ciências – um turno em mais de uma escola

=head2 qt_mat_med_ifa_cienc_oe

  data_type: 'integer'
  is_nullable: 1

IFA/Ciências – uma única escola

=head2 qt_mat_med_ifa_huma

  data_type: 'integer'
  is_nullable: 1

IFA – Ciências humanas

=head2 qt_mat_med_ifa_huma_mt

  data_type: 'integer'
  is_nullable: 1

IFA/Humanas – mais de um turno

=head2 qt_mat_med_ifa_huma_otme

  data_type: 'integer'
  is_nullable: 1

IFA/Humanas – um turno em mais de uma escola

=head2 qt_mat_med_ifa_huma_oe

  data_type: 'integer'
  is_nullable: 1

IFA/Humanas – uma única escola

=head2 qt_mat_med_arti_iftp_ct

  data_type: 'integer'
  is_nullable: 1

Articulação com IFTP – curso técnico

=head2 qt_mat_med_arti_iftp_ct_mt

  data_type: 'integer'
  is_nullable: 1

Articulação IFTP/CT – mais de um turno

=head2 qt_mat_med_arti_iftp_ct_otme

  data_type: 'integer'
  is_nullable: 1

Articulação IFTP/CT – um turno em mais de uma escola

=head2 qt_mat_med_arti_iftp_ct_oe

  data_type: 'integer'
  is_nullable: 1

Articulação IFTP/CT – uma única escola

=head2 qt_mat_med_arti_iftp_qp

  data_type: 'integer'
  is_nullable: 1

Articulação com IFTP – qualificação profissional

=head2 qt_mat_med_arti_iftp_qp_mt

  data_type: 'integer'
  is_nullable: 1

Articulação IFTP/QP – mais de um turno

=head2 qt_mat_med_arti_iftp_qp_otme

  data_type: 'integer'
  is_nullable: 1

Articulação IFTP/QP – um turno em mais de uma escola

=head2 qt_mat_med_arti_iftp_qp_oe

  data_type: 'integer'
  is_nullable: 1

Articulação IFTP/QP – uma única escola

=head2 qt_mat_prof

  data_type: 'integer'
  is_nullable: 1

Matrículas na educação profissional (total)

=head2 qt_mat_prof_tec

  data_type: 'integer'
  is_nullable: 1

Educação profissional técnica (subsequente / concomitante)

=head2 qt_mat_prof_tec_con

  data_type: 'integer'
  is_nullable: 1

Técnico – concomitante

=head2 qt_mat_prof_tec_subs

  data_type: 'integer'
  is_nullable: 1

Técnico – subsequente

=head2 qt_mat_prof_tec_iftp_ct

  data_type: 'integer'
  is_nullable: 1

Técnico – IFTP curso técnico

=head2 qt_mat_prof_nao_tec

  data_type: 'integer'
  is_nullable: 1

Formação profissional não técnica

=head2 qt_mat_prof_iftp_qp

  data_type: 'integer'
  is_nullable: 1

Profissional – IFTP qualificação

=head2 qt_mat_prof_fic_con

  data_type: 'integer'
  is_nullable: 1

FIC (Formação Inicial Continuada) concomitante

=head2 qt_mat_eja

  data_type: 'integer'
  is_nullable: 1

Matrículas na EJA (Educação de Jovens e Adultos)

=head2 qt_mat_eja_fund

  data_type: 'integer'
  is_nullable: 1

EJA – ensino fundamental

=head2 qt_mat_eja_fund_nprof

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – não profissionalizante

=head2 qt_mat_eja_fund_ai

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – anos iniciais

=head2 qt_mat_eja_fund_af

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – anos finais

=head2 qt_mat_eja_fund_fic

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – FIC

=head2 qt_mat_eja_med

  data_type: 'integer'
  is_nullable: 1

EJA – ensino médio

=head2 qt_mat_eja_med_nprof

  data_type: 'integer'
  is_nullable: 1

EJA médio – não profissionalizante

=head2 qt_mat_eja_med_fic

  data_type: 'integer'
  is_nullable: 1

EJA médio – FIC

=head2 qt_mat_eja_med_tec

  data_type: 'integer'
  is_nullable: 1

EJA médio – técnico

=head2 qt_mat_esp

  data_type: 'integer'
  is_nullable: 1

Matrículas na educação especial (total)

=head2 qt_mat_esp_inf

  data_type: 'integer'
  is_nullable: 1

Especial – educação infantil

=head2 qt_mat_esp_inf_cre

  data_type: 'integer'
  is_nullable: 1

Especial – creche

=head2 qt_mat_esp_inf_pre

  data_type: 'integer'
  is_nullable: 1

Especial – pré-escola

=head2 qt_mat_esp_fund

  data_type: 'integer'
  is_nullable: 1

Especial – ensino fundamental

=head2 qt_mat_esp_fund_ai

  data_type: 'integer'
  is_nullable: 1

Especial – fundamental anos iniciais

=head2 qt_mat_esp_fund_af

  data_type: 'integer'
  is_nullable: 1

Especial – fundamental anos finais

=head2 qt_mat_esp_med

  data_type: 'integer'
  is_nullable: 1

Especial – ensino médio

=head2 qt_mat_esp_prof

  data_type: 'integer'
  is_nullable: 1

Especial – educação profissional

=head2 qt_mat_esp_prof_tec

  data_type: 'integer'
  is_nullable: 1

Especial – profissional técnica

=head2 qt_mat_esp_eja

  data_type: 'integer'
  is_nullable: 1

Especial – EJA

=head2 qt_mat_esp_eja_fund

  data_type: 'integer'
  is_nullable: 1

Especial – EJA fundamental

=head2 qt_mat_esp_eja_med

  data_type: 'integer'
  is_nullable: 1

Especial – EJA médio

=head2 qt_mat_esp_cc

  data_type: 'integer'
  is_nullable: 1

Especial – classes comuns (inclusão)

=head2 qt_mat_esp_cc_inf

  data_type: 'integer'
  is_nullable: 1

Classes comuns – educação infantil

=head2 qt_mat_esp_cc_inf_cre

  data_type: 'integer'
  is_nullable: 1

Classes comuns – creche

=head2 qt_mat_esp_cc_inf_pre

  data_type: 'integer'
  is_nullable: 1

Classes comuns – pré-escola

=head2 qt_mat_esp_cc_fund

  data_type: 'integer'
  is_nullable: 1

Classes comuns – ensino fundamental

=head2 qt_mat_esp_cc_fund_ai

  data_type: 'integer'
  is_nullable: 1

Classes comuns – fundamental anos iniciais

=head2 qt_mat_esp_cc_fund_af

  data_type: 'integer'
  is_nullable: 1

Classes comuns – fundamental anos finais

=head2 qt_mat_esp_cc_med

  data_type: 'integer'
  is_nullable: 1

Classes comuns – ensino médio

=head2 qt_mat_esp_cc_prof

  data_type: 'integer'
  is_nullable: 1

Classes comuns – educação profissional

=head2 qt_mat_esp_cc_prof_tec

  data_type: 'integer'
  is_nullable: 1

Classes comuns – profissional técnica

=head2 qt_mat_esp_cc_eja

  data_type: 'integer'
  is_nullable: 1

Classes comuns – EJA

=head2 qt_mat_esp_cc_eja_fund

  data_type: 'integer'
  is_nullable: 1

Classes comuns – EJA fundamental

=head2 qt_mat_esp_cc_eja_med

  data_type: 'integer'
  is_nullable: 1

Classes comuns – EJA médio

=head2 qt_mat_esp_ce

  data_type: 'integer'
  is_nullable: 1

Especial – classes exclusivas (AEE)

=head2 qt_mat_esp_ce_inf

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – educação infantil

=head2 qt_mat_esp_ce_inf_cre

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – creche

=head2 qt_mat_esp_ce_inf_pre

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – pré-escola

=head2 qt_mat_esp_ce_fund

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – ensino fundamental

=head2 qt_mat_esp_ce_fund_ai

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – fundamental anos iniciais

=head2 qt_mat_esp_ce_fund_af

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – fundamental anos finais

=head2 qt_mat_esp_ce_med

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – ensino médio

=head2 qt_mat_esp_ce_prof

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – educação profissional

=head2 qt_mat_esp_ce_prof_tec

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – profissional técnica

=head2 qt_mat_esp_ce_eja

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – EJA

=head2 qt_mat_esp_ce_eja_fund

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – EJA fundamental

=head2 qt_mat_esp_ce_eja_med

  data_type: 'integer'
  is_nullable: 1

Classes exclusivas – EJA médio

=head2 qt_mat_bas_fem

  data_type: 'integer'
  is_nullable: 1

Educação básica – sexo feminino

=head2 qt_mat_bas_masc

  data_type: 'integer'
  is_nullable: 1

Educação básica – sexo masculino

=head2 qt_mat_bas_nd

  data_type: 'integer'
  is_nullable: 1

Educação básica – sexo não declarado

=head2 qt_mat_bas_branca

  data_type: 'integer'
  is_nullable: 1

Raça/cor – branca

=head2 qt_mat_bas_preta

  data_type: 'integer'
  is_nullable: 1

Raça/cor – preta

=head2 qt_mat_bas_parda

  data_type: 'integer'
  is_nullable: 1

Raça/cor – parda

=head2 qt_mat_bas_amarela

  data_type: 'integer'
  is_nullable: 1

Raça/cor – amarela

=head2 qt_mat_bas_indigena

  data_type: 'integer'
  is_nullable: 1

Raça/cor – indígena

=head2 qt_mat_bas_0_3

  data_type: 'integer'
  is_nullable: 1

Idade 0 a 3 anos

=head2 qt_mat_bas_4_5

  data_type: 'integer'
  is_nullable: 1

Idade 4 a 5 anos

=head2 qt_mat_bas_6_10

  data_type: 'integer'
  is_nullable: 1

Idade 6 a 10 anos

=head2 qt_mat_bas_11_14

  data_type: 'integer'
  is_nullable: 1

Idade 11 a 14 anos

=head2 qt_mat_bas_15_17

  data_type: 'integer'
  is_nullable: 1

Idade 15 a 17 anos

=head2 qt_mat_bas_18_mais

  data_type: 'integer'
  is_nullable: 1

Idade 18 anos ou mais

=head2 qt_mat_bas_0_3_ref_31_03

  data_type: 'integer'
  is_nullable: 1

Idade 0-3 anos (referência 31/03)

=head2 qt_mat_bas_4_5_ref_31_03

  data_type: 'integer'
  is_nullable: 1

Idade 4-5 anos (ref. 31/03)

=head2 qt_mat_bas_6_10_ref_31_03

  data_type: 'integer'
  is_nullable: 1

Idade 6-10 anos (ref. 31/03)

=head2 qt_mat_bas_11_14_ref_31_03

  data_type: 'integer'
  is_nullable: 1

Idade 11-14 anos (ref. 31/03)

=head2 qt_mat_bas_15_17_ref_31_03

  data_type: 'integer'
  is_nullable: 1

Idade 15-17 anos (ref. 31/03)

=head2 qt_mat_bas_18_mais_ref_31_03

  data_type: 'integer'
  is_nullable: 1

Idade 18+ anos (ref. 31/03)

=head2 qt_mat_bas_d

  data_type: 'integer'
  is_nullable: 1

Deficiência – Deficiência

=head2 qt_mat_bas_dm

  data_type: 'integer'
  is_nullable: 1

Deficiência – Deficiência múltipla

=head2 qt_mat_bas_dv

  data_type: 'integer'
  is_nullable: 1

Deficiência – Deficiência visual

=head2 qt_mat_bas_n

  data_type: 'integer'
  is_nullable: 1

Deficiência – Não se aplica

=head2 qt_mat_bas_ead

  data_type: 'integer'
  is_nullable: 1

Educação básica – EAD

=head2 qt_mat_inf_cre_d

  data_type: 'integer'
  is_nullable: 1

Creche – Deficiência

=head2 qt_mat_inf_cre_dm

  data_type: 'integer'
  is_nullable: 1

Creche – Deficiência múltipla

=head2 qt_mat_inf_cre_dv

  data_type: 'integer'
  is_nullable: 1

Creche – Deficiência visual

=head2 qt_mat_inf_cre_n

  data_type: 'integer'
  is_nullable: 1

Creche – Não se aplica

=head2 qt_mat_inf_pre_d

  data_type: 'integer'
  is_nullable: 1

Pré‑escola – Deficiência

=head2 qt_mat_inf_pre_dm

  data_type: 'integer'
  is_nullable: 1

Pré‑escola – Deficiência múltipla

=head2 qt_mat_inf_pre_dv

  data_type: 'integer'
  is_nullable: 1

Pré‑escola – Deficiência visual

=head2 qt_mat_inf_pre_n

  data_type: 'integer'
  is_nullable: 1

Pré‑escola – Não se aplica

=head2 qt_mat_fund_d

  data_type: 'integer'
  is_nullable: 1

Fundamental – Deficiência

=head2 qt_mat_fund_dm

  data_type: 'integer'
  is_nullable: 1

Fundamental – Deficiência múltipla

=head2 qt_mat_fund_dv

  data_type: 'integer'
  is_nullable: 1

Fundamental – Deficiência visual

=head2 qt_mat_fund_n

  data_type: 'integer'
  is_nullable: 1

Fundamental – Não se aplica

=head2 qt_mat_fund_ai_d

  data_type: 'integer'
  is_nullable: 1

Fundamental anos iniciais – Deficiência

=head2 qt_mat_fund_ai_dm

  data_type: 'integer'
  is_nullable: 1

Fundamental anos iniciais – Deficiência múltipla

=head2 qt_mat_fund_ai_dv

  data_type: 'integer'
  is_nullable: 1

Fundamental anos iniciais – Deficiência visual

=head2 qt_mat_fund_ai_n

  data_type: 'integer'
  is_nullable: 1

Fundamental anos iniciais – Não se aplica

=head2 qt_mat_fund_af_d

  data_type: 'integer'
  is_nullable: 1

Fundamental anos finais – Deficiência

=head2 qt_mat_fund_af_dm

  data_type: 'integer'
  is_nullable: 1

Fundamental anos finais – Deficiência múltipla

=head2 qt_mat_fund_af_dv

  data_type: 'integer'
  is_nullable: 1

Fundamental anos finais – Deficiência visual

=head2 qt_mat_fund_af_n

  data_type: 'integer'
  is_nullable: 1

Fundamental anos finais – Não se aplica

=head2 qt_mat_med_d

  data_type: 'integer'
  is_nullable: 1

Ensino médio – Deficiência

=head2 qt_mat_med_dm

  data_type: 'integer'
  is_nullable: 1

Ensino médio – Deficiência múltipla

=head2 qt_mat_med_dv

  data_type: 'integer'
  is_nullable: 1

Ensino médio – Deficiência visual

=head2 qt_mat_med_n

  data_type: 'integer'
  is_nullable: 1

Ensino médio – Não se aplica

=head2 qt_mat_med_ead

  data_type: 'integer'
  is_nullable: 1

Ensino médio – EAD

=head2 qt_mat_prof_d

  data_type: 'integer'
  is_nullable: 1

Profissional – Deficiência

=head2 qt_mat_prof_dm

  data_type: 'integer'
  is_nullable: 1

Profissional – Deficiência múltipla

=head2 qt_mat_prof_dv

  data_type: 'integer'
  is_nullable: 1

Profissional – Deficiência visual

=head2 qt_mat_prof_n

  data_type: 'integer'
  is_nullable: 1

Profissional – Não se aplica

=head2 qt_mat_prof_ead

  data_type: 'integer'
  is_nullable: 1

Profissional – EAD

=head2 qt_mat_prof_tec_d

  data_type: 'integer'
  is_nullable: 1

Profissional técnica – Deficiência

=head2 qt_mat_prof_tec_dm

  data_type: 'integer'
  is_nullable: 1

Profissional técnica – Deficiência múltipla

=head2 qt_mat_prof_tec_dv

  data_type: 'integer'
  is_nullable: 1

Profissional técnica – Deficiência visual

=head2 qt_mat_prof_tec_n

  data_type: 'integer'
  is_nullable: 1

Profissional técnica – Não se aplica

=head2 qt_mat_prof_tec_ead

  data_type: 'integer'
  is_nullable: 1

Profissional técnica – EAD

=head2 qt_mat_eja_d

  data_type: 'integer'
  is_nullable: 1

EJA – Deficiência

=head2 qt_mat_eja_dm

  data_type: 'integer'
  is_nullable: 1

EJA – Deficiência múltipla

=head2 qt_mat_eja_dv

  data_type: 'integer'
  is_nullable: 1

EJA – Deficiência visual

=head2 qt_mat_eja_n

  data_type: 'integer'
  is_nullable: 1

EJA – Não se aplica

=head2 qt_mat_eja_ead

  data_type: 'integer'
  is_nullable: 1

EJA – EAD

=head2 qt_mat_eja_fund_d

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – Deficiência

=head2 qt_mat_eja_fund_dm

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – Deficiência múltipla

=head2 qt_mat_eja_fund_dv

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – Deficiência visual

=head2 qt_mat_eja_fund_n

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – Não se aplica

=head2 qt_mat_eja_fund_ead

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – EAD

=head2 qt_mat_eja_med_d

  data_type: 'integer'
  is_nullable: 1

EJA médio – Deficiência

=head2 qt_mat_eja_med_dm

  data_type: 'integer'
  is_nullable: 1

EJA médio – Deficiência múltipla

=head2 qt_mat_eja_med_dv

  data_type: 'integer'
  is_nullable: 1

EJA médio – Deficiência visual

=head2 qt_mat_eja_med_n

  data_type: 'integer'
  is_nullable: 1

EJA médio – Não se aplica

=head2 qt_mat_eja_med_ead

  data_type: 'integer'
  is_nullable: 1

EJA médio – EAD

=head2 qt_mat_esp_d

  data_type: 'integer'
  is_nullable: 1

Educação especial – Deficiência

=head2 qt_mat_esp_dm

  data_type: 'integer'
  is_nullable: 1

Educação especial – Deficiência múltipla

=head2 qt_mat_esp_dv

  data_type: 'integer'
  is_nullable: 1

Educação especial – Deficiência visual

=head2 qt_mat_esp_n

  data_type: 'integer'
  is_nullable: 1

Educação especial – Não se aplica

=head2 qt_mat_esp_ead

  data_type: 'integer'
  is_nullable: 1

Educação especial – EAD

=head2 qt_mat_esp_cc_d

  data_type: 'integer'
  is_nullable: 1

Classe comum – Deficiência

=head2 qt_mat_esp_cc_dm

  data_type: 'integer'
  is_nullable: 1

Classe comum – Deficiência múltipla

=head2 qt_mat_esp_cc_dv

  data_type: 'integer'
  is_nullable: 1

Classe comum – Deficiência visual

=head2 qt_mat_esp_cc_n

  data_type: 'integer'
  is_nullable: 1

Classe comum – Não se aplica

=head2 qt_mat_esp_cc_ead

  data_type: 'integer'
  is_nullable: 1

Classe comum – EAD

=head2 qt_mat_esp_ce_d

  data_type: 'integer'
  is_nullable: 1

Classe exclusiva – Deficiência

=head2 qt_mat_esp_ce_dm

  data_type: 'integer'
  is_nullable: 1

Classe exclusiva – Deficiência múltipla

=head2 qt_mat_esp_ce_dv

  data_type: 'integer'
  is_nullable: 1

Classe exclusiva – Deficiência visual

=head2 qt_mat_esp_ce_n

  data_type: 'integer'
  is_nullable: 1

Classe exclusiva – Não se aplica

=head2 qt_mat_esp_ce_ead

  data_type: 'integer'
  is_nullable: 1

Classe exclusiva – EAD

=head2 qt_mat_bas_int

  data_type: 'integer'
  is_nullable: 1

Educação básica – período integral

=head2 qt_mat_inf_int

  data_type: 'integer'
  is_nullable: 1

Educação infantil – integral

=head2 qt_mat_inf_cre_int

  data_type: 'integer'
  is_nullable: 1

Creche – integral

=head2 qt_mat_inf_pre_int

  data_type: 'integer'
  is_nullable: 1

Pré‑escola – integral

=head2 qt_mat_fund_int

  data_type: 'integer'
  is_nullable: 1

Fundamental – integral

=head2 qt_mat_fund_ai_int

  data_type: 'integer'
  is_nullable: 1

Fundamental anos iniciais – integral

=head2 qt_mat_fund_af_int

  data_type: 'integer'
  is_nullable: 1

Fundamental anos finais – integral

=head2 qt_mat_med_int

  data_type: 'integer'
  is_nullable: 1

Ensino médio – integral

=head2 qt_mat_prof_int

  data_type: 'integer'
  is_nullable: 1

Profissional – integral

=head2 qt_mat_prof_tec_int

  data_type: 'integer'
  is_nullable: 1

Profissional técnica – integral

=head2 qt_mat_eja_int

  data_type: 'integer'
  is_nullable: 1

EJA – integral

=head2 qt_mat_eja_fund_int

  data_type: 'integer'
  is_nullable: 1

EJA fundamental – integral

=head2 qt_mat_eja_med_int

  data_type: 'integer'
  is_nullable: 1

EJA médio – integral

=head2 qt_mat_esp_int

  data_type: 'integer'
  is_nullable: 1

Educação especial – integral

=head2 qt_mat_esp_cc_int

  data_type: 'integer'
  is_nullable: 1

Classe comum – integral

=head2 qt_mat_esp_ce_int

  data_type: 'integer'
  is_nullable: 1

Classe exclusiva – integral

=head2 qt_mat_bas_libras

  data_type: 'integer'
  is_nullable: 1

Educação básica – Libras

=head2 qt_mat_zr_urb

  data_type: 'integer'
  is_nullable: 1

Localização – urbana

=head2 qt_mat_zr_rur

  data_type: 'integer'
  is_nullable: 1

Localização – rural

=head2 qt_mat_zr_na

  data_type: 'integer'
  is_nullable: 1

Localização – não aplicável

=head2 qt_transp_publico

  data_type: 'integer'
  is_nullable: 1

Transporte público – alunos que utilizam

=head2 qt_transp_resp_est

  data_type: 'integer'
  is_nullable: 1

Transporte – responsabilidade estadual

=head2 qt_transp_resp_mun

  data_type: 'integer'
  is_nullable: 1

Transporte – responsabilidade municipal

=cut

__PACKAGE__->add_columns(
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 0 },
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "qt_mat_bas",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_pre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_5",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_6",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_7",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_8",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_9",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_prop",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_prop_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_prop_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_prop_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_prop_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_prop_ns",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_ct",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_ct_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_ct_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_ct_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_ct_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_ct_ns",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_qp",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_qp_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_qp_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_qp_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_qp_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_iftp_qp_ns",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_nm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_nm_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_nm_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_nm_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_nm_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_ling",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_ling_mt",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_ling_otme",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_ling_oe",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_mate",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_mate_mt",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_mate_otme",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_mate_oe",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_cienc",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_cienc_mt",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_cienc_otme",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_cienc_oe",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_huma",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_huma_mt",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_huma_otme",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ifa_huma_oe",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_ct",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_ct_mt",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_ct_otme",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_ct_oe",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_qp",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_qp_mt",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_qp_otme",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_arti_iftp_qp_oe",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_con",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_subs",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_iftp_ct",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_nao_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_iftp_qp",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_fic_con",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_nprof",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_fic",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_nprof",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_fic",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_inf",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_inf_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_inf_pre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_prof",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_prof_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_eja_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_eja_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_inf",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_inf_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_inf_pre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_prof",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_prof_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_eja_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_eja_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_inf",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_inf_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_inf_pre",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_prof",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_prof_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_eja_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_eja_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_fem",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_masc",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_nd",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_branca",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_preta",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_parda",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_amarela",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_indigena",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_0_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_4_5",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_6_10",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_11_14",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_15_17",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_18_mais",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_0_3_ref_31_03",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_4_5_ref_31_03",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_6_10_ref_31_03",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_11_14_ref_31_03",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_15_17_ref_31_03",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_18_mais_ref_31_03",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_cre_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_cre_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_cre_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_cre_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_pre_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_pre_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_pre_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_pre_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_d",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_dm",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_dv",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_n",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_cre_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf_pre_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_ai_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund_af_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_prof_tec_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_fund_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_eja_med_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_cc_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_esp_ce_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_libras",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_zr_urb",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_zr_rur",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_zr_na",
  { data_type => "integer", is_nullable => 1 },
  "qt_transp_publico",
  { data_type => "integer", is_nullable => 1 },
  "qt_transp_resp_est",
  { data_type => "integer", is_nullable => 1 },
  "qt_transp_resp_mun",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</nu_ano_censo>

=item * L</co_entidade>

=back

=cut

__PACKAGE__->set_primary_key("nu_ano_censo", "co_entidade");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-28 17:01:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aN6Ge4GnsioOOqxa7FQ+wA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.co_entidade' },
);

1;
