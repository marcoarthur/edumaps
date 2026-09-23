package EduMaps::Roles::Business::Gestor::Overview;
use Mojo::Base -role, -signatures;
use utf8;

# Raio-x da escola para o gestor: matrículas (etapa/turno/modalidade/faixa
# etária), salas, docentes (formação/vínculo/disciplina), infraestrutura,
# equipamentos e acessibilidade. Fonte única: Censo Escolar 2025
# (clean.censo_escolas / censo_matriculas / censo_docentes). Não usa as
# tabelas clean.inep* (deprecated).

requires qw(schema);

our $DEFAULT_YEAR = 2025;

our %REDE = (
  1 => 'Federal',
  2 => 'Estadual',
  3 => 'Municipal',
  4 => 'Privada',
);

our %LOCALIZACAO = (
  1 => 'Urbana',
  2 => 'Rural',
);

# --- Especificações (key, rótulo PT-BR, coluna do Censo) ------------------

our @ETAPAS = (
  { key => 'creche',             label => 'Creche',                      col => 'qt_mat_inf_cre' },
  { key => 'pre_escola',         label => 'Pré-escola',                  col => 'qt_mat_inf_pre' },
  { key => 'fundamental_ai',     label => 'Fundamental — Anos Iniciais', col => 'qt_mat_fund_ai' },
  { key => 'fundamental_af',     label => 'Fundamental — Anos Finais',   col => 'qt_mat_fund_af' },
  { key => 'ensino_medio',       label => 'Ensino Médio',                col => 'qt_mat_med' },
  { key => 'eja',                label => 'EJA',                         col => 'qt_mat_eja' },
  { key => 'profissionalizante', label => 'Educação Profissional',       col => 'qt_mat_prof' },
);

our @TURNO = (
  { key => 'matutino',   label => 'Matutino',   col => 'qt_mat_bas_dm' },
  { key => 'vespertino', label => 'Vespertino', col => 'qt_mat_bas_dv' },
  { key => 'noturno',    label => 'Noturno',    col => 'qt_mat_bas_n' },
);

our @FAIXAS = (
  { key => '0-3',   label => '0 a 3 anos',      col => 'qt_mat_bas_0_3' },
  { key => '4-5',   label => '4 a 5 anos',      col => 'qt_mat_bas_4_5' },
  { key => '6-10',  label => '6 a 10 anos',     col => 'qt_mat_bas_6_10' },
  { key => '11-14', label => '11 a 14 anos',    col => 'qt_mat_bas_11_14' },
  { key => '15-17', label => '15 a 17 anos',    col => 'qt_mat_bas_15_17' },
  { key => '18+',   label => '18 anos ou mais', col => 'qt_mat_bas_18_mais' },
);

our @FORMACAO = (
  { key => 'fundamental',               label => 'Ensino Fundamental',            col => 'qt_doc_bas_esco_ef' },
  { key => 'medio',                     label => 'Ensino Médio',                  col => 'qt_doc_bas_esco_em' },
  { key => 'superior',                  label => 'Superior (total)',              col => 'qt_doc_bas_esco_sup_grad' },
  { key => 'superior_licenciatura',     label => 'Superior — Licenciatura',       col => 'qt_doc_bas_esco_sup_grad_licen' },
  { key => 'superior_sem_licenciatura', label => 'Superior — Sem licenciatura',   col => 'qt_doc_bas_esco_sup_grad_slicen' },
  { key => 'especializacao',            label => 'Especialização',                col => 'qt_doc_bas_esco_sup_pos_espec' },
  { key => 'mestrado',                  label => 'Mestrado',                      col => 'qt_doc_bas_esco_sup_pos_mestra' },
  { key => 'doutorado',                 label => 'Doutorado',                     col => 'qt_doc_bas_esco_sup_pos_douto' },
);

our @VINCULO = (
  { key => 'concurso',     label => 'Concurso público',    col => 'qt_doc_bas_vinculo_concur' },
  { key => 'clt',          label => 'CLT',                 col => 'qt_doc_bas_vinculo_clt' },
  { key => 'contrato',     label => 'Contrato temporário', col => 'qt_doc_bas_vinculo_contra' },
  { key => 'terceirizado', label => 'Terceirizado',        col => 'qt_doc_bas_vinculo_terceir' },
);

