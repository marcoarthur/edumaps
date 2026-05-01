use utf8;
package EduMaps::Schema::Result::CensoDocentes;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::CensoDocentes

=head1 DESCRIPTION

Docentes do Censo Escolar 2025 por escola (CO_ENTIDADE) e ano

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<censo_docentes>

=cut

__PACKAGE__->table("censo_docentes");

=head1 ACCESSORS

=head2 nu_ano_censo

  data_type: 'integer'
  is_nullable: 0

Ano do censo (2025)

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 0

Código único da escola (FK para clean.censo_escolas)

=head2 qt_doc_bas

  data_type: 'integer'
  is_nullable: 1

Total de docentes na educação básica

=head2 qt_doc_inf

  data_type: 'integer'
  is_nullable: 1

Docentes na educação infantil

=head2 qt_doc_inf_cre

  data_type: 'integer'
  is_nullable: 1

Docentes em creche

=head2 qt_doc_inf_pre

  data_type: 'integer'
  is_nullable: 1

Docentes na pré-escola

=head2 qt_doc_fund

  data_type: 'integer'
  is_nullable: 1

Docentes no ensino fundamental

=head2 qt_doc_fund_ai

  data_type: 'integer'
  is_nullable: 1

Docentes nos anos iniciais do fundamental

=head2 qt_doc_fund_ai_1

  data_type: 'integer'
  is_nullable: 1

Docentes no 1º ano do fundamental (anos iniciais)

=head2 qt_doc_fund_ai_2

  data_type: 'integer'
  is_nullable: 1

Docentes no 2º ano do fundamental (anos iniciais)

=head2 qt_doc_fund_ai_3

  data_type: 'integer'
  is_nullable: 1

Docentes no 3º ano do fundamental (anos iniciais)

=head2 qt_doc_fund_ai_4

  data_type: 'integer'
  is_nullable: 1

Docentes no 4º ano do fundamental (anos iniciais)

=head2 qt_doc_fund_ai_5

  data_type: 'integer'
  is_nullable: 1

Docentes no 5º ano do fundamental (anos iniciais)

=head2 qt_doc_fund_ai_multietapa

  data_type: 'integer'
  is_nullable: 1

Docentes em turmas multietapa nos anos iniciais

=head2 qt_doc_fund_af

  data_type: 'integer'
  is_nullable: 1

Docentes nos anos finais do fundamental

=head2 qt_doc_fund_af_6

  data_type: 'integer'
  is_nullable: 1

Docentes no 6º ano do fundamental (anos finais)

=head2 qt_doc_fund_af_7

  data_type: 'integer'
  is_nullable: 1

Docentes no 7º ano do fundamental (anos finais)

=head2 qt_doc_fund_af_8

  data_type: 'integer'
  is_nullable: 1

Docentes no 8º ano do fundamental (anos finais)

=head2 qt_doc_fund_af_9

  data_type: 'integer'
  is_nullable: 1

Docentes no 9º ano do fundamental (anos finais)

=head2 qt_doc_fund_af_multi

  data_type: 'integer'
  is_nullable: 1

Docentes em turmas multietapa nos anos finais

=head2 qt_doc_fund_af_corrfluxo

  data_type: 'integer'
  is_nullable: 1

Docentes em turmas de correção de fluxo nos anos finais

=head2 qt_doc_med

  data_type: 'integer'
  is_nullable: 1

Docentes no ensino médio

=head2 qt_doc_med_prop

  data_type: 'integer'
  is_nullable: 1

Docentes no ensino médio - proposta pedagógica

=head2 qt_doc_med_prop_1

  data_type: 'integer'
  is_nullable: 1

Docentes na 1ª série do médio (proposta)

=head2 qt_doc_med_prop_2

  data_type: 'integer'
  is_nullable: 1

Docentes na 2ª série do médio (proposta)

=head2 qt_doc_med_prop_3

  data_type: 'integer'
  is_nullable: 1

Docentes na 3ª série do médio (proposta)

=head2 qt_doc_med_prop_4

  data_type: 'integer'
  is_nullable: 1

Docentes na 4ª série do médio (proposta)

=head2 qt_doc_med_prop_ns

  data_type: 'integer'
  is_nullable: 1

Docentes no médio - série não especificada (proposta)

