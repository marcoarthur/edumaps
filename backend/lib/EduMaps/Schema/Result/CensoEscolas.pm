use utf8;
package EduMaps::Schema::Result::CensoEscolas;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::CensoEscolas

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.censo_escolas>

=cut

__PACKAGE__->table("clean.censo_escolas");

=head1 ACCESSORS

=head2 linha_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'censo_escolas_linha_id_seq'

Número da linha no arquivo original (1 = primeira linha de dados)

=head2 nu_ano_censo

  data_type: 'integer'
  is_nullable: 1

Ano de referência do Censo Escolar (ex: 2025)

=head2 no_regiao

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Nome da região geográfica (Norte, Nordeste, etc.)

=head2 co_regiao

  data_type: 'smallint'
  is_nullable: 1

Código da região (1-Norte,2-Nordeste,3-Sudeste,4-Sul,5-Centro-Oeste)

=head2 no_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 50

Nome da Unidade da Federação

=head2 sg_uf

  data_type: 'char'
  is_nullable: 1
  size: 2

Sigla da UF (SP, RJ, etc.)

=head2 co_uf

  data_type: 'smallint'
  is_nullable: 1

Código IBGE da UF

=head2 no_municipio

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome do município

=head2 co_municipio

  data_type: 'integer'
  is_nullable: 1

Código IBGE do município

=head2 no_regiao_geog_interm

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da região geográfica intermediária (IBGE)

=head2 co_regiao_geog_interm

  data_type: 'integer'
  is_nullable: 1

Código da região intermediária

=head2 no_regiao_geog_imed

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da região geográfica imediata (IBGE)

=head2 co_regiao_geog_imed

  data_type: 'integer'
  is_nullable: 1

Código da região imediata

=head2 no_mesorregiao

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da mesorregião (IBGE)

=head2 co_mesorregiao

  data_type: 'integer'
  is_nullable: 1

Código da mesorregião

=head2 no_microrregiao

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da microrregião (IBGE)

=head2 co_microrregiao

  data_type: 'integer'
  is_nullable: 1

Código da microrregião

=head2 no_distrito

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome do distrito (se aplicável)

=head2 co_distrito

  data_type: 'integer'
  is_nullable: 1

Código do distrito

=head2 no_regiao_administrativa

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da região administrativa (grandes municípios)

=head2 co_regiao_administrativa

  data_type: 'integer'
  is_nullable: 1

Código da região administrativa

=head2 no_entidade

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Nome oficial da escola

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 0

Código único da escola no INEP (identificador principal)

=head2 tp_dependencia

  data_type: 'smallint'
  is_nullable: 1

Dependência administrativa: 1-Federal,2-Estadual,3-Municipal,4-Privada

=head2 tp_categoria_escola_privada

  data_type: 'smallint'
  is_nullable: 1

Categoria da escola privada: 1-Particular,2-Comunitária,3-Confessional,4-Filantrópica

=head2 tp_localizacao

  data_type: 'smallint'
  is_nullable: 1

Localização: 1-Urbana,2-Rural

=head2 tp_localizacao_diferenciada

  data_type: 'smallint'
  is_nullable: 1

Localização diferenciada: 1-Assentamento,2-Terra Indígena,3-Quilombo,4-Área remanescente de quilombos, etc.

=head2 ds_endereco

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Logradouro do endereço

=head2 nu_endereco

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Número do endereço (pode conter letras)

=head2 ds_complemento

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Complemento do endereço (bloco, apto, etc.)

=head2 no_bairro

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Bairro

=head2 co_cep

  data_type: 'varchar'
  is_nullable: 1
  size: 10

Código postal (CEP)

=head2 nu_ddd

  data_type: 'smallint'
  is_nullable: 1

DDD do telefone

=head2 nu_telefone

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Número do telefone

=head2 latitude

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa63b960)"]

Coordenada latitude (graus decimais)

=head2 longitude

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa010ae8)"]

Coordenada longitude (graus decimais)

=head2 tp_situacao_funcionamento

  data_type: 'smallint'
  is_nullable: 1

Situação de funcionamento: 1-Ativa,2-Paralisada,3-Extinta

=head2 co_orgao_regional

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Código do órgão regional de educação (CRE, DRES, etc.)

=head2 dt_ano_letivo_inicio

  data_type: 'date'
  is_nullable: 1

Data de início do ano letivo (formato DD/MM/AAAA)

=head2 dt_ano_letivo_termino

  data_type: 'date'
  is_nullable: 1

Data de término do ano letivo (formato DD/MM/AAAA)

=head2 in_vinculo_secretaria_educacao

  data_type: 'smallint'
  is_nullable: 1

A escola tem vínculo com a Secretaria de Educação? (0-Não,1-Sim)

=head2 in_vinculo_seguranca_publica

  data_type: 'smallint'
  is_nullable: 1

Vínculo com órgão de segurança pública?

=head2 in_vinculo_secretaria_saude

  data_type: 'smallint'
  is_nullable: 1

Vínculo com Secretaria de Saúde?

=head2 in_vinculo_outro_orgao

  data_type: 'smallint'
  is_nullable: 1

Vínculo com outro órgão público?

=head2 in_poder_publico_parceria

  data_type: 'smallint'
  is_nullable: 1

Mantém parceria com o poder público?

=head2 tp_poder_publico_parceria

  data_type: 'smallint'
  is_nullable: 1

Tipo de poder público parceiro: 1-Municipal,2-Estadual,3-Federal

=head2 in_forma_cont_termo_colabora

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato: termo de colaboração? (0/1)

=head2 in_forma_cont_termo_fomento

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato: termo de fomento?

=head2 in_forma_cont_acordo_coop

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato: acordo de cooperação?

=head2 in_forma_cont_prestacao_serv

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato: prestação de serviços?

=head2 in_forma_cont_coop_tec_fin

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato: cooperação técnica/financeira?

=head2 in_forma_cont_consorcio_pub

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato: consórcio público?

=head2 in_forma_cont_mu_termo_colab

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (municipal): termo de colaboração?

=head2 in_forma_cont_mu_termo_fomento

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (municipal): termo de fomento?

=head2 in_forma_cont_mu_acordo_coop

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (municipal): acordo de cooperação?

=head2 in_forma_cont_mu_prest_serv

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (municipal): prestação de serviços?

=head2 in_forma_cont_mu_coop_tec_fin

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (municipal): cooperação técnico-financeira?

=head2 in_forma_cont_mu_consorcio_pub

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (municipal): consórcio público?

=head2 in_forma_cont_es_termo_colab

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (estadual): termo de colaboração?

=head2 in_forma_cont_es_termo_fomento

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (estadual): termo de fomento?

=head2 in_forma_cont_es_acordo_coop

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (estadual): acordo de cooperação?

=head2 in_forma_cont_es_prest_serv

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (estadual): prestação de serviços?

=head2 in_forma_cont_es_coop_tec_fin

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (estadual): cooperação técnico-financeira?

=head2 in_forma_cont_es_consorcio_pub

  data_type: 'smallint'
  is_nullable: 1

Forma de contrato (estadual): consórcio público?