our @DISCIPLINAS = (
  { key => 'lingua_port',     label => 'Língua Portuguesa',      col => 'qt_doc_bas_disc_lingua_port' },
  { key => 'matematica',      label => 'Matemática',             col => 'qt_doc_bas_disc_matematica' },
  { key => 'ciencias',        label => 'Ciências',               col => 'qt_doc_bas_disc_ciencias' },
  { key => 'fisica',          label => 'Física',                 col => 'qt_doc_bas_disc_fisica' },
  { key => 'quimica',         label => 'Química',                col => 'qt_doc_bas_disc_quimica' },
  { key => 'biologia',        label => 'Biologia',               col => 'qt_doc_bas_disc_biologia' },
  { key => 'historia',        label => 'História',               col => 'qt_doc_bas_disc_historia' },
  { key => 'geografia',       label => 'Geografia',              col => 'qt_doc_bas_disc_geografia' },
  { key => 'filosofia',       label => 'Filosofia',              col => 'qt_doc_bas_disc_filosofia' },
  { key => 'sociologia',      label => 'Sociologia',             col => 'qt_doc_bas_disc_sociologia' },
  { key => 'artes',           label => 'Artes',                  col => 'qt_doc_bas_disc_artes' },
  { key => 'educ_fisica',     label => 'Educação Física',        col => 'qt_doc_bas_disc_educ_fisica' },
  { key => 'lingua_ing',      label => 'Língua Inglesa',         col => 'qt_doc_bas_disc_lingua_ing' },
  { key => 'lingua_espa',     label => 'Língua Espanhola',       col => 'qt_doc_bas_disc_lingua_espa' },
  { key => 'ensino_religioso', label => 'Ensino Religioso',      col => 'qt_doc_bas_disc_ensino_religioso' },
  { key => 'info_computacao', label => 'Informática / Computação', col => 'qt_doc_bas_disc_info_computacao' },
  { key => 'pedagogicas',     label => 'Disciplinas pedagógicas', col => 'qt_doc_bas_disc_pedagogicas' },
  { key => 'libras',          label => 'Libras',                 col => 'qt_doc_bas_disc_libras' },
  { key => 'est_sociais',     label => 'Estudos Sociais',        col => 'qt_doc_bas_disc_est_sociais' },
  { key => 'est_sociais_soci', label => 'Estudos Sociais / Sociologia', col => 'qt_doc_bas_disc_est_sociais_soci' },
  { key => 'lingua_franc',    label => 'Língua Francesa',        col => 'qt_doc_bas_disc_lingua_franc' },
  { key => 'lingua_indig',    label => 'Língua Indígena',        col => 'qt_doc_bas_disc_lingua_indig' },
  { key => 'lingua_outra',    label => 'Outra Língua',           col => 'qt_doc_bas_disc_lingua_outra' },
  { key => 'port_seg_lingua', label => 'Português — 2ª Língua',  col => 'qt_doc_bas_disc_port_seg_lingua' },
  { key => 'profissiona',     label => 'Disciplinas profissionalizantes', col => 'qt_doc_bas_disc_profissiona' },
  { key => 'projeto_de_vida', label => 'Projeto de Vida',        col => 'qt_doc_bas_disc_projeto_de_vida' },
  { key => 'estagio_super',   label => 'Estágio supervisionado', col => 'qt_doc_bas_disc_estagio_super' },
  { key => 'outras',          label => 'Outras disciplinas',     col => 'qt_doc_bas_disc_outras' },
);

our @INFRA_BASICA = (
  { key => 'agua_potavel',    label => 'Água potável',            col => 'in_agua_potavel' },
  { key => 'energia',         label => 'Energia da rede pública', col => 'in_energia_rede_publica' },
  { key => 'esgoto',          label => 'Esgoto da rede pública',  col => 'in_esgoto_rede_publica' },
  { key => 'fossa_septica',   label => 'Fossa séptica',           col => 'in_esgoto_fossa_septica' },
  { key => 'coleta_lixo',     label => 'Coleta de lixo',          col => 'in_lixo_servico_coleta' },
  { key => 'banheiro',        label => 'Banheiro',                col => 'in_banheiro' },
  { key => 'cozinha',         label => 'Cozinha',                 col => 'in_cozinha' },
  { key => 'refeitorio',      label => 'Refeitório',              col => 'in_refeitorio' },
);

