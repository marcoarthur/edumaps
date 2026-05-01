package EduMaps::Schema::ResultSet::CensoEscolas;

use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;
use List::Util qw(reduce);

has _types => sub {
  state $types = { 
    administration => [
      qw/
        co_orgao_regional dt_ano_letivo_inicio dt_ano_letivo_termino
        in_vinculo_secretaria_educacao in_vinculo_seguranca_publica
        in_vinculo_secretaria_saude in_vinculo_outro_orgao in_poder_publico_parceria
        tp_poder_publico_parceria in_mant_escola_privada nu_cnpj_escola_privada
        nu_cnpj_mantenedora tp_regulamentacao tp_responsavel_regulamentacao
        co_escola_sede_vinculada co_ies_ofertante
      /
    ],
    infrastructure_building => [
      qw/
        IN_LOCAL_FUNC_PREDIO_ESCOLAR
        TP_OCUPACAO_PREDIO_ESCOLAR
        IN_LOCAL_FUNC_SOCIOEDUCATIVO
        IN_LOCAL_FUNC_UNID_PRISIONAL
        IN_LOCAL_FUNC_PRISIONAL_SOCIO
        IN_LOCAL_FUNC_GALPAO
        TP_OCUPACAO_GALPAO
        IN_LOCAL_FUNC_SALAS_OUTRA_ESC
        IN_LOCAL_FUNC_OUTROS
        IN_PREDIO_COMPARTILHADO
      /
    ],
    infrastructure_water => [
      qw/
        IN_AGUA_POTAVEL
        IN_AGUA_REDE_PUBLICA
        IN_AGUA_POCO_ARTESIANO
        IN_AGUA_CACIMBA
        IN_AGUA_FONTE_RIO
        IN_AGUA_INEXISTENTE
        IN_AGUA_CARRO_PIPA
      /
    ],
    infrastructure_trash => [
      qw/
        IN_ESGOTO_REDE_PUBLICA
        IN_ESGOTO_FOSSA_SEPTICA
        IN_ESGOTO_FOSSA_COMUM
        IN_ESGOTO_FOSSA
        IN_ESGOTO_INEXISTENTE
        IN_LIXO_SERVICO_COLETA
        IN_LIXO_QUEIMA
        IN_LIXO_ENTERRA
        IN_LIXO_DESTINO_FINAL_PUBLICO
        IN_LIXO_DESCARTA_OUTRA_AREA
        IN_TRATAMENTO_LIXO_SEPARACAO
        IN_TRATAMENTO_LIXO_REUTILIZA
        IN_TRATAMENTO_LIXO_RECICLAGEM
        IN_TRATAMENTO_LIXO_INEXISTENTE
      /
    ],
    infrastructure_energy => [
      qw/
        IN_ENERGIA_REDE_PUBLICA
        IN_ENERGIA_GERADOR_FOSSIL
        IN_ENERGIA_RENOVAVEL
        IN_ENERGIA_INEXISTENTE
      /
    ],
    infrastructure_rooms => [
      qw/
        IN_ALMOXARIFADO
        IN_AREA_VERDE
        IN_AREA_PLANTIO
        IN_AUDITORIO
        IN_BANHEIRO
        IN_BANHEIRO_EI
        IN_BANHEIRO_PNE
        IN_BANHEIRO_FUNCIONARIOS
        IN_BANHEIRO_CHUVEIRO
        IN_BIBLIOTECA
        IN_BIBLIOTECA_SALA_LEITURA
        IN_COZINHA
        IN_DESPENSA
        IN_DORMITORIO_ALUNO
        IN_DORMITORIO_PROFESSOR
        IN_LABORATORIO_CIENCIAS
        IN_LABORATORIO_INFORMATICA
        IN_LABORATORIO_EDUC_PROF
        IN_PATIO_COBERTO
        IN_PATIO_DESCOBERTO
        IN_PARQUE_INFANTIL
        IN_PISCINA
        IN_QUADRA_ESPORTES
        IN_QUADRA_ESPORTES_COBERTA
        IN_QUADRA_ESPORTES_DESCOBERTA
        IN_REFEITORIO
        IN_SALA_ATELIE_ARTES
        IN_SALA_MUSICA_CORAL
        IN_SALA_ESTUDIO_DANCA
        IN_SALA_MULTIUSO
        IN_SALA_ESTUDIO_GRAVACAO
        IN_SALA_OFICINAS_EDUC_PROF
        IN_SALA_DIRETORIA
        IN_SALA_LEITURA
        IN_SALA_PROFESSOR
        IN_SALA_REPOUSO_ALUNO
        IN_SECRETARIA
        IN_SALA_ATENDIMENTO_ESPECIAL
        IN_TERREIRAO
        IN_VIVEIRO
        IN_DEPENDENCIAS_OUTRAS
      /
    ],
    infrastructure_accessibility => [
      qw/
        IN_ACESSIBILIDADE_CORRIMAO
        IN_ACESSIBILIDADE_ELEVADOR
        IN_ACESSIBILIDADE_PISOS_TATEIS
        IN_ACESSIBILIDADE_VAO_LIVRE
        IN_ACESSIBILIDADE_RAMPAS
        IN_ACESSIBILIDADE_SINAL_SONORO
        IN_ACESSIBILIDADE_SINAL_TATIL
        IN_ACESSIBILIDADE_SINAL_VISUAL
        IN_ACESSIBILIDADE_INEXISTENTE
        IN_ACESSIBILIDADE_SINALIZACAO
      /
    ],
    qty_rooms => [
      qw/
        QT_SALAS_UTILIZADAS_DENTRO
        QT_SALAS_UTILIZADAS_FORA
        QT_SALAS_UTILIZADAS
        QT_SALAS_UTILIZA_CLIMATIZADAS
        QT_SALAS_UTILIZADAS_ACESSIVEIS
        QT_SALAS_LEITURA
      /
    ],
    infrastructure_tech_equip => [
      qw/
        IN_EQUIP_PARABOLICA
        IN_COMPUTADOR
        IN_EQUIP_COPIADORA
        IN_EQUIP_IMPRESSORA
        IN_EQUIP_IMPRESSORA_MULT
        IN_EQUIP_SCANNER
        IN_EQUIP_NENHUM
        IN_EQUIP_DVD
        QT_EQUIP_DVD
        IN_EQUIP_SOM
        QT_EQUIP_SOM
        IN_EQUIP_TV
        QT_EQUIP_TV
        IN_EQUIP_LOUSA_DIGITAL
        QT_EQUIP_LOUSA_DIGITAL
        IN_EQUIP_MULTIMIDIA
        QT_EQUIP_MULTIMIDIA
      /
    ],
    infrastructure_tablets => [
      qw/
        IN_DESKTOP_ALUNO
        QT_DESKTOP_ALUNO
        IN_COMP_PORTATIL_ALUNO
        QT_COMP_PORTATIL_ALUNO
        IN_TABLET_ALUNO
        QT_TABLET_ALUNO
      /
    ],
    infrastructure_net => [
      qw/
        IN_INTERNET
        IN_INTERNET_ALUNOS
        IN_INTERNET_ADMINISTRATIVO
        IN_INTERNET_APRENDIZAGEM
        IN_INTERNET_COMUNIDADE
        IN_ACESSO_INTERNET_COMPUTADOR
        IN_ACES_INTERNET_DISP_PESSOAIS
        TP_REDE_LOCAL
        IN_BANDA_LARGA
      /
    ],
    infrastructure_material => [
      qw/
        IN_MATERIAL_PED_MULTIMIDIA
        IN_MATERIAL_PED_INFANTIL
        IN_MATERIAL_PED_CIENTIFICO
        IN_MATERIAL_PED_DIFUSAO
        IN_MATERIAL_PED_MUSICAL
        IN_MATERIAL_PED_JOGOS
        IN_MATERIAL_PED_ARTISTICAS
        IN_MATERIAL_PED_PROFISSIONAL
        IN_MATERIAL_PED_DESPORTIVA
        IN_MATERIAL_PED_INDIGENA
        IN_MATERIAL_PED_ETNICO
        IN_MATERIAL_PED_CAMPO
        IN_MATERIAL_PED_BIL_SURDOS
        IN_MATERIAL_PED_AGRICOLA
        IN_MATERIAL_PED_QUILOMBOLA
        IN_MATERIAL_PED_EDU_ESP
        IN_MATERIAL_PED_NENHUM
      /
    ],
    modality_regular => [
      qw/
        IN_COMUM_CRECHE
        IN_COMUM_PRE
        IN_COMUM_FUND_AI
        IN_COMUM_FUND_AF
        IN_COMUM_MEDIO_MEDIO
        IN_COMUM_MEDIO_INTEGRADO
        IN_COMUM_MEDIO_FIC
        IN_COMUM_MEDIO_NORMAL
      /
    ],
    modality_exclusive => [
      qw/
        IN_ESP_EXCLUSIVA_CRECHE
        IN_ESP_EXCLUSIVA_PRE
        IN_ESP_EXCLUSIVA_FUND_AI
        IN_ESP_EXCLUSIVA_FUND_AF
        IN_ESP_EXCLUSIVA_MEDIO_MEDIO
      /
    ],
  };
};