=head2 in_mant_escola_privada_emp

  data_type: 'smallint'
  is_nullable: 1

Mantenedora privada: empresa (0/1)

=head2 in_mant_escola_privada_ong

  data_type: 'smallint'
  is_nullable: 1

Mantenedora: ONG

=head2 in_mant_escola_privada_oscip

  data_type: 'smallint'
  is_nullable: 1

Mantenedora: OSCIP

=head2 in_mant_escola_priv_ong_oscip

  data_type: 'smallint'
  is_nullable: 1

Mantenedora: ONG ou OSCIP

=head2 in_mant_escola_privada_sind

  data_type: 'smallint'
  is_nullable: 1

Mantenedora: sindicato

=head2 in_mant_escola_privada_sist_s

  data_type: 'smallint'
  is_nullable: 1

Mantenedora: Sistema S (SESI, SENAI, etc.)

=head2 in_mant_escola_privada_s_fins

  data_type: 'smallint'
  is_nullable: 1

Mantenedora: sem fins lucrativos

=head2 nu_cnpj_escola_privada

  data_type: 'varchar'
  is_nullable: 1
  size: 18

CNPJ da escola privada

=head2 nu_cnpj_mantenedora

  data_type: 'varchar'
  is_nullable: 1
  size: 18

CNPJ da mantenedora (privada)

=head2 tp_regulamentacao

  data_type: 'smallint'
  is_nullable: 1

Tipo de regulamentação da escola (estadual, municipal, etc.)

=head2 tp_responsavel_regulamentacao

  data_type: 'smallint'
  is_nullable: 1

Responsável pela regulamentação

=head2 co_escola_sede_vinculada

  data_type: 'bigint'
  is_nullable: 1

Código da escola sede (se esta for extensão)

=head2 co_ies_ofertante

  data_type: 'integer'
  is_nullable: 1

Código da IES ofertante (educação profissional)

=head2 in_local_func_predio_escolar

  data_type: 'smallint'
  is_nullable: 1

Funciona em prédio escolar? (0/1)

=head2 tp_ocupacao_predio_escolar

  data_type: 'smallint'
  is_nullable: 1

Tipo de ocupação do prédio (próprio, alugado, cedido)

=head2 in_local_func_socioeducativo

  data_type: 'smallint'
  is_nullable: 1

Funciona em unidade socioeducativa?

=head2 in_local_func_unid_prisional

  data_type: 'smallint'
  is_nullable: 1

Funciona em unidade prisional?

=head2 in_local_func_prisional_socio

  data_type: 'smallint'
  is_nullable: 1

Funciona em unidade prisional/socioeducativa?

=head2 in_local_func_galpao

  data_type: 'smallint'
  is_nullable: 1

Funciona em galpão?

=head2 tp_ocupacao_galpao

  data_type: 'smallint'
  is_nullable: 1

Tipo de ocupação do galpão

=head2 in_local_func_salas_outra_esc

  data_type: 'smallint'
  is_nullable: 1

Funciona em salas de outra escola?

=head2 in_local_func_outros

  data_type: 'smallint'
  is_nullable: 1

Funciona em outro tipo de local?

=head2 in_predio_compartilhado

  data_type: 'smallint'
  is_nullable: 1

Prédio compartilhado com outra escola?

=head2 in_agua_potavel

  data_type: 'smallint'
  is_nullable: 1

Há água potável na escola?

=head2 in_agua_rede_publica

  data_type: 'smallint'
  is_nullable: 1

Abastecimento de água: rede pública

=head2 in_agua_poco_artesiano

  data_type: 'smallint'
  is_nullable: 1

Abastecimento: poço artesiano

=head2 in_agua_cacimba

  data_type: 'smallint'
  is_nullable: 1

Abastecimento: cacimba

=head2 in_agua_fonte_rio

  data_type: 'smallint'
  is_nullable: 1

Abastecimento: fonte/rio

=head2 in_agua_inexistente

  data_type: 'smallint'
  is_nullable: 1

Inexistente abastecimento de água

=head2 in_agua_carro_pipa

  data_type: 'smallint'
  is_nullable: 1

Abastecimento: carro-pipa

=head2 in_energia_rede_publica

  data_type: 'smallint'
  is_nullable: 1

Energia elétrica: rede pública

=head2 in_energia_gerador_fossil

  data_type: 'smallint'
  is_nullable: 1

Energia: gerador a combustível fóssil

=head2 in_energia_renovavel

  data_type: 'smallint'
  is_nullable: 1

Energia: fonte renovável (solar, eólica)

=head2 in_energia_inexistente

  data_type: 'smallint'
  is_nullable: 1

Inexistente energia elétrica

=head2 in_esgoto_rede_publica

  data_type: 'smallint'
  is_nullable: 1

Esgoto sanitário: rede pública

=head2 in_esgoto_fossa_septica

  data_type: 'smallint'
  is_nullable: 1

Esgoto: fossa séptica

=head2 in_esgoto_fossa_comum

  data_type: 'smallint'
  is_nullable: 1

Esgoto: fossa comum

=head2 in_esgoto_fossa

  data_type: 'smallint'
  is_nullable: 1

Esgoto: fossa (genérico)

=head2 in_esgoto_inexistente

  data_type: 'smallint'
  is_nullable: 1

Inexistente esgotamento sanitário

=head2 in_lixo_servico_coleta

  data_type: 'smallint'
  is_nullable: 1

Destino do lixo: serviço de coleta

=head2 in_lixo_queima

  data_type: 'smallint'
  is_nullable: 1

Destino: queima

=head2 in_lixo_enterra

  data_type: 'smallint'
  is_nullable: 1

Destino: enterra

=head2 in_lixo_destino_final_publico

  data_type: 'smallint'
  is_nullable: 1

Destino: destino final público (lixão/aterro)

=head2 in_lixo_descarta_outra_area

  data_type: 'smallint'
  is_nullable: 1

Destino: descarta em outra área

=head2 in_tratamento_lixo_separacao

  data_type: 'smallint'
  is_nullable: 1

Tratamento do lixo: separação

=head2 in_tratamento_lixo_reutiliza

  data_type: 'smallint'
  is_nullable: 1

Tratamento: reutilização

=head2 in_tratamento_lixo_reciclagem

  data_type: 'smallint'
  is_nullable: 1

Tratamento: reciclagem

=head2 in_tratamento_lixo_inexistente

  data_type: 'smallint'
  is_nullable: 1

Inexistente tratamento de lixo

=head2 in_almoxarifado

  data_type: 'smallint'
  is_nullable: 1

Possui almoxarifado?

=head2 in_area_verde

  data_type: 'smallint'
  is_nullable: 1

Possui área verde?

=head2 in_area_plantio

  data_type: 'smallint'
  is_nullable: 1

Possui área de plantio?

=head2 in_auditorio

  data_type: 'smallint'
  is_nullable: 1

Possui auditório?

=head2 in_banheiro

  data_type: 'smallint'
  is_nullable: 1

Possui banheiro?

=head2 in_banheiro_ei

  data_type: 'smallint'
  is_nullable: 1