our @ESPACOS = (
  { key => 'biblioteca',              label => 'Biblioteca',              col => 'in_biblioteca' },
  { key => 'sala_leitura',            label => 'Sala de leitura',         col => 'in_biblioteca_sala_leitura' },
  { key => 'laboratorio_ciencias',    label => 'Laboratório de ciências', col => 'in_laboratorio_ciencias' },
  { key => 'laboratorio_informatica', label => 'Laboratório de informática', col => 'in_laboratorio_informatica' },
  { key => 'quadra_esportes',         label => 'Quadra de esportes',      col => 'in_quadra_esportes' },
  { key => 'patio_coberto',           label => 'Pátio coberto',           col => 'in_patio_coberto' },
  { key => 'patio_descoberto',        label => 'Pátio descoberto',        col => 'in_patio_descoberto' },
  { key => 'parque_infantil',         label => 'Parque infantil',         col => 'in_parque_infantil' },
  { key => 'auditorio',               label => 'Auditório',               col => 'in_auditorio' },
  { key => 'sala_professor',          label => 'Sala dos professores',    col => 'in_sala_professor' },
  { key => 'sala_diretoria',          label => 'Sala da direção',         col => 'in_sala_diretoria' },
  { key => 'secretaria',              label => 'Secretaria',              col => 'in_secretaria' },
  { key => 'area_verde',              label => 'Área verde',              col => 'in_area_verde' },
);

our @EQUIPAMENTOS = (
  { key => 'computador',        label => 'Computador',             col => 'in_computador' },
  { key => 'parabolica',        label => 'Antena parabólica',      col => 'in_equip_parabolica' },
  { key => 'copiadora',         label => 'Copiadora',              col => 'in_equip_copiadora' },
  { key => 'impressora',        label => 'Impressora',             col => 'in_equip_impressora' },
  { key => 'impressora_mult',   label => 'Impressora multifuncional', col => 'in_equip_impressora_mult' },
  { key => 'scanner',           label => 'Scanner',                col => 'in_equip_scanner' },
  { key => 'dvd',               label => 'Aparelho de DVD',        col => 'in_equip_dvd' },
  { key => 'som',               label => 'Aparelho de som',        col => 'in_equip_som' },
  { key => 'tv',                label => 'Televisão',              col => 'in_equip_tv' },
  { key => 'lousa_digital',     label => 'Lousa digital',          col => 'in_equip_lousa_digital' },
  { key => 'multimidia',        label => 'Projetor multimídia',    col => 'in_equip_multimidia' },
);

our @DISPOSITIVOS = (
  { key => 'desktop_aluno',  label => 'Computadores (aluno)',  in => 'in_desktop_aluno',        qty => 'qt_desktop_aluno' },
  { key => 'notebook_aluno', label => 'Notebooks (aluno)',     in => 'in_comp_portatil_aluno',  qty => 'qt_comp_portatil_aluno' },
  { key => 'tablet_aluno',   label => 'Tablets (aluno)',       in => 'in_tablet_aluno',         qty => 'qt_tablet_aluno' },
);

our @CONECTIVIDADE = (
  { key => 'internet',              label => 'Internet',                     col => 'in_internet' },
  { key => 'internet_alunos',       label => 'Internet para alunos',         col => 'in_internet_alunos' },
  { key => 'internet_administrativo', label => 'Internet administrativa',    col => 'in_internet_administrativo' },
  { key => 'internet_aprendizagem', label => 'Internet de aprendizagem',     col => 'in_internet_aprendizagem' },
  { key => 'internet_comunidade',   label => 'Internet para a comunidade',   col => 'in_internet_comunidade' },
  { key => 'banda_larga',           label => 'Banda larga',                  col => 'in_banda_larga' },
  { key => 'acesso_computador',     label => 'Acesso à internet por computador', col => 'in_acesso_internet_computador' },
  { key => 'dispositivos_pessoais', label => 'Internet em dispositivos pessoais', col => 'in_aces_internet_disp_pessoais' },
);