sub columns_for($self, $params) {
  my $type = $params->{type};
  my $cols = $self->_types->{$type};
  unless ($cols) {
    warn "Not found columns for $type";
    return $self;
  }
  if (my $includes = $params->{include}) {
    $cols = [@$cols, @$includes];
  };

  return $self->search_rs(undef, {columns => $cols});
}

# score to define internet level
sub with_internet_score($self) {
  my $weights = {
    IN_INTERNET => 3,
    IN_BANDA_LARGA => 3,
    IN_LABORATORIO_INFORMATICA => 3,
    IN_INTERNET_APRENDIZAGEM => 2,
    IN_INTERNET_COMUNIDADE => 2,
    IN_ACESSO_INTERNET_COMPUTADOR => 1,
    IN_ACES_INTERNET_DISP_PESSOAIS => 1,
    IN_EQUIP_LOUSA_DIGITAL => 1,
  };

  $self->_compute_score(internet_score => $weights);
}

# score to define accessibility level
sub with_accessibility_score($self) {
  my $weights = {
    IN_ACESSIBILIDADE_RAMPAS => 3,
    IN_BANHEIRO_PNE => 3,
    IN_ACESSIBILIDADE_ELEVADOR => 2,
    IN_ACESSIBILIDADE_PISOS_TATEIS => 2,
    IN_ACESSIBILIDADE_SINAL_SONORO => 1,
  };

  $self->_compute_score(accessibility_score => $weights);
}