Banheiro para educação infantil?

=head2 in_banheiro_pne

  data_type: 'smallint'
  is_nullable: 1

Banheiro acessível para PNE?

=head2 in_banheiro_funcionarios

  data_type: 'smallint'
  is_nullable: 1

Banheiro para funcionários?

=head2 in_banheiro_chuveiro

  data_type: 'smallint'
  is_nullable: 1

Banheiro com chuveiro?

=head2 in_biblioteca

  data_type: 'smallint'
  is_nullable: 1

Possui biblioteca?

=head2 in_biblioteca_sala_leitura

  data_type: 'smallint'
  is_nullable: 1

Possui biblioteca ou sala de leitura?

=head2 in_cozinha

  data_type: 'smallint'
  is_nullable: 1

Possui cozinha?

=head2 in_despensa

  data_type: 'smallint'
  is_nullable: 1

Possui despensa?

=head2 in_dormitorio_aluno

  data_type: 'smallint'
  is_nullable: 1

Possui dormitório para alunos?

=head2 in_dormitorio_professor

  data_type: 'smallint'
  is_nullable: 1

Possui dormitório para professores?

=head2 in_laboratorio_ciencias

  data_type: 'smallint'
  is_nullable: 1

Possui laboratório de ciências?

=head2 in_laboratorio_informatica

  data_type: 'smallint'
  is_nullable: 1

Possui laboratório de informática?

=head2 in_laboratorio_educ_prof

  data_type: 'smallint'
  is_nullable: 1

Possui laboratório de educação profissional?

=head2 in_patio_coberto

  data_type: 'smallint'
  is_nullable: 1

Possui pátio coberto?

=head2 in_patio_descoberto

  data_type: 'smallint'
  is_nullable: 1

Possui pátio descoberto?

=head2 in_parque_infantil

  data_type: 'smallint'
  is_nullable: 1

Possui parque infantil?

=head2 in_piscina

  data_type: 'smallint'
  is_nullable: 1

Possui piscina?

=head2 in_quadra_esportes

  data_type: 'smallint'
  is_nullable: 1

Possui quadra de esportes?

=head2 in_quadra_esportes_coberta

  data_type: 'smallint'
  is_nullable: 1

Quadra coberta?

=head2 in_quadra_esportes_descoberta

  data_type: 'smallint'
  is_nullable: 1

Quadra descoberta?

=head2 in_refeitorio

  data_type: 'smallint'
  is_nullable: 1

Possui refeitório?

=head2 in_sala_atelie_artes

  data_type: 'smallint'
  is_nullable: 1

Possui sala/atelier de artes?

=head2 in_sala_musica_coral

  data_type: 'smallint'
  is_nullable: 1

Possui sala de música/coral?

=head2 in_sala_estudio_danca

  data_type: 'smallint'
  is_nullable: 1

Possui sala/estúdio de dança?

=head2 in_sala_multiuso

  data_type: 'smallint'
  is_nullable: 1

Possui sala multiuso?

=head2 in_sala_estudio_gravacao

  data_type: 'smallint'
  is_nullable: 1

Possui estúdio de gravação?

=head2 in_sala_oficinas_educ_prof

  data_type: 'smallint'
  is_nullable: 1

Possui sala de oficinas de educação profissional?

=head2 in_sala_diretoria

  data_type: 'smallint'
  is_nullable: 1

Possui sala da diretoria?

=head2 in_sala_leitura

  data_type: 'smallint'
  is_nullable: 1

Possui sala de leitura?

=head2 in_sala_professor

  data_type: 'smallint'
  is_nullable: 1

Possui sala dos professores?

=head2 in_sala_repouso_aluno

  data_type: 'smallint'
  is_nullable: 1

Possui sala de repouso para alunos?

=head2 in_secretaria

  data_type: 'smallint'
  is_nullable: 1

Possui secretaria?

=head2 in_sala_atendimento_especial

  data_type: 'smallint'
  is_nullable: 1

Possui sala de atendimento especial?

=head2 in_terreirao

  data_type: 'smallint'
  is_nullable: 1

Possui terreirão (espaço aberto)?

=head2 in_viveiro

  data_type: 'smallint'
  is_nullable: 1

Possui viveiro (plantas)?

=head2 in_dependencias_outras

  data_type: 'smallint'
  is_nullable: 1

Possui outras dependências não listadas?

=head2 in_acessibilidade_corrimao

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: corrimão?

=head2 in_acessibilidade_elevador

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: elevador?

=head2 in_acessibilidade_pisos_tateis

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: pisos táteis?

=head2 in_acessibilidade_vao_livre

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: vão livre (portas largas)?

=head2 in_acessibilidade_rampas

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: rampas?

=head2 in_acessibilidade_sinal_sonoro

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: sinal sonoro?

=head2 in_acessibilidade_sinal_tatil

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: sinal tátil?

=head2 in_acessibilidade_sinal_visual

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: sinal visual?

=head2 in_acessibilidade_inexistente

  data_type: 'smallint'
  is_nullable: 1

Inexistente recursos de acessibilidade?

=head2 in_acessibilidade_sinalizacao

  data_type: 'smallint'
  is_nullable: 1

Acessibilidade: sinalização adequada?

=head2 qt_salas_utilizadas_dentro

  data_type: 'integer'
  is_nullable: 1

Quantidade de salas de aula utilizadas na própria escola

=head2 qt_salas_utilizadas_fora

  data_type: 'integer'
  is_nullable: 1

Quantidade de salas de aula utilizadas fora da escola

=head2 qt_salas_utilizadas

  data_type: 'integer'
  is_nullable: 1

Quantidade total de salas de aula utilizadas

=head2 qt_salas_utiliza_climatizadas

  data_type: 'integer'
  is_nullable: 1

Quantidade de salas de aula climatizadas

=head2 qt_salas_utilizadas_acessiveis

  data_type: 'integer'
  is_nullable: 1

Quantidade de salas acessíveis para PNE

=head2 qt_salas_leitura

  data_type: 'integer'
  is_nullable: 1

Quantidade de salas de leitura

=head2 in_equip_parabolica

  data_type: 'smallint'
  is_nullable: 1

Dispõe de antena parabólica?

=head2 in_computador

  data_type: 'smallint'
  is_nullable: 1

Dispõe de computadores?

=head2 in_equip_copiadora

  data_type: 'smallint'
  is_nullable: 1

Dispõe de copiadora?

=head2 in_equip_impressora

  data_type: 'smallint'
  is_nullable: 1

Dispõe de impressora?

=head2 in_equip_impressora_mult

  data_type: 'smallint'
  is_nullable: 1

Dispõe de impressora multifuncional?

=head2 in_equip_scanner

  data_type: 'smallint'
  is_nullable: 1

Dispõe de scanner?

=head2 in_equip_nenhum

  data_type: 'smallint'
  is_nullable: 1

Não dispõe de nenhum desses equipamentos?

=head2 in_equip_dvd

  data_type: 'smallint'
  is_nullable: 1

Dispõe de equipamento de DVD?

=head2 qt_equip_dvd

  data_type: 'integer'
  is_nullable: 1