=head2 qt_doc_med_iftp_ct

  data_type: 'integer'
  is_nullable: 1

Docentes no médio integrado à formação técnica - curso técnico

=head2 qt_doc_med_iftp_ct_1

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/CT - 1ª série

=head2 qt_doc_med_iftp_ct_2

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/CT - 2ª série

=head2 qt_doc_med_iftp_ct_3

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/CT - 3ª série

=head2 qt_doc_med_iftp_ct_4

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/CT - 4ª série

=head2 qt_doc_med_iftp_ct_ns

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/CT - série não especificada

=head2 qt_doc_med_iftp_qp

  data_type: 'integer'
  is_nullable: 1

Docentes no médio integrado à formação técnica - qualificação profissional

=head2 qt_doc_med_iftp_qp_1

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/QP - 1ª série

=head2 qt_doc_med_iftp_qp_2

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/QP - 2ª série

=head2 qt_doc_med_iftp_qp_3

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/QP - 3ª série

=head2 qt_doc_med_iftp_qp_4

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/QP - 4ª série

=head2 qt_doc_med_iftp_qp_ns

  data_type: 'integer'
  is_nullable: 1

Docentes no IFTP/QP - série não especificada

=head2 qt_doc_med_nm

  data_type: 'integer'
  is_nullable: 1

Docentes no ensino médio normal/magistério

=head2 qt_doc_med_nm_1

  data_type: 'integer'
  is_nullable: 1

Docentes no normal/magistério - 1ª série

=head2 qt_doc_med_nm_2

  data_type: 'integer'
  is_nullable: 1

Docentes no normal/magistério - 2ª série

=head2 qt_doc_med_nm_3

  data_type: 'integer'
  is_nullable: 1

Docentes no normal/magistério - 3ª série

=head2 qt_doc_med_nm_4

  data_type: 'integer'
  is_nullable: 1

Docentes no normal/magistério - 4ª série

=head2 qt_doc_prof

  data_type: 'integer'
  is_nullable: 1

Docentes na educação profissional (total)

=head2 qt_doc_prof_tec

  data_type: 'integer'
  is_nullable: 1

Docentes na educação profissional técnica

=head2 qt_doc_prof_tec_con

  data_type: 'integer'
  is_nullable: 1

Docentes no técnico concomitante

=head2 qt_doc_prof_tec_subs

  data_type: 'integer'
  is_nullable: 1

Docentes no técnico subsequente

=head2 qt_doc_prof_tec_misto

  data_type: 'integer'
  is_nullable: 1

Docentes no técnico misto

=head2 qt_doc_prof_tec_iftp_ct

  data_type: 'integer'
  is_nullable: 1

Docentes no técnico IFTP curso técnico

=head2 qt_doc_prof_nao_tec

  data_type: 'integer'
  is_nullable: 1

Docentes na formação profissional não técnica

=head2 qt_doc_prof_iftp_qp

  data_type: 'integer'
  is_nullable: 1

Docentes profissional IFTP qualificação

=head2 qt_doc_prof_fic_con

  data_type: 'integer'
  is_nullable: 1

Docentes no FIC concomitante

=head2 qt_doc_eja

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA (Educação de Jovens e Adultos)

=head2 qt_doc_eja_fund

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA fundamental

=head2 qt_doc_eja_fund_nprof

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA fundamental não profissionalizante

=head2 qt_doc_eja_fund_ai

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA fundamental anos iniciais

=head2 qt_doc_eja_fund_af

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA fundamental anos finais

=head2 qt_doc_eja_fund_fic

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA fundamental FIC

=head2 qt_doc_eja_med

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA médio

=head2 qt_doc_eja_med_nprof

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA médio não profissionalizante

=head2 qt_doc_eja_med_fic

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA médio FIC

=head2 qt_doc_eja_med_tec

  data_type: 'integer'
  is_nullable: 1

Docentes na EJA médio técnico

=head2 qt_doc_esp

  data_type: 'integer'
  is_nullable: 1

Docentes na educação especial (total)

=head2 qt_doc_esp_cc

  data_type: 'integer'
  is_nullable: 1

Docentes em classes comuns (inclusão) na educação especial

=head2 qt_doc_esp_ce

  data_type: 'integer'
  is_nullable: 1