our @ACESSIBILIDADE = (
  { key => 'rampas',       label => 'Rampas',                    col => 'in_acessibilidade_rampas' },
  { key => 'corrimao',     label => 'Corrimão',                  col => 'in_acessibilidade_corrimao' },
  { key => 'elevador',     label => 'Elevador',                  col => 'in_acessibilidade_elevador' },
  { key => 'pisos_tateis', label => 'Pisos táteis',              col => 'in_acessibilidade_pisos_tateis' },
  { key => 'vao_livre',    label => 'Vão livre',                 col => 'in_acessibilidade_vao_livre' },
  { key => 'sinal_sonoro', label => 'Sinalização sonora',        col => 'in_acessibilidade_sinal_sonoro' },
  { key => 'sinal_tatil',  label => 'Sinalização tátil',         col => 'in_acessibilidade_sinal_tatil' },
  { key => 'sinal_visual', label => 'Sinalização visual',        col => 'in_acessibilidade_sinal_visual' },
  { key => 'sinalizacao',  label => 'Sinalização (geral)',       col => 'in_acessibilidade_sinalizacao' },
  { key => 'banheiro_pne', label => 'Banheiro acessível',        col => 'in_banheiro_pne' },
);

# --- Consultas ------------------------------------------------------------

sub overview($self, $params = {}) {
  my $inep = $params->{cod_inep} or return;
  my $ano  = $params->{ano} // $DEFAULT_YEAR;

  my $mat   = $self->_matriculas($inep, $ano) // {};
  my $doc   = $self->_docentes($inep, $ano)   // {};
  my $censo = $self->_censo($inep, $ano);

  # Escola inexistente no Censo: sem nenhum registro.
  return unless $censo || %$mat;

  my $total = $mat->{qt_mat_bas} // 0;

  my @etapas      = $self->_num_items($mat, \@ETAPAS);
  my @turno       = $self->_num_items($mat, \@TURNO);
  my @faixas      = $self->_num_items($mat, \@FAIXAS);
  my @formacao    = $self->_num_items($doc, \@FORMACAO);
  my @vinculo     = $self->_num_items($doc, \@VINCULO);
  my @disciplinas = $self->_num_items($doc, \@DISCIPLINAS, nonzero => 1, sort => 1);
  my @modalidades = $self->_modalidades($mat);
  my $salas       = $censo->{qt_salas_utilizadas} // 0;
  my $etapas_ofertadas = grep { $_->{value} > 0 } @etapas;
  my $mod_ofertadas    = grep { $_->{value} > 0 } @modalidades;

  return {
    escola => {
      id_escola   => $inep,
      nome        => $censo->{no_entidade},
      municipio   => $censo->{no_municipio},
      uf          => $censo->{sg_uf},
      cod_municipio => $censo->{co_municipio} + 0,
      rede        => $REDE{ $censo->{tp_dependencia} // 0 } // 'Não informada',
      localizacao => $LOCALIZACAO{ $censo->{tp_localizacao} // 0 },
      ano_censo   => $ano + 0,
    },
    resumo => {
      matriculas         => $total,
      docentes           => $doc->{qt_doc_bas} // 0,
      salas_utilizadas   => $salas,
      alunos_por_sala    => $self->_ratio($total, $salas),
      salas_climatizadas => $censo->{qt_salas_utiliza_climatizadas} // 0,
      salas_acessiveis   => $censo->{qt_salas_utilizadas_acessiveis} // 0,
      regime_integral    => $mat->{qt_mat_bas_int} // 0,
      educacao_especial  => $mat->{qt_mat_esp} // 0,
      etapas_ofertadas   => $etapas_ofertadas,
      modalidades_ofertadas => $mod_ofertadas,
    },
    matriculas => {
      total           => $total,
      por_etapa       => \@etapas,
      por_turno       => \@turno,
      por_modalidade  => \@modalidades,
      por_faixa_etaria => \@faixas,
      inclusao => {
        educacao_especial    => $mat->{qt_mat_esp} // 0,
        classes_comuns       => $mat->{qt_mat_esp_cc} // 0,
        classes_exclusivas   => $mat->{qt_mat_esp_ce} // 0,
      },
    },
    turmas => {
      salas_utilizadas   => $salas,
      salas_dentro       => $censo->{qt_salas_utilizadas_dentro} // 0,
      salas_fora         => $censo->{qt_salas_utilizadas_fora} // 0,
      salas_climatizadas => $censo->{qt_salas_utiliza_climatizadas} // 0,
      salas_acessiveis   => $censo->{qt_salas_utilizadas_acessiveis} // 0,
      salas_leitura      => $censo->{qt_salas_leitura} // 0,
      alunos_por_sala    => $self->_ratio($total, $salas),
      nota => 'O Censo Escolar agregado não informa o número de turmas; '
        . 'usamos as salas de aula utilizadas como referência.',
    },
    docentes => {
      total           => $doc->{qt_doc_bas} // 0,
      por_formacao    => \@formacao,
      por_vinculo     => \@vinculo,
      por_disciplina  => \@disciplinas,
      nota_formacao => 'Um docente pode aparecer em mais de um nível de formação; '
        . 'os valores não somam necessariamente o total.',
    },
    infraestrutura => {
      basica  => [ $self->_bool_items($censo, \@INFRA_BASICA) ],
      espacos => [ $self->_bool_items($censo, \@ESPACOS) ],
    },
    equipamentos => {
      itens           => [ $self->_bool_items($censo, \@EQUIPAMENTOS) ],
      dispositivos    => [ $self->_device_items($censo, \@DISPOSITIVOS) ],
      conectividade   => [ $self->_bool_items($censo, \@CONECTIVIDADE) ],
      sem_equipamentos => ($censo->{in_equip_nenhum} // 0) ? 1 : 0,
    },
    acessibilidade => [ $self->_bool_items($censo, \@ACESSIBILIDADE) ],
  };
}

sub _matriculas($self, $inep, $ano) {
  $self->schema->resultset('CensoMatriculas')
    ->search_rs({ co_entidade => $inep, nu_ano_censo => $ano })
    ->as_hash->first;
}

sub _docentes($self, $inep, $ano) {
  $self->schema->resultset('CensoDocentes')
    ->search_rs({ co_entidade => $inep, nu_ano_censo => $ano })
    ->as_hash->first;
}

sub _censo($self, $inep, $ano) {
  my @bool_cols = map { $_->{col} } @INFRA_BASICA, @ESPACOS, @EQUIPAMENTOS,
    @CONECTIVIDADE, @ACESSIBILIDADE;
  my @device_cols = map { ($_->{in}, $_->{qty}) } @DISPOSITIVOS;

  my @cols = (
    qw(co_entidade nu_ano_censo no_entidade no_municipio sg_uf co_municipio
       tp_dependencia tp_localizacao
       qt_salas_utilizadas qt_salas_utilizadas_dentro qt_salas_utilizadas_fora
       qt_salas_utiliza_climatizadas qt_salas_utilizadas_acessiveis
       qt_salas_leitura in_equip_nenhum),
    @bool_cols,
    @device_cols,
  );

  $self->schema->resultset('CensoEscolas')
    ->search_rs({ co_entidade => $inep, nu_ano_censo => $ano })
    ->columns(\@cols)
    ->as_hash->first;
}

# --- Construtores ---------------------------------------------------------

sub _num_items($self, $row, $spec, %opts) {
  my @items = map {
    +{
      key   => $_->{key},
      label => $_->{label},
      value => $row->{ $_->{col} } // 0,
    }
  } @$spec;

  @items = grep { $_->{value} > 0 } @items if $opts{nonzero};
  @items = sort { $b->{value} <=> $a->{value} } @items if $opts{sort};

  return @items;
}

sub _bool_items($self, $row, $spec) {
  return map {
    +{
      key     => $_->{key},
      label   => $_->{label},
      present => ($row->{ $_->{col} } // 0) ? 1 : 0,
    }
  } @$spec;
}

sub _device_items($self, $row, $spec) {
  return map {
    +{
      key     => $_->{key},
      label   => $_->{label},
      present => ($row->{ $_->{in} } // 0) ? 1 : 0,
      qtd     => $row->{ $_->{qty} } // 0,
    }
  } @$spec;
}

sub _modalidades($self, $mat) {
  my $total   = $mat->{qt_mat_bas} // 0;
  my $esp     = $mat->{qt_mat_esp} // 0;
  my $eja     = $mat->{qt_mat_eja} // 0;
  my $prof    = $mat->{qt_mat_prof} // 0;
  my $ead     = $mat->{qt_mat_bas_ead} // 0;
  my $regular = $total - $esp - $eja - $prof;
  $regular = 0 if $regular < 0;

  return (
    { key => 'regular',           label => 'Ensino regular',        value => $regular },
    { key => 'eja',               label => 'EJA',                   value => $eja },
    { key => 'profissionalizante', label => 'Educação profissional', value => $prof },
    { key => 'especial',          label => 'Educação especial',     value => $esp },
    { key => 'ead',               label => 'Ensino a distância (EAD)', value => $ead },
  );
}

sub _ratio($self, $num, $den) {
  return undef unless $den;
  return sprintf('%.1f', $num / $den) + 0;
}

1;