Quantidade de aparelhos de DVD

=head2 in_equip_som

  data_type: 'smallint'
  is_nullable: 1

Dispõe de equipamento de som?

=head2 qt_equip_som

  data_type: 'integer'
  is_nullable: 1

Quantidade de equipamentos de som

=head2 in_equip_tv

  data_type: 'smallint'
  is_nullable: 1

Dispõe de televisão?

=head2 qt_equip_tv

  data_type: 'integer'
  is_nullable: 1

Quantidade de televisores

=head2 in_equip_lousa_digital

  data_type: 'smallint'
  is_nullable: 1

Dispõe de lousa digital?

=head2 qt_equip_lousa_digital

  data_type: 'integer'
  is_nullable: 1

Quantidade de lousas digitais

=head2 in_equip_multimidia

  data_type: 'smallint'
  is_nullable: 1

Dispõe de equipamento multimídia (projetor, etc.)?

=head2 qt_equip_multimidia

  data_type: 'integer'
  is_nullable: 1

Quantidade de equipamentos multimídia

=head2 in_desktop_aluno

  data_type: 'smallint'
  is_nullable: 1

Dispõe de computadores desktop para alunos?

=head2 qt_desktop_aluno

  data_type: 'integer'
  is_nullable: 1

Quantidade de desktops para alunos

=head2 in_comp_portatil_aluno

  data_type: 'smallint'
  is_nullable: 1

Dispõe de computadores portáteis (notebooks) para alunos?

=head2 qt_comp_portatil_aluno

  data_type: 'integer'
  is_nullable: 1

Quantidade de portáteis para alunos

=head2 in_tablet_aluno

  data_type: 'smallint'
  is_nullable: 1

Dispõe de tablets para alunos?

=head2 qt_tablet_aluno

  data_type: 'integer'
  is_nullable: 1

Quantidade de tablets para alunos

=head2 in_internet

  data_type: 'smallint'
  is_nullable: 1

Acesso à internet na escola?

=head2 in_internet_alunos

  data_type: 'smallint'
  is_nullable: 1

Uso da internet para atividades dos alunos?

=head2 in_internet_administrativo

  data_type: 'smallint'
  is_nullable: 1

Uso da internet para atividades administrativas?

=head2 in_internet_aprendizagem

  data_type: 'smallint'
  is_nullable: 1

Uso da internet na aprendizagem?

=head2 in_internet_comunidade

  data_type: 'smallint'
  is_nullable: 1

Uso da internet pela comunidade?

=head2 in_acesso_internet_computador

  data_type: 'smallint'
  is_nullable: 1

Acesso à internet via computador

=head2 in_aces_internet_disp_pessoais

  data_type: 'smallint'
  is_nullable: 1

Acesso à internet via dispositivos pessoais

=head2 tp_rede_local

  data_type: 'smallint'
  is_nullable: 1

Tipo de rede local: 0-inexistente,1-com fio,2-wifi,3-ambas

=head2 in_banda_larga

  data_type: 'smallint'
  is_nullable: 1

Conexão de banda larga?

=head2 qt_prof_administrativos

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais administrativos

=head2 qt_prof_servicos_gerais

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais de serviços gerais

=head2 qt_prof_bibliotecario

  data_type: 'integer'
  is_nullable: 1

Quantidade de bibliotecários

=head2 qt_prof_saude

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais de saúde (enfermagem, etc.)

=head2 qt_prof_coordenador

  data_type: 'integer'
  is_nullable: 1

Quantidade de coordenadores

=head2 qt_prof_fonaudiologo

  data_type: 'integer'
  is_nullable: 1

Quantidade de fonoaudiólogos

=head2 qt_prof_nutricionista

  data_type: 'integer'
  is_nullable: 1

Quantidade de nutricionistas

=head2 qt_prof_psicologo

  data_type: 'integer'
  is_nullable: 1

Quantidade de psicólogos

=head2 qt_prof_alimentacao

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais de alimentação

=head2 qt_prof_pedagogia

  data_type: 'integer'
  is_nullable: 1

Quantidade de pedagogos

=head2 qt_prof_secretario

  data_type: 'integer'
  is_nullable: 1

Quantidade de secretários

=head2 qt_prof_seguranca

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais de segurança

=head2 qt_prof_monitores

  data_type: 'integer'
  is_nullable: 1

Quantidade de monitores

=head2 qt_prof_gestao

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais de gestão

=head2 qt_prof_assist_social

  data_type: 'integer'
  is_nullable: 1

Quantidade de assistentes sociais

=head2 qt_prof_trad_libras

  data_type: 'integer'
  is_nullable: 1

Quantidade de tradutores/intérpretes de Libras

=head2 qt_prof_agricola

  data_type: 'integer'
  is_nullable: 1

Quantidade de profissionais agrícolas

=head2 qt_prof_revisor_braille

  data_type: 'integer'
  is_nullable: 1

Quantidade de revisores de Braille

=head2 in_alimentacao

  data_type: 'smallint'
  is_nullable: 1

Oferece alimentação escolar?

=head2 in_material_ped_multimidia

  data_type: 'smallint'
  is_nullable: 1

Materiais pedagógicos: multimídia

=head2 in_material_ped_infantil

  data_type: 'smallint'
  is_nullable: 1

Materiais: educação infantil

=head2 in_material_ped_cientifico

  data_type: 'smallint'
  is_nullable: 1

Materiais: científico

=head2 in_material_ped_difusao

  data_type: 'smallint'
  is_nullable: 1

Materiais: difusão (cultura geral)

=head2 in_material_ped_musical

  data_type: 'smallint'
  is_nullable: 1

Materiais: musical

=head2 in_material_ped_jogos

  data_type: 'smallint'
  is_nullable: 1

Materiais: jogos educativos

=head2 in_material_ped_artisticas

  data_type: 'smallint'
  is_nullable: 1

Materiais: artes

=head2 in_material_ped_profissional

  data_type: 'smallint'
  is_nullable: 1

Materiais: profissionalizante

=head2 in_material_ped_desportiva

  data_type: 'smallint'
  is_nullable: 1

Materiais: esportiva

=head2 in_material_ped_indigena

  data_type: 'smallint'
  is_nullable: 1

Materiais: indígena

=head2 in_material_ped_etnico

  data_type: 'smallint'
  is_nullable: 1

Materiais: étnico-racial

=head2 in_material_ped_campo

  data_type: 'smallint'
  is_nullable: 1

Materiais: educação do campo

=head2 in_material_ped_bil_surdos

  data_type: 'smallint'
  is_nullable: 1

Materiais: bilíngue para surdos

=head2 in_material_ped_agricola

  data_type: 'smallint'
  is_nullable: 1

Materiais: agrícola

=head2 in_material_ped_quilombola

  data_type: 'smallint'
  is_nullable: 1

Materiais: quilombola

=head2 in_material_ped_edu_esp

  data_type: 'smallint'
  is_nullable: 1

Materiais: educação especial

=head2 in_material_ped_nenhum

  data_type: 'smallint'
  is_nullable: 1

Nenhum material pedagógico listado