Docentes em classes exclusivas (AEE) na educação especial

=head2 qt_doc_bas_fem

  data_type: 'integer'
  is_nullable: 1

Docentes do sexo feminino (educação básica)

=head2 qt_doc_bas_masc

  data_type: 'integer'
  is_nullable: 1

Docentes do sexo masculino

=head2 qt_doc_bas_nd

  data_type: 'integer'
  is_nullable: 1

Docentes com sexo não declarado

=head2 qt_doc_bas_branca

  data_type: 'integer'
  is_nullable: 1

Docentes de cor/raça branca

=head2 qt_doc_bas_preta

  data_type: 'integer'
  is_nullable: 1

Docentes de cor/raça preta

=head2 qt_doc_bas_parda

  data_type: 'integer'
  is_nullable: 1

Docentes de cor/raça parda

=head2 qt_doc_bas_amarela

  data_type: 'integer'
  is_nullable: 1

Docentes de cor/raça amarela

=head2 qt_doc_bas_indigena

  data_type: 'integer'
  is_nullable: 1

Docentes de cor/raça indígena

=head2 qt_doc_bas_0_24

  data_type: 'integer'
  is_nullable: 1

Docentes com idade até 24 anos

=head2 qt_doc_bas_25_29

  data_type: 'integer'
  is_nullable: 1

Docentes com idade de 25 a 29 anos

=head2 qt_doc_bas_30_39

  data_type: 'integer'
  is_nullable: 1

Docentes com idade de 30 a 39 anos

=head2 qt_doc_bas_40_49

  data_type: 'integer'
  is_nullable: 1

Docentes com idade de 40 a 49 anos

=head2 qt_doc_bas_50_54

  data_type: 'integer'
  is_nullable: 1

Docentes com idade de 50 a 54 anos

=head2 qt_doc_bas_55_59

  data_type: 'integer'
  is_nullable: 1

Docentes com idade de 55 a 59 anos

=head2 qt_doc_bas_60_mais

  data_type: 'integer'
  is_nullable: 1

Docentes com idade de 60 anos ou mais

=head2 qt_doc_bas_pcd

  data_type: 'integer'
  is_nullable: 1

Docentes com deficiência (PcD)

=head2 qt_doc_bas_zr_urb

  data_type: 'integer'
  is_nullable: 1

Docentes atuando em zona urbana

=head2 qt_doc_bas_zr_rur

  data_type: 'integer'
  is_nullable: 1

Docentes atuando em zona rural

=head2 qt_doc_bas_zr_na

  data_type: 'integer'
  is_nullable: 1

Docentes com zona não aplicável

=head2 qt_doc_bas_esco_ef

  data_type: 'integer'
  is_nullable: 1

Docentes com escolaridade até ensino fundamental

=head2 qt_doc_bas_esco_em

  data_type: 'integer'
  is_nullable: 1

Docentes com escolaridade ensino médio

=head2 qt_doc_bas_esco_sup_grad

  data_type: 'integer'
  is_nullable: 1

Docentes com ensino superior (graduação)

=head2 qt_doc_bas_esco_sup_grad_licen

  data_type: 'integer'
  is_nullable: 1

Docentes com licenciatura

=head2 qt_doc_bas_esco_sup_grad_slicen

  data_type: 'integer'
  is_nullable: 1

Docentes com graduação sem licenciatura

=head2 qt_doc_bas_esco_sup_pos_espec

  data_type: 'integer'
  is_nullable: 1

Docentes com pós-graduação especialização

=head2 qt_doc_bas_esco_sup_pos_mestra

  data_type: 'integer'
  is_nullable: 1

Docentes com mestrado

=head2 qt_doc_bas_esco_sup_pos_douto

  data_type: 'integer'
  is_nullable: 1

Docentes com doutorado

=head2 qt_doc_bas_esco_sup_pos_nenhum

  data_type: 'integer'
  is_nullable: 1

Docentes sem pós-graduação

=head2 qt_doc_bas_vinculo_concur

  data_type: 'integer'
  is_nullable: 1

Docentes com vínculo concursado/efetivo

=head2 qt_doc_bas_vinculo_contra

  data_type: 'integer'
  is_nullable: 1

Docentes contratados temporariamente