sub with_support_staff_score($self) {
  my $conditions = { 
    'qt_prof_psicologo > 0' => 3,
    'qt_prof_assist_social > 0' => 3,
    'qt_prof_nutricionista > 0' => 2,
    'qt_prof_bibliotecario > 0' => 2,
    'qt_prof_coordenador > 1' => 1,
  };

  $self->_compute_score(support_staff_score => $conditions);
}

# TODO: infrastructure score
sub with_infrastructure_score($self) {
  my $weights = {
    IN_BIBLIOTECA => 2,
    IN_LABORATORIO_CIENCIAS => 2,
    IN_QUADRA_ESPORTES => 2,
    IN_REFEITORIO => 2,
    IN_COZINHA => 1,
    IN_BANHEIRO => 1,
    IN_AGUA_POTAVEL => 3,
    IN_ENERGIA_REDE_PUBLICA => 2,
    'QT_SALAS_UTILIZADAS > 10' => 1,
    'QT_SALAS_UTILIZA_CLIMATIZADAS > 5' => 2,
  };

  $self->_compute_score( infrastructure_score => $weights );
}

sub with_all_scores($self) {
  $self->with_support_staff_score
  ->with_internet_score
  ->with_accessibility_score
  ->with_infrastructure_score
  ->order_by(
    { -desc => [qw(internet_score accessibility_score support_staff_score infrastructure_score)] }
  );
}

#TODO:
sub with_critical_infra_highlight($self) {
  ...;
};

#TODO:
sub with_vulnerability_score($self) {
  ...;
}

#TODO
sub with_highlight_badges($self) {
}

#TODO
sub with_extra_activities_score($self) {
}

sub _compute_score($self, $name, $weights) {
  # USE CASE to protect from NULLs or any Noise in data
  my $case = sub($col, $weight) {
    my $case_expr;
    # column is of form: a condition expression OR a 1/0 (yes/no) boolean
    if ( $col =~ /[>=<]/ ) {
      $case_expr = "CASE WHEN $col THEN 1 ELSE 0 END";
    } else {
      $case_expr = "CASE WHEN $col = 1 THEN 1 ELSE 0 END";
    }
    return sprintf ("%d * COALESCE(%s,0)", $weight, $case_expr);
  };

  my $expr = join('+', map { $case->($_, $weights->{$_}) } keys %$weights);
  my $sum  = reduce {$a + $b} values %$weights;
  $self->add_derived(
    $name => "ROUND(($expr)::numeric/$sum, 2)",
  );
}

1;