=head2 in_educacao_indigena

  data_type: 'smallint'
  is_nullable: 1

Oferece educação indígena específica?

=head2 tp_indigena_lingua

  data_type: 'smallint'
  is_nullable: 1

Língua usada na educação indígena: 1-indígena,2-português,3-ambas

=head2 co_lingua_indigena_1

  data_type: 'integer'
  is_nullable: 1

Código da primeira língua indígena usada

=head2 co_lingua_indigena_2

  data_type: 'integer'
  is_nullable: 1

Código da segunda língua indígena usada

=head2 co_lingua_indigena_3

  data_type: 'integer'
  is_nullable: 1

Código da terceira língua indígena usada

=head2 in_exame_selecao

  data_type: 'smallint'
  is_nullable: 1

Utiliza processo seletivo para ingresso?

=head2 in_reserva_ppi

  data_type: 'smallint'
  is_nullable: 1

Possui reserva de vagas para pretos, pardos e indígenas?

=head2 in_reserva_renda

  data_type: 'smallint'
  is_nullable: 1

Reserva de vagas por critério de renda?

=head2 in_reserva_publica

  data_type: 'smallint'
  is_nullable: 1

Reserva de vagas para egressos de escola pública?

=head2 in_reserva_pcd

  data_type: 'smallint'
  is_nullable: 1

Reserva de vagas para pessoas com deficiência?

=head2 in_reserva_outros

  data_type: 'smallint'
  is_nullable: 1

Outros tipos de reserva de vagas?

=head2 in_reserva_nenhuma

  data_type: 'smallint'
  is_nullable: 1

Nenhuma reserva de vagas?

=head2 in_redes_sociais

  data_type: 'smallint'
  is_nullable: 1

Possui perfil oficial em redes sociais?

=head2 in_espaco_atividade

  data_type: 'smallint'
  is_nullable: 1

Possui espaços para atividades complementares?

=head2 in_espaco_equipamento

  data_type: 'smallint'
  is_nullable: 1

Possui equipamentos para atividades complementares?

=head2 in_orgao_ass_pais

  data_type: 'smallint'
  is_nullable: 1

Possui associação de pais?

=head2 in_orgao_ass_pais_mestres

  data_type: 'smallint'
  is_nullable: 1

Possui associação de pais e mestres?

=head2 in_orgao_conselho_escolar

  data_type: 'smallint'
  is_nullable: 1

Possui conselho escolar?

=head2 in_orgao_gremio_estudantil

  data_type: 'smallint'
  is_nullable: 1

Possui grêmio estudantil?

=head2 in_orgao_outros

  data_type: 'smallint'
  is_nullable: 1

Possui outros órgãos colegiados?

=head2 in_orgao_nenhum

  data_type: 'smallint'
  is_nullable: 1

Nenhum órgão colegiado?

=head2 tp_proposta_pedagogica

  data_type: 'smallint'
  is_nullable: 1

Tipo de proposta pedagógica: 1-Própria,2-Da rede,3-Adaptada da rede

=head2 in_educ_ambiental

  data_type: 'smallint'
  is_nullable: 1

Aborda educação ambiental?

=head2 in_educ_amb_conteudo

  data_type: 'smallint'
  is_nullable: 1

Educação ambiental como conteúdo?

=head2 in_educ_amb_curricular

  data_type: 'smallint'
  is_nullable: 1

Educação ambiental na matriz curricular?

=head2 in_educ_amb_eixo

  data_type: 'smallint'
  is_nullable: 1

Educação ambiental como eixo transversal?

=head2 in_educ_amb_eventos

  data_type: 'smallint'
  is_nullable: 1

Atividades de educação ambiental em eventos?

=head2 in_educ_amb_projetos

  data_type: 'smallint'
  is_nullable: 1

Projetos de educação ambiental?

=head2 in_educ_amb_nenhuma

  data_type: 'smallint'
  is_nullable: 1

Nenhuma abordagem de educação ambiental

=head2 tp_aee

  data_type: 'smallint'
  is_nullable: 1

Tipo de Atendimento Educacional Especializado: 1-Sala multifuncional,2-Outras salas,3-Canto de atividades,4-Itinerância,5-Classe hospitalar,8-Não se aplica

=head2 tp_atividade_complementar

  data_type: 'smallint'
  is_nullable: 1

Tipo de atividade complementar: 1-Meio período,2-Período integral,3-Ambas

=head2 tp_itinerario_formativo

  data_type: 'smallint'
  is_nullable: 1

Itinerário formativo (Novo EM): 1-Linguagens,2-Matemática,3-Ciências da Natureza,4-Ciências Humanas,5-Técnico profissional

=head2 in_itinerario_aprofundamento

  data_type: 'smallint'
  is_nullable: 1

Itinerário de aprofundamento?

=head2 in_itinerario_tecn_prof

  data_type: 'smallint'
  is_nullable: 1

Itinerário técnico-profissional?

=head2 in_escolarizacao

  data_type: 'smallint'
  is_nullable: 1

Promove escolarização?

=head2 in_mediacao_presencial

  data_type: 'smallint'
  is_nullable: 1

Mediação presencial

=head2 in_mediacao_semipresencial

  data_type: 'smallint'
  is_nullable: 1

Mediação semipresencial

=head2 in_mediacao_ead

  data_type: 'smallint'
  is_nullable: 1

Mediação a distância (EAD)

=head2 in_especial_exclusiva

  data_type: 'smallint'
  is_nullable: 1

Oferece educação especial exclusiva?

=head2 in_regular

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino regular?

=head2 in_eja

  data_type: 'smallint'
  is_nullable: 1

Oferece Educação de Jovens e Adultos (EJA)?

=head2 in_profissionalizante

  data_type: 'smallint'
  is_nullable: 1

Oferece educação profissional?

=head2 in_comum_creche

  data_type: 'smallint'
  is_nullable: 1

Oferece creche (regular)?

=head2 in_comum_pre

  data_type: 'smallint'
  is_nullable: 1

Oferece pré-escola (regular)?

=head2 in_comum_fund_ai

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino fundamental anos iniciais (regular)?

=head2 in_comum_fund_af

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino fundamental anos finais (regular)?

=head2 in_comum_medio_medio

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino médio regular?

=head2 in_comum_medio_integrado

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino médio integrado (regular)?

=head2 in_comum_medio_fic

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino médio - FIC (regular)?

=head2 in_comum_medio_normal

  data_type: 'smallint'
  is_nullable: 1

Oferece curso normal (magistério) em nível médio?

=head2 in_esp_exclusiva_creche

  data_type: 'smallint'
  is_nullable: 1

Oferece creche (educação especial exclusiva)?

=head2 in_esp_exclusiva_pre

  data_type: 'smallint'
  is_nullable: 1

Oferece pré-escola (educação especial exclusiva)?

=head2 in_esp_exclusiva_fund_ai

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino fundamental AI (educação especial exclusiva)?

=head2 in_esp_exclusiva_fund_af

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino fundamental AF (educação especial exclusiva)?

=head2 in_esp_exclusiva_medio_medio

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino médio (educação especial exclusiva)?