=head2 qt_doc_bas_vinculo_terceir

  data_type: 'integer'
  is_nullable: 1

Docentes terceirizados

=head2 qt_doc_bas_vinculo_clt

  data_type: 'integer'
  is_nullable: 1

Docentes com vínculo CLT

=head2 qt_doc_bas_docente

  data_type: 'integer'
  is_nullable: 1

Docentes com função docente (regência de classe)

=head2 qt_doc_bas_auxiliar

  data_type: 'integer'
  is_nullable: 1

Docentes auxiliares/assistentes

=head2 qt_doc_bas_profi_monitor

  data_type: 'integer'
  is_nullable: 1

Docentes profissionais/monitores

=head2 qt_doc_bas_tradutor_libras

  data_type: 'integer'
  is_nullable: 1

Docentes tradutores/intérpretes de Libras

=head2 qt_doc_bas_titular_ead

  data_type: 'integer'
  is_nullable: 1

Docentes titulares em EAD

=head2 qt_doc_bas_tutor_aux_ead

  data_type: 'integer'
  is_nullable: 1

Docentes tutores/auxiliares em EAD

=head2 qt_doc_bas_guia_interprete

  data_type: 'integer'
  is_nullable: 1

Docentes guia-intérpretes

=head2 qt_doc_bas_apoio_pcd

  data_type: 'integer'
  is_nullable: 1

Docentes de apoio a PcD

=head2 qt_doc_bas_instrutor_ep

  data_type: 'integer'
  is_nullable: 1

Docentes instrutores de educação profissional

=head2 qt_doc_bas_espec_cre

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em creche

=head2 qt_doc_bas_espec_pre_escola

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em pré-escola

=head2 qt_doc_bas_espec_anos_iniciais

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em anos iniciais

=head2 qt_doc_bas_espec_anos_finais

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em anos finais

=head2 qt_doc_bas_espec_ens_medio

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em ensino médio

=head2 qt_doc_bas_espec_eja

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em EJA

=head2 qt_doc_bas_espec_ed_especial

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em educação especial

=head2 qt_doc_bas_espec_bil_surdos

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em bilinguismo para surdos

=head2 qt_doc_bas_espec_ed_indigena

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em educação indígena

=head2 qt_doc_bas_espec_campo

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em educação do campo

=head2 qt_doc_bas_espec_ambiental

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em educação ambiental

=head2 qt_doc_bas_espec_dir_humanos

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em direitos humanos

=head2 qt_doc_bas_espec_div_sexual

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em diversidade sexual

=head2 qt_doc_bas_espec_dir_adolesc

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em direitos de adolescentes

=head2 qt_doc_bas_espec_afro

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em educação afro-brasileira

=head2 qt_doc_bas_espec_gestao

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em gestão

=head2 qt_doc_bas_espec_educ_tic

  data_type: 'integer'
  is_nullable: 1

Docentes com especialização em educação e TIC

=head2 qt_doc_bas_espec_outros

  data_type: 'integer'
  is_nullable: 1

Docentes com outras especializações

=head2 qt_doc_bas_espec_nenhum

  data_type: 'integer'
  is_nullable: 1

Docentes sem especialização

=head2 qt_doc_bas_disc_lingua_port

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Língua Portuguesa

=head2 qt_doc_bas_disc_educ_fisica

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Educação Física

=head2 qt_doc_bas_disc_artes

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Artes

=head2 qt_doc_bas_disc_lingua_ing

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Língua Inglesa

=head2 qt_doc_bas_disc_lingua_espa

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Língua Espanhola

=head2 qt_doc_bas_disc_lingua_franc

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Língua Francesa

=head2 qt_doc_bas_disc_lingua_outra

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam outra língua

=head2 qt_doc_bas_disc_libras

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Libras

=head2 qt_doc_bas_disc_lingua_indig

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Língua Indígena

=head2 qt_doc_bas_disc_port_seg_lingua

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Português como segunda língua

=head2 qt_doc_bas_disc_matematica

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Matemática

=head2 qt_doc_bas_disc_ciencias

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Ciências

=head2 qt_doc_bas_disc_fisica

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Física

=head2 qt_doc_bas_disc_quimica

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Química

=head2 qt_doc_bas_disc_biologia

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Biologia