=head2 in_esp_exclusiva_medio_integr

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino médio integrado (educação especial exclusiva)?

=head2 in_esp_exclusiva_medio_fic

  data_type: 'smallint'
  is_nullable: 1

Oferece ensino médio FIC (educação especial exclusiva)?

=head2 in_esp_exclusiva_medio_normal

  data_type: 'smallint'
  is_nullable: 1

Oferece curso normal (magistério) em nível médio (educação especial exclusiva)?

=head2 in_comum_eja_fund

  data_type: 'smallint'
  is_nullable: 1

Oferece EJA fundamental (regular)?

=head2 in_comum_eja_medio

  data_type: 'smallint'
  is_nullable: 1

Oferece EJA médio (regular)?

=head2 in_comum_eja_prof

  data_type: 'smallint'
  is_nullable: 1

Oferece EJA profissionalizante (regular)?

=head2 in_esp_exclusiva_eja_fund

  data_type: 'smallint'
  is_nullable: 1

Oferece EJA fundamental (educação especial exclusiva)?

=head2 in_esp_exclusiva_eja_medio

  data_type: 'smallint'
  is_nullable: 1

Oferece EJA médio (educação especial exclusiva)?

=head2 in_esp_exclusiva_eja_prof

  data_type: 'smallint'
  is_nullable: 1

Oferece EJA profissional (educação especial exclusiva)?

=head2 in_comum_prof

  data_type: 'smallint'
  is_nullable: 1

Oferece educação profissional (regular)?

=head2 in_esp_exclusiva_prof

  data_type: 'smallint'
  is_nullable: 1

Oferece educação profissional (educação especial exclusiva)?

=head2 geometry

  data_type: 'geometry'
  is_nullable: 1
  size: [18,16896]

=head2 nro_participacoes_exame

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Número de exames nacionais já realizados

=cut

__PACKAGE__->add_columns(
  "linha_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "censo_escolas_linha_id_seq",
  },
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 1 },
  "no_regiao",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "co_regiao",
  { data_type => "smallint", is_nullable => 1 },
  "no_uf",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "sg_uf",
  { data_type => "char", is_nullable => 1, size => 2 },
  "co_uf",
  { data_type => "smallint", is_nullable => 1 },
  "no_municipio",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_municipio",
  { data_type => "integer", is_nullable => 1 },
  "no_regiao_geog_interm",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_regiao_geog_interm",
  { data_type => "integer", is_nullable => 1 },
  "no_regiao_geog_imed",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_regiao_geog_imed",
  { data_type => "integer", is_nullable => 1 },
  "no_mesorregiao",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_mesorregiao",
  { data_type => "integer", is_nullable => 1 },
  "no_microrregiao",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_microrregiao",
  { data_type => "integer", is_nullable => 1 },
  "no_distrito",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_distrito",
  { data_type => "integer", is_nullable => 1 },
  "no_regiao_administrativa",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_regiao_administrativa",
  { data_type => "integer", is_nullable => 1 },
  "no_entidade",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "tp_dependencia",
  { data_type => "smallint", is_nullable => 1 },
  "tp_categoria_escola_privada",
  { data_type => "smallint", is_nullable => 1 },
  "tp_localizacao",
  { data_type => "smallint", is_nullable => 1 },
  "tp_localizacao_diferenciada",
  { data_type => "smallint", is_nullable => 1 },
  "ds_endereco",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "nu_endereco",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "ds_complemento",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "no_bairro",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "co_cep",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "nu_ddd",
  { data_type => "smallint", is_nullable => 1 },
  "nu_telefone",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "latitude",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa63b960)"],
  },
  "longitude",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa010ae8)"],
  },
  "tp_situacao_funcionamento",
  { data_type => "smallint", is_nullable => 1 },
  "co_orgao_regional",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "dt_ano_letivo_inicio",
  { data_type => "date", is_nullable => 1 },
  "dt_ano_letivo_termino",
  { data_type => "date", is_nullable => 1 },
  "in_vinculo_secretaria_educacao",
  { data_type => "smallint", is_nullable => 1 },
  "in_vinculo_seguranca_publica",
  { data_type => "smallint", is_nullable => 1 },
  "in_vinculo_secretaria_saude",
  { data_type => "smallint", is_nullable => 1 },
  "in_vinculo_outro_orgao",
  { data_type => "smallint", is_nullable => 1 },
  "in_poder_publico_parceria",
  { data_type => "smallint", is_nullable => 1 },
  "tp_poder_publico_parceria",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_termo_colabora",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_termo_fomento",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_acordo_coop",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_prestacao_serv",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_coop_tec_fin",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_consorcio_pub",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_mu_termo_colab",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_mu_termo_fomento",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_mu_acordo_coop",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_mu_prest_serv",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_mu_coop_tec_fin",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_mu_consorcio_pub",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_es_termo_colab",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_es_termo_fomento",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_es_acordo_coop",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_es_prest_serv",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_es_coop_tec_fin",
  { data_type => "smallint", is_nullable => 1 },
  "in_forma_cont_es_consorcio_pub",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_privada_emp",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_privada_ong",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_privada_oscip",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_priv_ong_oscip",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_privada_sind",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_privada_sist_s",
  { data_type => "smallint", is_nullable => 1 },
  "in_mant_escola_privada_s_fins",
  { data_type => "smallint", is_nullable => 1 },
  "nu_cnpj_escola_privada",
  { data_type => "varchar", is_nullable => 1, size => 18 },
  "nu_cnpj_mantenedora",
  { data_type => "varchar", is_nullable => 1, size => 18 },
  "tp_regulamentacao",
  { data_type => "smallint", is_nullable => 1 },
  "tp_responsavel_regulamentacao",
  { data_type => "smallint", is_nullable => 1 },
  "co_escola_sede_vinculada",
  { data_type => "bigint", is_nullable => 1 },
  "co_ies_ofertante",
  { data_type => "integer", is_nullable => 1 },
  "in_local_func_predio_escolar",
  { data_type => "smallint", is_nullable => 1 },
  "tp_ocupacao_predio_escolar",
  { data_type => "smallint", is_nullable => 1 },
  "in_local_func_socioeducativo",
  { data_type => "smallint", is_nullable => 1 },
  "in_local_func_unid_prisional",
  { data_type => "smallint", is_nullable => 1 },
  "in_local_func_prisional_socio",
  { data_type => "smallint", is_nullable => 1 },
  "in_local_func_galpao",
  { data_type => "smallint", is_nullable => 1 },
  "tp_ocupacao_galpao",
  { data_type => "smallint", is_nullable => 1 },
  "in_local_func_salas_outra_esc",
  { data_type => "smallint", is_nullable => 1 },
  "in_local_func_outros",
  { data_type => "smallint", is_nullable => 1 },
  "in_predio_compartilhado",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_potavel",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_rede_publica",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_poco_artesiano",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_cacimba",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_fonte_rio",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_inexistente",
  { data_type => "smallint", is_nullable => 1 },
  "in_agua_carro_pipa",
  { data_type => "smallint", is_nullable => 1 },
  "in_energia_rede_publica",
  { data_type => "smallint", is_nullable => 1 },
  "in_energia_gerador_fossil",
  { data_type => "smallint", is_nullable => 1 },
  "in_energia_renovavel",
  { data_type => "smallint", is_nullable => 1 },
  "in_energia_inexistente",
  { data_type => "smallint", is_nullable => 1 },
  "in_esgoto_rede_publica",
  { data_type => "smallint", is_nullable => 1 },
  "in_esgoto_fossa_septica",
  { data_type => "smallint", is_nullable => 1 },
  "in_esgoto_fossa_comum",
  { data_type => "smallint", is_nullable => 1 },
  "in_esgoto_fossa",
  { data_type => "smallint", is_nullable => 1 },
  "in_esgoto_inexistente",
  { data_type => "smallint", is_nullable => 1 },
  "in_lixo_servico_coleta",
  { data_type => "smallint", is_nullable => 1 },
  "in_lixo_queima",
  { data_type => "smallint", is_nullable => 1 },
  "in_lixo_enterra",
  { data_type => "smallint", is_nullable => 1 },
  "in_lixo_destino_final_publico",
  { data_type => "smallint", is_nullable => 1 },
  "in_lixo_descarta_outra_area",
  { data_type => "smallint", is_nullable => 1 },
  "in_tratamento_lixo_separacao",
  { data_type => "smallint", is_nullable => 1 },
  "in_tratamento_lixo_reutiliza",
  { data_type => "smallint", is_nullable => 1 },
  "in_tratamento_lixo_reciclagem",
  { data_type => "smallint", is_nullable => 1 },
  "in_tratamento_lixo_inexistente",
  { data_type => "smallint", is_nullable => 1 },
  "in_almoxarifado",
  { data_type => "smallint", is_nullable => 1 },
  "in_area_verde",
  { data_type => "smallint", is_nullable => 1 },
  "in_area_plantio",
  { data_type => "smallint", is_nullable => 1 },
  "in_auditorio",
  { data_type => "smallint", is_nullable => 1 },
  "in_banheiro",
  { data_type => "smallint", is_nullable => 1 },
  "in_banheiro_ei",
  { data_type => "smallint", is_nullable => 1 },
  "in_banheiro_pne",
  { data_type => "smallint", is_nullable => 1 },
  "in_banheiro_funcionarios",
  { data_type => "smallint", is_nullable => 1 },
  "in_banheiro_chuveiro",
  { data_type => "smallint", is_nullable => 1 },
  "in_biblioteca",
  { data_type => "smallint", is_nullable => 1 },
  "in_biblioteca_sala_leitura",
  { data_type => "smallint", is_nullable => 1 },
  "in_cozinha",
  { data_type => "smallint", is_nullable => 1 },
  "in_despensa",
  { data_type => "smallint", is_nullable => 1 },
  "in_dormitorio_aluno",
  { data_type => "smallint", is_nullable => 1 },
  "in_dormitorio_professor",
  { data_type => "smallint", is_nullable => 1 },
  "in_laboratorio_ciencias",
  { data_type => "smallint", is_nullable => 1 },
  "in_laboratorio_informatica",
  { data_type => "smallint", is_nullable => 1 },
  "in_laboratorio_educ_prof",
  { data_type => "smallint", is_nullable => 1 },
  "in_patio_coberto",
  { data_type => "smallint", is_nullable => 1 },
  "in_patio_descoberto",
  { data_type => "smallint", is_nullable => 1 },
  "in_parque_infantil",
  { data_type => "smallint", is_nullable => 1 },
  "in_piscina",
  { data_type => "smallint", is_nullable => 1 },
  "in_quadra_esportes",
  { data_type => "smallint", is_nullable => 1 },
  "in_quadra_esportes_coberta",
  { data_type => "smallint", is_nullable => 1 },
  "in_quadra_esportes_descoberta",
  { data_type => "smallint", is_nullable => 1 },
  "in_refeitorio",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_atelie_artes",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_musica_coral",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_estudio_danca",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_multiuso",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_estudio_gravacao",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_oficinas_educ_prof",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_diretoria",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_leitura",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_professor",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_repouso_aluno",
  { data_type => "smallint", is_nullable => 1 },
  "in_secretaria",
  { data_type => "smallint", is_nullable => 1 },
  "in_sala_atendimento_especial",
  { data_type => "smallint", is_nullable => 1 },
  "in_terreirao",
  { data_type => "smallint", is_nullable => 1 },
  "in_viveiro",
  { data_type => "smallint", is_nullable => 1 },
  "in_dependencias_outras",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_corrimao",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_elevador",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_pisos_tateis",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_vao_livre",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_rampas",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_sinal_sonoro",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_sinal_tatil",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_sinal_visual",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_inexistente",
  { data_type => "smallint", is_nullable => 1 },
  "in_acessibilidade_sinalizacao",
  { data_type => "smallint", is_nullable => 1 },
  "qt_salas_utilizadas_dentro",
  { data_type => "integer", is_nullable => 1 },
  "qt_salas_utilizadas_fora",
  { data_type => "integer", is_nullable => 1 },
  "qt_salas_utilizadas",
  { data_type => "integer", is_nullable => 1 },
  "qt_salas_utiliza_climatizadas",
  { data_type => "integer", is_nullable => 1 },
  "qt_salas_utilizadas_acessiveis",
  { data_type => "integer", is_nullable => 1 },
  "qt_salas_leitura",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_parabolica",
  { data_type => "smallint", is_nullable => 1 },
  "in_computador",
  { data_type => "smallint", is_nullable => 1 },
  "in_equip_copiadora",
  { data_type => "smallint", is_nullable => 1 },
  "in_equip_impressora",
  { data_type => "smallint", is_nullable => 1 },
  "in_equip_impressora_mult",
  { data_type => "smallint", is_nullable => 1 },
  "in_equip_scanner",
  { data_type => "smallint", is_nullable => 1 },
  "in_equip_nenhum",
  { data_type => "smallint", is_nullable => 1 },
  "in_equip_dvd",
  { data_type => "smallint", is_nullable => 1 },
  "qt_equip_dvd",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_som",
  { data_type => "smallint", is_nullable => 1 },
  "qt_equip_som",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_tv",
  { data_type => "smallint", is_nullable => 1 },
  "qt_equip_tv",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_lousa_digital",
  { data_type => "smallint", is_nullable => 1 },
  "qt_equip_lousa_digital",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_multimidia",
  { data_type => "smallint", is_nullable => 1 },
  "qt_equip_multimidia",
  { data_type => "integer", is_nullable => 1 },
  "in_desktop_aluno",
  { data_type => "smallint", is_nullable => 1 },
  "qt_desktop_aluno",
  { data_type => "integer", is_nullable => 1 },
  "in_comp_portatil_aluno",
  { data_type => "smallint", is_nullable => 1 },
  "qt_comp_portatil_aluno",
  { data_type => "integer", is_nullable => 1 },
  "in_tablet_aluno",
  { data_type => "smallint", is_nullable => 1 },
  "qt_tablet_aluno",
  { data_type => "integer", is_nullable => 1 },
  "in_internet",
  { data_type => "smallint", is_nullable => 1 },
  "in_internet_alunos",
  { data_type => "smallint", is_nullable => 1 },
  "in_internet_administrativo",
  { data_type => "smallint", is_nullable => 1 },
  "in_internet_aprendizagem",
  { data_type => "smallint", is_nullable => 1 },
  "in_internet_comunidade",
  { data_type => "smallint", is_nullable => 1 },
  "in_acesso_internet_computador",
  { data_type => "smallint", is_nullable => 1 },
  "in_aces_internet_disp_pessoais",
  { data_type => "smallint", is_nullable => 1 },
  "tp_rede_local",
  { data_type => "smallint", is_nullable => 1 },
  "in_banda_larga",
  { data_type => "smallint", is_nullable => 1 },
  "qt_prof_administrativos",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_servicos_gerais",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_bibliotecario",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_saude",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_coordenador",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_fonaudiologo",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_nutricionista",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_psicologo",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_alimentacao",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_pedagogia",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_secretario",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_seguranca",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_monitores",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_gestao",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_assist_social",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_trad_libras",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_agricola",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_revisor_braille",
  { data_type => "integer", is_nullable => 1 },
  "in_alimentacao",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_multimidia",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_infantil",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_cientifico",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_difusao",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_musical",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_jogos",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_artisticas",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_profissional",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_desportiva",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_indigena",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_etnico",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_campo",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_bil_surdos",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_agricola",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_quilombola",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_edu_esp",
  { data_type => "smallint", is_nullable => 1 },
  "in_material_ped_nenhum",
  { data_type => "smallint", is_nullable => 1 },
  "in_educacao_indigena",
  { data_type => "smallint", is_nullable => 1 },
  "tp_indigena_lingua",
  { data_type => "smallint", is_nullable => 1 },
  "co_lingua_indigena_1",
  { data_type => "integer", is_nullable => 1 },
  "co_lingua_indigena_2",
  { data_type => "integer", is_nullable => 1 },
  "co_lingua_indigena_3",
  { data_type => "integer", is_nullable => 1 },
  "in_exame_selecao",
  { data_type => "smallint", is_nullable => 1 },
  "in_reserva_ppi",
  { data_type => "smallint", is_nullable => 1 },
  "in_reserva_renda",
  { data_type => "smallint", is_nullable => 1 },
  "in_reserva_publica",
  { data_type => "smallint", is_nullable => 1 },
  "in_reserva_pcd",
  { data_type => "smallint", is_nullable => 1 },
  "in_reserva_outros",
  { data_type => "smallint", is_nullable => 1 },
  "in_reserva_nenhuma",
  { data_type => "smallint", is_nullable => 1 },
  "in_redes_sociais",
  { data_type => "smallint", is_nullable => 1 },
  "in_espaco_atividade",
  { data_type => "smallint", is_nullable => 1 },
  "in_espaco_equipamento",
  { data_type => "smallint", is_nullable => 1 },
  "in_orgao_ass_pais",
  { data_type => "smallint", is_nullable => 1 },
  "in_orgao_ass_pais_mestres",
  { data_type => "smallint", is_nullable => 1 },
  "in_orgao_conselho_escolar",
  { data_type => "smallint", is_nullable => 1 },
  "in_orgao_gremio_estudantil",
  { data_type => "smallint", is_nullable => 1 },
  "in_orgao_outros",
  { data_type => "smallint", is_nullable => 1 },
  "in_orgao_nenhum",
  { data_type => "smallint", is_nullable => 1 },
  "tp_proposta_pedagogica",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_ambiental",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_amb_conteudo",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_amb_curricular",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_amb_eixo",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_amb_eventos",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_amb_projetos",
  { data_type => "smallint", is_nullable => 1 },
  "in_educ_amb_nenhuma",
  { data_type => "smallint", is_nullable => 1 },
  "tp_aee",
  { data_type => "smallint", is_nullable => 1 },
  "tp_atividade_complementar",
  { data_type => "smallint", is_nullable => 1 },
  "tp_itinerario_formativo",
  { data_type => "smallint", is_nullable => 1 },
  "in_itinerario_aprofundamento",
  { data_type => "smallint", is_nullable => 1 },
  "in_itinerario_tecn_prof",
  { data_type => "smallint", is_nullable => 1 },
  "in_escolarizacao",
  { data_type => "smallint", is_nullable => 1 },
  "in_mediacao_presencial",
  { data_type => "smallint", is_nullable => 1 },
  "in_mediacao_semipresencial",
  { data_type => "smallint", is_nullable => 1 },
  "in_mediacao_ead",
  { data_type => "smallint", is_nullable => 1 },
  "in_especial_exclusiva",
  { data_type => "smallint", is_nullable => 1 },
  "in_regular",
  { data_type => "smallint", is_nullable => 1 },
  "in_eja",
  { data_type => "smallint", is_nullable => 1 },
  "in_profissionalizante",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_creche",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_pre",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_fund_ai",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_fund_af",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_medio_medio",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_medio_integrado",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_medio_fic",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_medio_normal",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_creche",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_pre",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_fund_ai",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_fund_af",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_medio_medio",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_medio_integr",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_medio_fic",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_medio_normal",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_eja_fund",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_eja_medio",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_eja_prof",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_eja_fund",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_eja_medio",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_eja_prof",
  { data_type => "smallint", is_nullable => 1 },
  "in_comum_prof",
  { data_type => "smallint", is_nullable => 1 },
  "in_esp_exclusiva_prof",
  { data_type => "smallint", is_nullable => 1 },
  "geometry",
  { data_type => "geometry", is_nullable => 1, size => [18, 16896] },
  "nro_participacoes_exame",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</linha_id>