=head2 qt_doc_bas_disc_historia

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam História

=head2 qt_doc_bas_disc_geografia

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Geografia

=head2 qt_doc_bas_disc_sociologia

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Sociologia

=head2 qt_doc_bas_disc_filosofia

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Filosofia

=head2 qt_doc_bas_disc_est_sociais

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Estudos Sociais

=head2 qt_doc_bas_disc_est_sociais_soci

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Estudos Sociais e Sociologia

=head2 qt_doc_bas_disc_info_computacao

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Informática/Computação

=head2 qt_doc_bas_disc_ensino_religioso

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Ensino Religioso

=head2 qt_doc_bas_disc_profissiona

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam disciplinas profissionalizantes

=head2 qt_doc_bas_disc_estagio_super

  data_type: 'integer'
  is_nullable: 1

Docentes que orientam estágio supervisionado

=head2 qt_doc_bas_disc_pedagogicas

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam disciplinas pedagógicas

=head2 qt_doc_bas_disc_projeto_de_vida

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam Projeto de Vida

=head2 qt_doc_bas_disc_outras

  data_type: 'integer'
  is_nullable: 1

Docentes que lecionam outras disciplinas

=head2 qt_doc_bas_libras

  data_type: 'integer'
  is_nullable: 1

Docentes com proficiência em Libras

=cut

__PACKAGE__->add_columns(
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 0 },
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "qt_doc_bas",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_inf",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_inf_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_inf_pre",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai_5",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_ai_multietapa",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af_6",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af_7",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af_8",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af_9",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af_multi",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_fund_af_corrfluxo",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_prop",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_prop_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_prop_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_prop_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_prop_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_prop_ns",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_ct",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_ct_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_ct_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_ct_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_ct_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_ct_ns",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_qp",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_qp_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_qp_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_qp_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_qp_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_iftp_qp_ns",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_nm",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_nm_1",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_nm_2",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_nm_3",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_med_nm_4",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_tec_con",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_tec_subs",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_tec_misto",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_tec_iftp_ct",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_nao_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_iftp_qp",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_prof_fic_con",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_fund_nprof",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_fund_ai",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_fund_af",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_fund_fic",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_med_nprof",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_med_fic",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_eja_med_tec",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_esp",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_esp_cc",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_esp_ce",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_fem",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_masc",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_nd",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_branca",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_preta",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_parda",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_amarela",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_indigena",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_0_24",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_25_29",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_30_39",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_40_49",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_50_54",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_55_59",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_60_mais",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_pcd",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_zr_urb",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_zr_rur",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_zr_na",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_ef",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_em",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_grad",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_grad_licen",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_grad_slicen",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_pos_espec",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_pos_mestra",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_pos_douto",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_pos_nenhum",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_vinculo_concur",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_vinculo_contra",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_vinculo_terceir",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_vinculo_clt",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_docente",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_auxiliar",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_profi_monitor",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_tradutor_libras",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_titular_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_tutor_aux_ead",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_guia_interprete",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_apoio_pcd",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_instrutor_ep",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_cre",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_pre_escola",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_anos_iniciais",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_anos_finais",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_ens_medio",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_eja",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_ed_especial",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_bil_surdos",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_ed_indigena",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_campo",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_ambiental",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_dir_humanos",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_div_sexual",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_dir_adolesc",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_afro",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_gestao",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_educ_tic",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_outros",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_espec_nenhum",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_lingua_port",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_educ_fisica",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_artes",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_lingua_ing",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_lingua_espa",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_lingua_franc",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_lingua_outra",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_libras",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_lingua_indig",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_port_seg_lingua",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_matematica",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_ciencias",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_fisica",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_quimica",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_biologia",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_historia",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_geografia",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_sociologia",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_filosofia",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_est_sociais",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_est_sociais_soci",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_info_computacao",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_ensino_religioso",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_profissiona",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_estagio_super",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_pedagogicas",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_projeto_de_vida",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_disc_outras",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_libras",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</nu_ano_censo>

=item * L</co_entidade>

=back

=cut

__PACKAGE__->set_primary_key("nu_ano_censo", "co_entidade");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-28 20:55:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VRWSSyhnuKE8w67jM6qTrg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.co_entidade' },
);

1;