=back

=cut

__PACKAGE__->set_primary_key("linha_id");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-13 15:42:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FPzGx57Fkdsg0qv4o2AyxQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
#
__PACKAGE__->has_one(
  'escola',
  'EduMaps::Schema::Result::Escolas',
  {'foreign.codigo_inep' => 'self.co_entidade' },
);

__PACKAGE__->has_one(
  'score',
  'EduMaps::Schema::Result::CensoEscolasScores',
  { 'foreign.co_entidade' => 'self.co_entidade' },
);

__PACKAGE__->has_many(
  'matricula',
  'EduMaps::Schema::Result::CensoMatriculas',
  { 'foreign.co_entidade' => 'self.co_entidade' },
  { join_type => 'INNER' },
);

__PACKAGE__->has_many(
  'docente',
  'EduMaps::Schema::Result::CensoDocentes',
  { 'foreign.co_entidade' => 'self.co_entidade' },
  { join_type => 'INNER' },
);

__PACKAGE__->has_many(
  'gestor',
  'EduMaps::Schema::Result::CensoGestor',
  { 'foreign.co_entidade' => 'self.co_entidade' },
  { join_type => 'INNER' },
);

__PACKAGE__->has_many(
  'nota_ideb',
  'EduMaps::Schema::Result::IdebNotasEscolas',
  { 'foreign.id_escola' => 'self.co_entidade' },
  { join_type => 'INNER' },
);

1;
