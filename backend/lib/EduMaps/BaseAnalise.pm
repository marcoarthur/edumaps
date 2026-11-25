package EduMaps::BaseAnalise;
use Mojo::Base -strict, -signatures;
use utf8;
use Carp qw(croak);
use Mojo::JSON ();
use EduMaps::Fontes;
use EduMaps::Model::Rank::School ();
use EduMaps::Porte;
use EduMaps::Regiao;

# ============================================================================
# BASE DE ANÁLISE (#439, RV-02)
# ============================================================================
#
# Exportação pública de uma base com vários indicadores por escola, para a
# pesquisa (P4) e o jornalismo de dados (P6): uma linha por escola em
# funcionamento, num recorte de uma UF (decisão do developer, 2026-11-16: a
# exportação é pública e limitada a uma UF; o Brasil inteiro, as séries e o
# acesso programático ficam para a assinatura de dados/API).
#
# Lê as tabelas de origem, e não clean.school_indicators: aquela tabela é
# esvaziada e refeita a cada agrupamento (TRUNCATE no job) e o IDEB dela é a
# média entre etapas do ano do último agrupamento.
#
# Cada coluna tem descrição e fonte, para o dicionário que acompanha o CSV.

my %REDE_SQL = (
  municipal => [3], estadual => [2], federal => [1], privada => [4], publica => [1, 2, 3],
);
our @REDES = (
  { id => 'publica',   label => 'Pública (federal, estadual e municipal)' },
  { id => 'municipal', label => 'Municipal' },
  { id => 'estadual',  label => 'Estadual' },
  { id => 'federal',   label => 'Federal' },
  { id => 'privada',   label => 'Privada' },
);

our @UFS = qw(AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO);

# Etapas do IDEB/SAEB, com o sufixo das colunas.
my @ETAPAS = (
  [ai => 'fundamental_i',  'anos iniciais do fundamental'],
  [af => 'fundamental_ii', 'anos finais do fundamental'],
  [em => 'ensino_medio',   'ensino médio'],
);
my @MEDIDAS_IDEB = (
  [ideb            => 'ideb_observado',  'IDEB observado'],
  [nota_matematica => 'nota_matematica', 'Nota do SAEB em Matemática'],
  [nota_portugues  => 'nota_portugues',  'Nota do SAEB em Língua Portuguesa'],
  [nota_media      => 'nota_media',      'Nota média padronizada do SAEB (Matemática e Português)'],
  [aprovacao       => 'aprovacao_si_4',  'Indicador de rendimento (taxa de aprovação, em %)'],
);

# Infraestrutura: as 11 colunas do conjunto pronto do agrupamento e, ao lado
# de água, energia e esgoto, se a escola não tem o serviço (#452, VJ-01):
# "rede pública = 0" não quer dizer "sem" (pode ser poço, gerador, fossa).
my @INFRA = (
  [in_agua_potavel            => 'Tem água potável (1 = sim, 0 = não). 0 não quer dizer sem água: veja in_agua_inexistente'],
  [in_agua_inexistente        => 'Não tem abastecimento de água (1 = não tem, 0 = tem)'],
  [in_energia_rede_publica    => 'Energia da rede pública (1 = sim, 0 = não). 0 não quer dizer sem energia (pode ser gerador ou fonte renovável): veja in_energia_inexistente'],
  [in_energia_inexistente     => 'Não tem energia elétrica (1 = não tem, 0 = tem)'],
  [in_esgoto_rede_publica     => 'Esgoto na rede pública (1 = sim, 0 = não). 0 não quer dizer sem esgoto (pode ser fossa): veja in_esgoto_inexistente'],
  [in_esgoto_inexistente      => 'Não tem esgotamento sanitário (1 = não tem, 0 = tem)'],
  [in_lixo_servico_coleta     => 'Coleta de lixo pelo serviço público (1 = sim, 0 = não)'],
  [in_banheiro                => 'Tem banheiro (1 = sim, 0 = não)'],
  [in_biblioteca              => 'Tem biblioteca (1 = sim, 0 = não)'],
  [in_laboratorio_ciencias    => 'Tem laboratório de ciências (1 = sim, 0 = não)'],
  [in_laboratorio_informatica => 'Tem laboratório de informática (1 = sim, 0 = não)'],
  [in_quadra_esportes         => 'Tem quadra de esportes (1 = sim, 0 = não)'],
  [in_internet                => 'Tem internet (1 = sim, 0 = não)'],
  [in_acessibilidade_rampas   => 'Tem rampas de acessibilidade (1 = sim, 0 = não)'],
);

# Etapas oferecidas (#461): 1 = oferece, 0 = não; vazio quando o Censo não
# traz. O sufixo casa com o do IDEB (_ai, _af, _em). O ensino médio do SAEB
# inclui o integrado e o normal, por isso o GREATEST (que ignora NULL).
my @ETAPAS_OFERTA = (
  [oferece_creche       => 'e.in_comum_creche', 'Oferece creche (1 = sim, 0 = não). Censo: in_comum_creche'],
  [oferece_pre          => 'e.in_comum_pre', 'Oferece pré-escola (1 = sim, 0 = não). Censo: in_comum_pre'],
  [oferece_ai           => 'e.in_comum_fund_ai', 'Oferece os anos iniciais do fundamental (1 = sim, 0 = não). Casa com ideb_ai. Censo: in_comum_fund_ai'],
  [oferece_af           => 'e.in_comum_fund_af', 'Oferece os anos finais do fundamental (1 = sim, 0 = não). Casa com ideb_af. Censo: in_comum_fund_af'],
  [oferece_em           => 'GREATEST(e.in_comum_medio_medio, e.in_comum_medio_integrado, e.in_comum_medio_normal)',
                           'Oferece ensino médio, inclusive integrado e normal (1 = sim, 0 = não). Casa com ideb_em. Censo: in_comum_medio_medio, _integrado e _normal'],
  [oferece_eja          => 'e.in_eja', 'Oferece EJA (1 = sim, 0 = não). Censo: in_eja'],
  [oferece_profissional => 'e.in_profissionalizante', 'Oferece educação profissional (1 = sim, 0 = não, vazio quando o Censo não traz). Censo: in_profissionalizante'],
  [classe_especial_exclusiva => 'e.in_especial_exclusiva', 'Tem classe especial exclusiva (1 = sim, 0 = não). Censo: in_especial_exclusiva'],
);

# Docência: as mesmas fórmulas do agrupamento (Task::Clustering). A contagem
# é a do Censo Escolar, por escola: quem dá aula em mais de uma escola conta
# em cada uma (#444, BA-04).
# #465 (RY-01): os seis índices do EduMaps (clean.mv_escolas_scores), com o
# método do ranking (%METODO; sem ';', que o dicionário dos testes separa).
my @INDICES = qw(infraestrutura capacidade_atendimento capacitacao_docente
                 diversidade_discente capacidade_gestora sustentabilidade);
# #471 (RT-02): as partes do índice de diversidade discente, no fim do bloco
# (as colunas antigas não mudam de posição), com as expressões de
# clean.mv_escolas_scores (escolas_scores_cor_declarada). mt = censo_matriculas.
my $MAT  = 'mt.qt_mat_bas';
my $DECL = '(COALESCE(mt.qt_mat_bas_branca,0) + COALESCE(mt.qt_mat_bas_preta,0) + COALESCE(mt.qt_mat_bas_parda,0)'
         . ' + COALESCE(mt.qt_mat_bas_amarela,0) + COALESCE(mt.qt_mat_bas_indigena,0))::float8';
sub _sobre_mat ($num) { "CASE WHEN $MAT > 0 THEN LEAST(1, ($num)::float8 / $MAT) END" }
my $FORMULA_DIV = 'Índice = 10 × (0,35 × diversidade_racial + 0,25 × equilibrio_genero + 0,20 × prop_educacao_especial_cc + 0,20 × prop_eja), '
                . 'ou, com diversidade_racial vazia, 10 × (0,25 × equilibrio_genero + 0,20 × prop_educacao_especial_cc + 0,20 × prop_eja) ÷ 0,65';
# #473 (RS-02): as partes do índice de capacidade de atendimento, com as
# expressões de clean.mv_escolas_scores (escolas_scores_turnos).
my $TURNOS = 'GREATEST(1, (COALESCE(mt.qt_mat_bas_dm,0) > 0)::int + (COALESCE(mt.qt_mat_bas_dv,0) > 0)::int + (COALESCE(mt.qt_mat_bas_n,0) > 0)::int)';
my $FORMULA_ATEND = 'Índice = 10 × (0,40 × máximo(0, 1 − alunos_sala_turno ÷ 50) + 0,20 × etapas_regulares ÷ 7 + 0,20 × prop_tempo_integral + 0,20 × alimentacao), '
                  . 'com alunos_sala_turno vazio contando 0 na primeira parte e alimentacao vazia contando 0';
my @ATENDIMENTO = (
  ['alunos_sala_turno', "CASE WHEN $MAT > 0 AND e.qt_salas_utilizadas > 0 THEN ${MAT}::float8 / (e.qt_salas_utilizadas * $TURNOS) END",
   "Parte de 40% do índice de capacidade de atendimento: matrículas ÷ (salas utilizadas × turnos). Vazio: sem salas informadas (a parte conta 0) ou sem matrículas. $FORMULA_ATEND", 1],
  ['turnos', "CASE WHEN $MAT > 0 THEN $TURNOS END",
   'Turnos com matrícula na escola: matutino, vespertino e noturno (mínimo 1). Escola só de tempo integral conta 1', 1],
  ['etapas_regulares', '(COALESCE(e.in_comum_creche,0) + COALESCE(e.in_comum_pre,0) + COALESCE(e.in_comum_fund_ai,0) + COALESCE(e.in_comum_fund_af,0)'
     . ' + COALESCE(e.in_comum_medio_medio,0) + COALESCE(e.in_eja,0) + COALESCE(e.in_profissionalizante,0))',
   'Parte de 20% do índice de capacidade de atendimento: etapas oferecidas no ensino regular, de 7 (creche, pré-escola, anos iniciais, anos finais, ensino médio, EJA e educação profissional). Não é a soma das colunas oferece_*, que seguem outra definição do Censo', 1],
  ['prop_tempo_integral', "CASE WHEN $MAT > 0 THEN COALESCE(mt.qt_mat_bas_int,0)::float8 / $MAT END",
   'Parte de 20% do índice de capacidade de atendimento: matrículas em tempo integral ÷ matrículas', 1],
  ['alimentacao', 'e.in_alimentacao',
   'Parte de 20% do índice de capacidade de atendimento: oferece alimentação escolar (1 = sim, 0 = não). Vazio: sem resposta no Censo, que conta 0 no índice', 1],
);

# #475: as partes do índice de capacidade gestora, com as expressões de
# clean.mv_escolas_scores (escolas_scores_gestora). gs = censo_gestor.
my $GB = 'gs.qt_gest_bas';
my $FORMULA_GEST = 'Índice = 10 × (0,3 × gestores_formacao + 0,2 × prop_gestores_espec_gestao + 0,2 × mínimo(1, 200 ÷ alunos_por_gestor) '
                 . '+ 0,2 × mínimo(1, orgaos_colegiados ÷ 5) + 0,1 × prop_acesso_cargo_selecao) ÷ (soma dos pesos das partes presentes), '
                 . 'com alunos_por_gestor e prop_acesso_cargo_selecao vazios ficando de fora da soma e dos pesos';
my @GESTORA = (
  ['gestores_formacao', "CASE WHEN $GB > 0 THEN (LEAST(1, COALESCE(gs.qt_gest_bas_esco_sup_grad,0)::float8 / $GB)"
     . " + LEAST(1, (COALESCE(gs.qt_gest_bas_esco_sup_pos_espec,0) + COALESCE(gs.qt_gest_bas_esco_sup_pos_mestra,0)"
     . " + COALESCE(gs.qt_gest_bas_esco_sup_pos_douto,0))::float8 / $GB)) / 2 END",
   "Parte de 30% do índice de capacidade gestora: média entre a proporção de gestores com ensino superior e a com pós-graduação (especialização, mestrado ou doutorado), de 0 a 1. Vazio: sem gestores no Censo. $FORMULA_GEST", 1],
  ['prop_gestores_espec_gestao', "CASE WHEN $GB > 0 THEN LEAST(1, COALESCE(gs.qt_gest_bas_espec_gestao,0)::float8 / $GB) END",
   'Parte de 20% do índice de capacidade gestora: gestores com formação em gestão ÷ gestores', 1],
  ['alunos_por_gestor', "CASE WHEN $GB > 0 AND $MAT > 0 THEN ${MAT}::float8 / $GB END",
   'Parte de 20% do índice de capacidade gestora: matrículas ÷ gestores (a parte vale 10 com 200 ou menos). Vazio: sem matrículas, e a parte fica de fora do índice com o peso redistribuído, ou sem gestores', 1],
  ['orgaos_colegiados', '(COALESCE(e.in_orgao_ass_pais,0) + COALESCE(e.in_orgao_ass_pais_mestres,0) + COALESCE(e.in_orgao_conselho_escolar,0)'
     . ' + COALESCE(e.in_orgao_gremio_estudantil,0) + COALESCE(e.in_orgao_outros,0))',
   'Parte de 20% do índice de capacidade gestora: órgãos colegiados, de 5 (associação de pais, de pais e mestres, conselho escolar, grêmio e outros)', 1],
  ['prop_acesso_cargo_selecao', "CASE WHEN $GB > 0 AND e.tp_dependencia <> 4 THEN LEAST(1, (COALESCE(gs.qt_gest_bas_acesso_cargo_conca,0)"
     . " + COALESCE(gs.qt_gest_bas_acesso_cargo_eleic,0) + COALESCE(gs.qt_gest_bas_acesso_cargo_p_sel,0))::float8 / $GB) END",
   'Parte de 10% do índice de capacidade gestora: gestores que chegaram ao cargo por concurso, eleição ou processo seletivo ÷ gestores. Vazio: escola privada (o Censo não registra a escolha pela mantenedora, e a parte fica de fora do índice com o peso redistribuído) ou sem gestores', 1],
);

# #477 (RQ-02): as partes dos índices de infraestrutura e de
# sustentabilidade, com as expressões de clean.mv_escolas_scores (lidas da
# própria escola, e = censo_escolas). Como no índice, item sem resposta conta
# como ausente (COALESCE 0), então as partes não ficam vazias.
sub _itens (@c) { join(' + ', map { /^\(/ ? $_ : "COALESCE(e.$_,0)" } @c) }
sub _ou (@c) { '(CASE WHEN ' . join(' OR ', map { "COALESCE(e.$_,0) = 1" } @c) . ' THEN 1 ELSE 0 END)' }
my $FORMULA_INFRA = 'Índice = 10 × (infra_basico + infra_salas_equipamentos + infra_acessibilidade + infra_tecnologia) ÷ 4';
my $FORMULA_SUST  = 'Índice = 10 × (energia_renovavel + reciclagem_lixo + area_verde_plantio + educacao_ambiental) ÷ 4';
my $AUSENTE = 'Item sem resposta no Censo conta como ausente, como no índice';
my @INFRA_PARTES = (
  ['infra_basico', '(' . _itens(qw(in_agua_potavel in_energia_rede_publica), _ou(qw(in_esgoto_rede_publica in_esgoto_fossa_septica)),
                                qw(in_lixo_servico_coleta in_banheiro)) . ')::float8 / 5',
   "Parte de um quarto do índice de infraestrutura: água potável, energia da rede pública, esgoto da rede ou fossa séptica, coleta de lixo e banheiro, de 5 (0 a 1). $AUSENTE. $FORMULA_INFRA", 1],
  ['infra_salas_equipamentos', '(' . _itens(_ou(qw(in_biblioteca in_biblioteca_sala_leitura)), qw(in_laboratorio_ciencias in_laboratorio_informatica
                                in_quadra_esportes in_cozinha in_refeitorio in_sala_diretoria in_secretaria in_sala_professor)) . ')::float8 / 9',
   "Parte de um quarto do índice de infraestrutura: biblioteca ou sala de leitura, laboratórios de ciências e de informática, quadra, cozinha, refeitório e salas da diretoria, da secretaria e dos professores, de 9 (0 a 1). $AUSENTE", 1],
  ['infra_acessibilidade', '(' . _itens(qw(in_acessibilidade_rampas in_acessibilidade_corrimao in_acessibilidade_pisos_tateis
                                in_acessibilidade_sinalizacao in_banheiro_pne)) . ')::float8 / 5',
   "Parte de um quarto do índice de infraestrutura: rampas, corrimão, piso tátil, sinalização e banheiro adaptado, de 5 (0 a 1). $AUSENTE", 1],
  ['infra_tecnologia', '(' . _itens(qw(in_computador in_internet in_equip_lousa_digital in_equip_multimidia),
                                _ou(qw(in_equip_impressora in_equip_impressora_mult))) . ')::float8 / 5',
   "Parte de um quarto do índice de infraestrutura: computador, internet, lousa digital, multimídia e impressora (ou multifuncional), de 5 (0 a 1). $AUSENTE", 1],
);
my @SUSTENTABILIDADE = (
  ['energia_renovavel', _ou('in_energia_renovavel'),
   "Parte de um quarto do índice de sustentabilidade: energia renovável (1 = sim, 0 = não). $AUSENTE. $FORMULA_SUST", 1],
  ['reciclagem_lixo', _ou(qw(in_tratamento_lixo_reciclagem in_tratamento_lixo_reutiliza)),
   "Parte de um quarto do índice de sustentabilidade: reciclagem ou reaproveitamento do lixo (1 = sim, 0 = não). $AUSENTE", 1],
  ['area_verde_plantio', '(' . _ou('in_area_verde') . ' + ' . _ou('in_area_plantio') . ')::float8 / 2',
   "Parte de um quarto do índice de sustentabilidade: área verde e área de plantio, meio ponto cada (0, 0,5 ou 1). $AUSENTE", 1],
  ['educacao_ambiental', _ou(qw(in_educ_ambiental in_educ_amb_conteudo in_educ_amb_curricular in_educ_amb_eixo in_educ_amb_eventos in_educ_amb_projetos)),
   "Parte de um quarto do índice de sustentabilidade: educação ambiental em qualquer forma do Censo (disciplina, conteúdo, currículo, eixo, eventos ou projetos), 1 = sim, 0 = não. $AUSENTE", 1],
);

my @DIVERSIDADE = (
  ['diversidade_racial',
   "CASE WHEN $MAT > 0 AND $DECL > 0 AND $DECL >= 0.5 * $MAT THEN 1 - ("
     . join(' + ', map { "power(COALESCE(mt.qt_mat_bas_$_,0)::float8 / $DECL, 2)" } qw(branca preta parda amarela indigena))
     . ') END',
   "Parte de 35% do índice de diversidade discente: 1 menos a soma dos quadrados das proporções de branca, preta, parda, amarela e indígena, sobre as matrículas com cor declarada (0 a 1). Vazio: menos de metade das matrículas com cor declarada (o peso vai para as outras partes) ou escola sem matrículas. $FORMULA_DIV", 1],
  ['prop_cor_nao_declarada', "CASE WHEN $MAT > 0 THEN COALESCE(mt.qt_mat_bas_nd,0)::float8 / $MAT END",
   'Matrículas sem cor/raça declarada ÷ matrículas da educação básica. Com metade ou mais, diversidade_racial fica vazia', 1],
  ['equilibrio_genero', _sobre_mat('2 * LEAST(COALESCE(mt.qt_mat_bas_fem,0), COALESCE(mt.qt_mat_bas_masc,0))'),
   'Parte de 25% do índice de diversidade discente: 2 × o menor entre meninas e meninos ÷ matrículas (1 = metade de cada)', 1],
  ['prop_educacao_especial_cc', _sobre_mat('COALESCE(mt.qt_mat_esp_cc,0)'),
   'Parte de 20% do índice de diversidade discente: alunos da educação especial em classe comum ÷ matrículas, limitada a 1', 1],
  ['prop_eja', _sobre_mat('COALESCE(mt.qt_mat_eja,0)'),
   'Parte de 20% do índice de diversidade discente: matrículas na EJA ÷ matrículas, limitada a 1', 1],
);

# #467: o vazio também é a escola sem o registro de que o índice depende.
my %SEM_REGISTRO = (
  capacidade_atendimento => 'sem matrículas no Censo',
  capacitacao_docente    => 'sem docentes no Censo',
  diversidade_discente   => 'sem matrículas no Censo',
  capacidade_gestora     => 'sem gestores no Censo',
);
# #467 (RZ-02): na base não há a coluna "Infraestrutura básica" do ranking.
my $BASICA_NA_BASE = 'Para água, energia, esgoto e banheiro, use as colunas in_*_inexistente e in_banheiro do bloco Infraestrutura (a soma está na ajuda).';
sub _indices_colunas {
  no warnings 'once';
  my $met = \%EduMaps::Model::Rank::School::METODO;
  return [ ( map {
    my $d = $met->{$_} =~ s/;\s*/, /gr;
    $d =~ s/Para água, energia, esgoto e banheiro, use "Infraestrutura básica"\./$BASICA_NA_BASE/;
    # #469 (RW-02): os pesos são normativos.
    $d .= ' Os pesos são uma escolha do EduMaps, não estimados contra o IDEB: índice alto não quer dizer IDEB alto.';
    my $vazio = 'Vazio: '
      . ($SEM_REGISTRO{$_} ? "escola $SEM_REGISTRO{$_}, ou " : '')
      . 'índices ainda não recalculados depois de uma carga nova do Censo';
    ["indice_$_", "s.score_${_}::float8", "$d $vazio", 1]
  } @INDICES ), @DIVERSIDADE, @ATENDIMENTO, @GESTORA, @INFRA_PARTES, @SUSTENTABILIDADE ];
}
sub indices_versao ($class) { $EduMaps::Model::Rank::School::INDICES_VERSAO }

# #531: cobertura das coordenadas (Censo 2025, escolas em funcionamento).
my $SEM_COORD = 'Vazia quando o Censo não traz, o que é bem mais comum nas escolas privadas (cerca de 1 em cada 3 no Brasil) que nas municipais (16%) e estaduais (12%). Sem a coordenada, use o cep, o bairro e o endereco';
my $DENOM = 'docentes da escola (qt_docentes)';
# #533: a conta da taxa de atendimento da educação infantil (meta 1 do PNE).
my $TAXA_ATENDIMENTO = 'Taxa bruta de matrícula: some as matrículas da etapa nas escolas do município (bloco Matrículas) e divida por este número. Não é o indicador oficial da meta 1 do PNE (o percentual das crianças da idade que frequentam creche ou escola, de pesquisa domiciliar), e os números podem diferir. Pode passar de 100%, com crianças de outros municípios ou fora da idade, e o Censo Demográfico é anterior ao Censo Escolar';
# Proporção sobre qt_doc_bas limitada a 1; vazia sem docentes (#469).
sub _ate_um ($num) {
  "CASE WHEN d.qt_doc_bas > 0 THEN LEAST(1, ($num)::float8 / d.qt_doc_bas) END";
}
my @DOCENCIA = (
  [qt_docentes             => 'd.qt_doc_bas', 'Docentes da educação básica da escola. Quem dá aula em mais de uma escola conta em cada uma (contagem do Censo Escolar)'],
  [prop_licenciatura       => 'd.qt_doc_bas_esco_sup_grad_licen::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com licenciatura ÷ $DENOM"],
  [prop_mestrado           => 'd.qt_doc_bas_esco_sup_pos_mestra::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com mestrado ÷ $DENOM"],
  [prop_doutorado          => 'd.qt_doc_bas_esco_sup_pos_douto::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com doutorado ÷ $DENOM"],
  # #524 (QT-01): o Censo só pergunta o vínculo do docente na escola pública;
  # na privada a célula fica vazia (antes, 0).
  [prop_efetivos           => 'CASE WHEN e.tp_dependencia <> 4 THEN d.qt_doc_bas_vinculo_concur::float8 / NULLIF(d.qt_doc_bas, 0) END',
   "Docentes concursados (efetivos) ÷ $DENOM. Vazia nas escolas privadas: o Censo só pergunta o vínculo do docente na escola pública. Parte de 20% do índice de capacitação docente (na privada o peso vai para as outras partes)"],
  # #522 (QU-01): vem de qt_doc_bas_espec_nenhum, que o INEP descreve como
  # formação continuada de no mínimo 80 horas "Nenhum". Até 2026-11 a coluna
  # se chamava prop_sem_especializacao (dentro da plataforma o nome segue).
  [prop_sem_formacao_continuada => 'd.qt_doc_bas_espec_nenhum::float8 / NULLIF(d.qt_doc_bas, 0)',
   "Docentes sem formação continuada de no mínimo 80 horas ÷ $DENOM. Não é a pós-graduação (especialização, mestrado ou doutorado), que está em prop_pos_graduacao. Até 2026-11 a coluna se chamava prop_sem_especializacao"],
  # #469 (RW-01): as outras partes do índice de capacitação docente, com as
  # mesmas expressões de clean.mv_escolas_scores (escolas_scores_sem_registro),
  # inclusive o limite a 1. No fim do bloco, para não mudar a posição das
  # colunas antigas. O LEAST do Postgres ignora NULL (LEAST(1, NULL) = 1):
  # sem docentes, o CASE deixa a célula vazia.
  [prop_superior           => _ate_um('COALESCE(d.qt_doc_bas_esco_sup_grad,0)'),
   "Docentes com ensino superior completo ÷ $DENOM. Parte de 30% do índice de capacitação docente"],
  [prop_pos_graduacao      => _ate_um('COALESCE(d.qt_doc_bas_esco_sup_pos_espec,0) + COALESCE(d.qt_doc_bas_esco_sup_pos_mestra,0) + COALESCE(d.qt_doc_bas_esco_sup_pos_douto,0)'),
   "Docentes com pós-graduação (especialização, mestrado ou doutorado) ÷ $DENOM, limitada a 1 (quem tem mais de uma pós conta mais de uma vez no Censo). Parte de 30% do índice de capacitação docente"],
  [prop_formacao_continuada => _ate_um(join ' + ', map { "COALESCE(d.qt_doc_bas_espec_$_,0)" }
       qw(cre pre_escola anos_iniciais anos_finais ens_medio eja ed_especial bil_surdos ed_indigena campo
          ambiental dir_humanos div_sexual dir_adolesc afro gestao educ_tic outros)),
   "Formações continuadas dos docentes (soma dos cursos de formação continuada de no mínimo 80 horas do Censo) ÷ $DENOM, limitada a 1. Conta cursos, não pessoas: quem fez dois cursos conta duas vezes. Para a proporção de docentes com ao menos um curso, use 1 − prop_sem_formacao_continuada. Parte de 20% do índice de capacitação docente"],
  # #529 (QS-01): docentes por etapa, para o modelo por etapa separar ou
  # ponderar as escolas pela parte do quadro na etapa. No fim do bloco, para
  # não mudar a posição das colunas antigas. Vazias sem docentes.
  (map { my ($col, $censo, $etapa) = @$_;
         [$col => "CASE WHEN d.qt_doc_bas > 0 THEN COALESCE(d.$censo, 0) END",
          "Docentes que dão aula $etapa na escola. Quem dá aula em mais de uma etapa conta em cada uma, então a soma das etapas pode passar de qt_docentes. As proporções do bloco são sobre todos os docentes da escola, não só os desta etapa"] }
     [qt_docentes_infantil => 'qt_doc_inf',     'na educação infantil (creche e pré-escola)'],
     [qt_docentes_ai       => 'qt_doc_fund_ai', 'nos anos iniciais do fundamental'],
     [qt_docentes_af       => 'qt_doc_fund_af', 'nos anos finais do fundamental'],
     [qt_docentes_em       => 'qt_doc_med',     'no ensino médio']),
);

# #516 (QX-01): matrículas da escola (mm = censo_matriculas do mesmo Censo).
# O vazio é a escola sem linha de matrículas no Censo; 0 é 0.
my $MAT_VAZIO = 'Vazio: a escola não tem linha de matrículas no Censo Escolar (0 é 0 matrículas)';
my $MAT_NAO_SOMA = 'As etapas não somam o total da educação básica: a educação profissional repete matrículas do médio (médio integrado) e a educação especial atravessa as etapas. Para o total, use mat_basica';
our @MATRICULAS = (
  [mat_basica       => 'mm.qt_mat_bas',     "Matrículas na educação básica (total da escola, cada aluno uma vez). $MAT_VAZIO"],
  [mat_creche       => 'mm.qt_mat_inf_cre', "Matrículas na creche. $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_pre          => 'mm.qt_mat_inf_pre', "Matrículas na pré-escola. $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_ai           => 'mm.qt_mat_fund_ai', "Matrículas nos anos iniciais do ensino fundamental. $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_af           => 'mm.qt_mat_fund_af', "Matrículas nos anos finais do ensino fundamental. $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_medio        => 'mm.qt_mat_med',     "Matrículas no ensino médio (inclusive o integrado à educação profissional). $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_profissional => 'mm.qt_mat_prof',    "Matrículas na educação profissional (técnica e qualificação), inclusive as que também contam no médio. $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_eja          => 'mm.qt_mat_eja',     "Matrículas na educação de jovens e adultos (EJA). $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_especial     => 'mm.qt_mat_esp',     "Matrículas de alunos da educação especial, em classes comuns e exclusivas, em todas as etapas. $MAT_NAO_SOMA. $MAT_VAZIO"],
  [mat_integral     => 'mm.qt_mat_bas_int', "Matrículas em tempo integral (7 horas diárias ou mais) na educação básica. $MAT_VAZIO"],
);

# #471 (RT-03): o INSE só existe para escolas com alunos no SAEB.
my $INSE_VAZIO = 'Vazio: a escola não teve alunos avaliados no SAEB daquela edição. As privadas nunca têm INSE, e as creches e pré-escolas quase nunca';

# Cada bloco: colunas [nome, expressão SQL, descrição, numérica?] e a fonte.
my $SIOPE_VAZIO = 'Vazio: escola fora da rede municipal, município sem folha carregada nesse ano, ou município em que o SIOPE só traz o total da Secretaria, sem separar as escolas (veja a ajuda e a lista de municípios em Fontes e metodologia)';
# #512 (QZ-02): o quarto motivo do salário do magistério vazio.
my $SEM_MAGISTERIO = 'Com prof_magisterio = 0, a escola tem folha, mas ninguém no magistério: é o caso de creches em que a folha só traz auxiliares e assistentes educacionais (veja aux_educacional)';
my $MAGISTERIO = 'Profissionais do magistério';
# #553: o que vale para as três colunas da folha por fonte.
my $FONTE_SOMA = 'As três partes (gasto_fundeb_70_ano, gasto_fundeb_30_ano e gasto_outras_fontes_ano) somam o gasto_pessoal_ano, em reais inteiros, com diferença de arredondamento de até 2 reais. Não é a verificação do mínimo de 70% exigido em lei: essa conta usa a receita do Fundeb do município, que não está na base.';
our $AUX_EDUCACIONAL = 'Auxiliar/Assistente Educacional';

# #557 (QT-01 da P2): o mês com a folha pela metade. Comparado com o próprio
# ano do município: tem menos categorias de profissionais que o habitual (a
# moda do ano) ou menos da metade dos registros do mês mediano. Pelo número
# de registros e de categorias, não pelo valor: dezembro (13º) e janeiro
# (mais baixo, antes dos contratos do ano) não viram alarme. A causa não se
# sabe (declaração do município ao SIOPE ou carga): só se marca.
our @MESES = qw(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro);
# O número do mês (1 a 12) a partir do texto ("Março" também em latin1).
sub _mes_num ($col) {
  return "CASE left($col, 3) " . join(' ', map {
    sprintf "WHEN '%s' THEN %d", ucfirst(substr($MESES[$_ - 1] =~ s/ç/c/r, 0, 3)), $_
  } 1 .. 12) . ' END';
}
my $MES_NUM = _mes_num('mes');
my $SQL_MESES = <<~"SQL";
  WITH m AS (
    SELECT cod_municipio::text AS cod6, ano::int AS ano, $MES_NUM AS mes,
           count(*)::int AS registros, count(DISTINCT categoria)::int AS categorias
      FROM clean.remuneracao_municipal
     WHERE (?::text IS NULL OR cod_municipio::text = ?)
     GROUP BY 1, 2, 3
  ), a AS (
    SELECT cod6, ano,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY registros) AS registros_habitual,
           mode() WITHIN GROUP (ORDER BY categorias) AS categorias_habitual
      FROM m GROUP BY 1, 2
  )
  SELECT m.cod6, m.ano, m.mes, m.registros, m.categorias,
         round(a.registros_habitual)::int AS registros_habitual, a.categorias_habitual
    FROM m JOIN a USING (cod6, ano)
   WHERE m.mes IS NOT NULL
     AND (m.categorias < a.categorias_habitual OR m.registros < 0.5 * a.registros_habitual)
   ORDER BY 1, 2, 3
  SQL

# #563 (QQ-01 da P6): o piso salarial profissional nacional do magistério
# público da educação básica, por 40 horas semanais, por ano. Sobe uma vez
# por ano, por ato do MEC: o reajuste entra aqui, no PR do ano, com o ato.
# Ano sem piso cadastrado deixa as colunas do piso vazias (nada inventado).
# #575 (QH-01 da P5): na contagem do piso, só quem recebeu 3 meses ou mais
# no ano (sem dezembro): fora os pagamentos avulsos, as rescisões e os
# recém-admitidos (em Ubatuba 2026, 553 pessoas só em julho e agosto).
our $MESES_MIN_PISO = 3;

our %PISO_MAGISTERIO = (
  2024 => { valor => 4580.57, ato => 'portaria do MEC de janeiro de 2024' },
  2025 => { valor => 4867.77, ato => 'portaria do MEC de janeiro de 2025' },
  2026 => { valor => 5130.63, ato => 'Portaria MEC nº 82, de 29 de janeiro de 2026' },
);

sub piso_magisterio ($class, $ano) {
  my $p = $PISO_MAGISTERIO{ $ano // '' } or return undef;
  return $p->{valor};
}

# Folha do SIOPE por escola no ano (#491). Primeiro por pessoa e mês (a mesma
# pessoa pode ter mais de um vínculo na escola no mesmo mês), depois por
# escola. O mês vem em texto, com um caso conhecido de latin1 ("Março"): as
# três primeiras letras bastam. O agregado da Secretaria (99999999) fica de
# fora: não é escola.
my $MES_NUM_R = _mes_num('r.mes');
my $SQL_FOLHA = <<~"SQL";
  WITH pm AS (
    SELECT r.cod_inep, left(r.mes, 3) AS m, r.cpf, r.nome_profissional, r.tipo,
                 r.categoria = '$AUX_EDUCACIONAL' AS aux,
                 sum(r.salario_total) AS s, sum(r.carga_horaria) AS ch,
                 sum(r.salario_fundeb_max) AS f70, sum(r.salario_fundeb_min) AS f30,
                 sum(r.salario_outros) AS fo,
                 sum(r.salario_base) AS b,   -- #563: o salário base (vencimento)
                 bool_or(i.mes IS NOT NULL) AS inc   -- #561: mês incompleto do município (#557)
            FROM clean.remuneracao_municipal r
            LEFT JOIN ($SQL_MESES) i
              ON i.cod6 = r.cod_municipio::text AND i.ano = r.ano AND i.mes = $MES_NUM_R
           WHERE r.ano = ? AND r.cod_inep <> 99999999
           GROUP BY 1, 2, 3, 4, 5, 6
  ),
  -- #563 (QQ-01 da P6): o piso do ano (vazio sem piso cadastrado) e, por
  -- escola, quem tem o salário base para 40 horas abaixo dele no mês típico
  -- (a mediana dos meses da pessoa, sem dezembro): o mês de admissão ou de
  -- desconto sozinho não conta.
  p AS (SELECT ?::float8 AS piso),
  pp AS (
    SELECT cod_inep, (count(*) FILTER (WHERE md < (SELECT piso FROM p)))::int AS abaixo
      FROM (SELECT cod_inep, cpf, nome_profissional,
                   percentile_cont(0.5) WITHIN GROUP (ORDER BY b / ch * 40) AS md
              FROM pm
             WHERE tipo = '$MAGISTERIO' AND m <> 'Dez' AND ch > 0 AND b IS NOT NULL
             GROUP BY 1, 2, 3
            HAVING count(*) >= $MESES_MIN_PISO) x   -- #575: 3 meses ou mais
     GROUP BY 1
  )
  SELECT pm.cod_inep,
         (count(DISTINCT (cpf, nome_profissional)) FILTER (WHERE tipo = '$MAGISTERIO'))::int AS prof_magisterio,
         round((count(*) FILTER (WHERE tipo = '$MAGISTERIO'))::numeric / count(DISTINCT m), 1)::float8 AS prof_magisterio_mes,
         (count(DISTINCT (cpf, nome_profissional)) FILTER (WHERE aux))::int AS aux_educacional,
         round((count(*) FILTER (WHERE aux))::numeric / count(DISTINCT m), 1)::float8 AS aux_educacional_mes,
         round(avg(s) FILTER (WHERE aux AND m <> 'Dez'))::float8 AS salario_aux,
         round(avg(s) FILTER (WHERE tipo = '$MAGISTERIO' AND m <> 'Dez'))::float8 AS salario_medio,
         round((avg(ch) FILTER (WHERE tipo = '$MAGISTERIO' AND m <> 'Dez'))::numeric, 1)::float8 AS carga_media,
         round(avg(s / ch * 40) FILTER (WHERE tipo = '$MAGISTERIO' AND m <> 'Dez' AND ch > 0))::float8 AS salario_40h,
         round(sum(s))::float8 AS gasto_ano,
         round(sum(f70))::float8 AS gasto_fundeb_70,
         round(sum(f30))::float8 AS gasto_fundeb_30,
         round(sum(fo))::float8 AS gasto_outras,
         count(DISTINCT m)::int AS meses,
         -- #561 (QM-01 da P4): só os meses fora dos incompletos, para anualizar
         (count(DISTINCT m) FILTER (WHERE NOT inc))::int AS meses_completos,
         coalesce(round(sum(s) FILTER (WHERE NOT inc)), 0)::float8 AS gasto_completos,
         round(avg(b / ch * 40) FILTER (WHERE tipo = '$MAGISTERIO' AND m <> 'Dez' AND ch > 0))::float8 AS salario_base_40h,
         (SELECT piso FROM p) AS piso,
         CASE WHEN (SELECT piso FROM p) IS NULL THEN NULL ELSE coalesce(max(pp.abaixo), 0) END AS abaixo_piso
    FROM pm LEFT JOIN pp ON pp.cod_inep = pm.cod_inep
   GROUP BY pm.cod_inep
  SQL

sub _blocos {
  my @ideb;
  for my $e (@ETAPAS) {
    my ($suf, $etapa, $nome_etapa) = @$e;
    for my $m (@MEDIDAS_IDEB) {
      my ($col, $origem, $desc) = @$m;
      # #461 (RX-02): o vazio do IDEB mistura "não oferece" e "não teve
      # resultado", e a falta não é aleatória.
      push @ideb, ["${col}_$suf", "i.${col}_$suf",
        "$desc, $nome_etapa. Vazio: a escola não oferece a etapa (veja oferece_$suf) ou não teve resultado publicado "
        . '(participação insuficiente no SAEB). A falta não é aleatória: é mais comum nas escolas pequenas, rurais e sem infraestrutura (veja a ajuda)', 1];
    }
  }
  return [
    { id => 'identificacao', label => 'Identificação', fixo => 1, fonte => 'censo',
      descricao => 'INEP, nome, município, UF, região, rede, localização (urbana ou rural), as coordenadas e o endereço da escola (CEP, bairro, logradouro e número), sempre incluído.',
      colunas => [
        ['inep',        'e.co_entidade::text', 'Código INEP da escola', 0],
        ['escola',      'e.no_entidade', 'Nome da escola', 0],
        ['codigo_ibge', 'e.co_municipio::text', 'Código IBGE do município', 0],
        ['municipio',   'e.no_municipio', 'Município', 0],
        ['uf',          'e.sg_uf', 'UF', 0],
        # #448 (RG-01): a região vem da UF (EduMaps::Regiao, a mesma do
        # ranking), para juntar bases de várias UFs sem mapa à mão.
        ['regiao',      EduMaps::Regiao->case_sql('e.sg_uf'), 'Região geográfica do IBGE (Norte, Nordeste, Sudeste, Sul ou Centro-Oeste), derivada da UF', 0],
        ['rede',        q{CASE e.tp_dependencia WHEN 1 THEN 'Federal' WHEN 2 THEN 'Estadual' WHEN 3 THEN 'Municipal' WHEN 4 THEN 'Privada' END}, 'Rede (dependência administrativa)', 0],
        ['localizacao', q{CASE e.tp_localizacao WHEN 1 THEN 'Urbana' WHEN 2 THEN 'Rural' END}, 'Localização (urbana ou rural)', 0],
        # #452 (VJ-04): coordenadas como declaradas ao Censo, com 6 casas.
        # #531 (QR-01): a coordenada falta em cerca de um terço das privadas
        # (16% das municipais); o CEP e o endereço, que o Censo traz de toda
        # escola, permitem situar a escola mesmo assim.
        ['latitude',    'e.latitude::float8',  "Latitude da escola, em graus decimais (WGS84), como declarada ao Censo Escolar, sem verificação. $SEM_COORD", 'coord'],
        ['longitude',   'e.longitude::float8', "Longitude da escola, em graus decimais (WGS84), como declarada ao Censo Escolar, sem verificação. $SEM_COORD", 'coord'],
        ['cep',         q{CASE WHEN e.co_cep ~ '^[0-9]{8}$' THEN substr(e.co_cep, 1, 5) || '-' || substr(e.co_cep, 6, 3) END},
         'CEP da escola, como declarado ao Censo Escolar, no formato 00000-000 (com o hífen, o Excel não tira o zero do começo). Para situar a escola sem coordenada, geocodifique o CEP com o endereço e o município', 0],
        ['bairro',      q{NULLIF(btrim(e.no_bairro), '')}, 'Bairro da escola, como declarado ao Censo Escolar. Vazio quando o Censo não traz, o que é comum nas escolas rurais (cerca de 6 em cada 10)', 0],
        ['endereco',    q{NULLIF(concat_ws(', ', NULLIF(btrim(e.ds_endereco), ''), CASE WHEN btrim(e.nu_endereco) ~ '[1-9]' THEN btrim(e.nu_endereco) END), '')},
         'Endereço da escola (logradouro e número), como declarado ao Censo Escolar. Sem o número quando o Censo traz S/N, 0 ou nada', 0],
      ] },
    # #461 (RX-02): a oferta separa "não oferece a etapa" de "não teve IDEB".
    { id => 'etapas', label => 'Etapas oferecidas', fonte => 'censo',
      descricao => 'Se a escola oferece creche, pré-escola, anos iniciais, anos finais, ensino médio, EJA e educação profissional, e se tem classe especial exclusiva. Com o IDEB, separa "não oferece a etapa" de "não teve nota".',
      colunas => [ map { [$_->[0], $_->[1], $_->[2], 1] } @ETAPAS_OFERTA ] },
    # #516 (QX-01): o número de matrículas, para medir a oferta (contar as
    # escolas que oferecem a etapa não mede: Mirante e São José do Jacuípe/BA
    # têm 3 escolas com creche cada e 106 contra 329 matrículas).
    { id => 'matriculas', label => 'Matrículas', fonte => 'censo',
      descricao => 'Matrículas da escola na educação básica e por etapa (creche, pré-escola, anos iniciais, anos finais, médio, educação profissional, EJA), na educação especial e em tempo integral, para somar por município. As etapas não somam o total: use mat_basica.',
      colunas => [ map { [$_->[0], $_->[1], $_->[2], 1] } @MATRICULAS ] },
    # #518 (QW-01): a oferta da prefeitura feita por convênio fica na rede
    # privada (SP: 41% das matrículas em creche da prefeitura mais as
    # conveniadas). #520 (QV-01): o Censo marca a escola, não a vaga; a soma
    # é um teto. Colunas do próprio Censo, sem join.
    { id => 'parceria', label => 'Parceria com o poder público', fonte => 'censo',
      descricao => 'Se a escola tem parceria ou convênio com o poder público, com qual esfera (municipal, estadual ou as duas), e a categoria da escola privada. Com as matrículas, separa as privadas conveniadas com a prefeitura das demais.',
      colunas => [
        ['parceria_poder_publico', 'e.in_poder_publico_parceria',
         'Parceria ou convênio com o poder público (1 = sim, 0 = não), como declarado ao Censo Escolar (ex.: creche privada conveniada com a prefeitura). O Censo marca a escola conveniada, não a vaga: ela pode ter também alunos pagantes, e somar as matrículas das conveniadas dá o máximo da oferta conveniada (um teto), e as da categoria Particular são o caso mais provável de mistura. Algumas escolas públicas também têm parceria (sobretudo na educação profissional): para a oferta conveniada, filtre a rede privada', 1],
        ['parceria_esfera', q{CASE e.tp_poder_publico_parceria WHEN 1 THEN 'Municipal' WHEN 2 THEN 'Estadual' WHEN 3 THEN 'Estadual e municipal' END},
         'Esfera do poder público da parceria (Municipal, Estadual ou Estadual e municipal). Vazia sem parceria. Para a oferta da prefeitura, conte Municipal e Estadual e municipal', 0],
        ['categoria_privada', q{CASE e.tp_categoria_escola_privada WHEN 1 THEN 'Particular' WHEN 2 THEN 'Comunitária' WHEN 3 THEN 'Confessional' WHEN 4 THEN 'Filantrópica' END},
         'Categoria da escola privada (Particular, Comunitária, Confessional ou Filantrópica). Vazia nas escolas públicas', 0],
      ] },
    { id => 'infraestrutura', label => 'Infraestrutura', fonte => 'censo',
      descricao => 'Água, energia, esgoto (e se a escola não tem água, energia ou esgoto), lixo, banheiro, biblioteca, laboratórios, quadra, internet e rampas.',
      colunas => [ map { [$_->[0], "e.$_->[0]", $_->[1], 1] } @INFRA ] },
    { id => 'docencia', label => 'Docência', fonte => 'censo',
      descricao => 'Número de docentes, proporções de licenciatura, mestrado, doutorado, efetivos, sem formação continuada, ensino superior, pós-graduação e formação continuada, sobre o total de docentes da escola (as quatro partes do índice de capacitação docente), e os docentes por etapa. As proporções são da escola inteira, não de uma etapa: num modelo por etapa, use os docentes por etapa para separar ou ponderar as escolas. Quem dá aula em mais de uma escola conta em cada uma.',
      colunas => [ map { [$_->[0], $_->[1], $_->[2], 1] } @DOCENCIA ] },
    { id => 'desempenho', label => 'IDEB e SAEB por etapa', fonte => 'ideb', usa_ano_ideb => 1,
      descricao => 'IDEB, notas e aprovação nos anos iniciais (_ai), finais (_af) e no ensino médio (_em), na edição escolhida. O IDEB falta sobretudo nas escolas pequenas, rurais e sem infraestrutura: marque também as etapas oferecidas.',
      colunas => \@ideb },
    # #465 (RY-01): os índices próprios, com a versão da fórmula.
    { id => 'indices', label => 'Índices do EduMaps', fonte => 'indices_edumaps',
      descricao => 'Os seis índices de 0 a 10 do EduMaps (infraestrutura, capacidade de atendimento, capacitação docente, diversidade discente, capacidade gestora e sustentabilidade), calculados a partir do Censo Escolar, e as partes dos índices de diversidade, de capacidade de atendimento, de capacidade gestora, de infraestrutura e de sustentabilidade (as da capacitação docente estão no bloco Docência), com a versão da fórmula em versao_indice. Notas de versões diferentes não são comparáveis.',
      colunas => _indices_colunas() },
    { id => 'inse', label => 'Nível socioeconômico (INSE)', fonte => 'inse',
      descricao => 'INSE médio dos alunos e o nível (I a VIII), na edição mais recente do SAEB.',
      colunas => [
        ['inse_media',         'x.media_inse', "INSE médio dos alunos da escola. $INSE_VAZIO", 1],
        ['inse_classificacao', 'x.inse_classificacao', "Nível do INSE (I a VIII). $INSE_VAZIO", 0],
      ] },
    # #491 (RJ-03): a folha do SIOPE agregada por escola, sem nomes nem CPF.
    { id => 'remuneracao', label => 'Remuneração (SIOPE)', fonte => 'siope', usa_ano_siope => 1,
      descricao => 'Profissionais do magistério (no ano e por mês), salário médio mensal, carga horária média, salário para 40 horas, auxiliares e assistentes educacionais e gasto com pessoal da escola no ano escolhido, com a parte paga pelo Fundeb (70% e 30%) e por outras fontes, '
        . 'da folha que o município declara ao SIOPE. Só a rede municipal e só os municípios em que o SIOPE detalha a folha por escola; sem nomes nem CPF.',
      colunas => [
        ['prof_magisterio', 'f.prof_magisterio',
          "Profissionais do magistério pagos no ano, contados pela pessoa (CPF mascarado e nome: o CPF mascarado sozinho junta pessoas diferentes). "
          . 'Não é o número de docentes: conta todo mundo que recebeu no ano, inclusive quem esteve na escola só parte dele (compare com prof_magisterio_mes e qt_docentes). '
          . $SIOPE_VAZIO, 1],
        # #512 (QZ-03): pessoas por mês, comparável aos docentes do Censo.
        ['prof_magisterio_mes', 'f.prof_magisterio_mes',
          "Média de profissionais do magistério por mês com folha (pessoas pagas em cada mês, somadas e divididas pelos meses de meses_folha). É o número mais perto dos docentes do Censo (qt_docentes), mas ainda inclui quem está na escola sem dar aula (coordenação, apoio). $SIOPE_VAZIO", 1],
        ['salario_medio_magisterio', 'f.salario_medio',
          "Salário total médio por mês de um profissional do magistério, em reais, sem dezembro (que traz o 13º). Soma os vínculos da pessoa na escola no mês. $SIOPE_VAZIO $SEM_MAGISTERIO", 1],
        ['carga_horaria_media_magisterio', 'f.carga_media',
          "Carga horária semanal média de um profissional do magistério por mês, em horas, sem dezembro. Soma os vínculos da pessoa na escola no mês. $SIOPE_VAZIO", 1],
        ['salario_40h_magisterio', 'CASE WHEN cm.suspeita THEN NULL ELSE f.salario_40h END',
          "Salário médio do magistério convertido para 40 horas semanais (salário ÷ carga × 40), em reais, sem dezembro e sem os meses sem carga horária. $SIOPE_VAZIO $SEM_MAGISTERIO", 1],
        # #563 (QQ-01 da P6): o salário base (vencimento), sobre o qual vale o piso.
        ['salario_base_40h_magisterio', 'CASE WHEN cm.suspeita THEN NULL ELSE f.salario_base_40h END',
          "Salário base (vencimento, sem gratificações nem adicionais) médio por mês de um profissional do magistério, convertido para 40 horas semanais (base ÷ carga × 40), em reais, sem dezembro. É sobre o salário base que vale o piso do magistério; salario_40h_magisterio é o salário total. $SIOPE_VAZIO $SEM_MAGISTERIO", 1],
        ['piso_magisterio_ano', 'CASE WHEN f.cod_inep IS NOT NULL THEN f.piso END',
          "O piso salarial nacional do magistério do ano da folha, por 40 horas semanais, usado em prof_magisterio_base_abaixo_piso (2024: R\$ 4.580,57; 2025: R\$ 4.867,77; 2026: R\$ 5.130,63, Portaria MEC nº 82/2026). Vazio: ano sem piso cadastrado, ou escola sem folha", 1],
        ['prof_magisterio_base_abaixo_piso', 'CASE WHEN cm.suspeita THEN NULL ELSE f.abaixo_piso END',
          "Profissionais do magistério da escola com o salário base para 40 horas abaixo do piso do ano no mês típico (a mediana dos meses da pessoa, sem dezembro), entre quem recebeu 3 meses ou mais na escola no ano: um mês de admissão ou de desconto, os pagamentos avulsos e as rescisões não contam. Não é a verificação legal do piso: complementos, jornada, licenças e reajuste pago com atraso mudam a leitura. Quem trabalha em mais de uma escola conta em cada uma: a soma das escolas pode passar do número de pessoas da rede. Vazio: ano sem piso cadastrado, ou escola sem folha", 1],
        # #572 (QI-02 da P3): a carga mais comum do município e o aviso.
        ['carga_comum_municipio', 'CASE WHEN f.cod_inep IS NOT NULL THEN cm.carga END',
          "Carga horária mais comum dos profissionais do magistério do município no ano (toda a folha, sem dezembro). Quando a maioria dos pagamentos tem carga abaixo de 20, a carga não parece estar em horas semanais (aulas ou jornada parcial): então salario_40h_magisterio, salario_base_40h_magisterio e prof_magisterio_base_abaixo_piso ficam vazios, e vale o salário sem conversão (salario_medio_magisterio). $SIOPE_VAZIO", 1],
        # #512 (QZ-02): na educação infantil, quem está com as crianças pode
        # estar na folha como auxiliar ou assistente educacional, não no
        # magistério.
        ['aux_educacional', 'f.aux_educacional',
          "Auxiliares e assistentes educacionais pagos no ano (categoria \"$AUX_EDUCACIONAL\" do SIOPE, entre os outros profissionais da educação), contados pela pessoa. Em creches, pode ser quem trabalha com as crianças quando a folha não tem ninguém no magistério. $SIOPE_VAZIO", 1],
        ['aux_educacional_mes', 'f.aux_educacional_mes',
          "Média de auxiliares e assistentes educacionais por mês com folha. $SIOPE_VAZIO", 1],
        ['salario_medio_aux_educacional', 'f.salario_aux',
          "Salário total médio por mês de um auxiliar ou assistente educacional, em reais, sem dezembro. Soma os vínculos da pessoa na escola no mês. Vazio também quando a escola não tem auxiliares na folha. $SIOPE_VAZIO", 1],
        ['gasto_pessoal_ano', 'f.gasto_ano',
          "Soma do salário total de todos os profissionais da escola no ano (magistério e demais), em reais, com o 13º. Com menos de 12 meses (veja meses_folha), é só o gasto desses meses. $SIOPE_VAZIO", 1],
        # #553 (QS-01 da P5): o gasto do ano por fonte de recurso.
        ['gasto_fundeb_70_ano', 'f.gasto_fundeb_70',
          "Parte do gasto_pessoal_ano paga com a parcela de 70% do Fundeb, em reais, como o município declara ao SIOPE em cada pagamento. $FONTE_SOMA $SIOPE_VAZIO", 1],
        ['gasto_fundeb_30_ano', 'f.gasto_fundeb_30',
          "Parte do gasto_pessoal_ano paga com a parcela de 30% do Fundeb, em reais. $FONTE_SOMA $SIOPE_VAZIO", 1],
        ['gasto_outras_fontes_ano', 'f.gasto_outras',
          "Parte do gasto_pessoal_ano paga com outras fontes (fora do Fundeb), em reais. $FONTE_SOMA $SIOPE_VAZIO", 1],
        ['meses_folha', 'f.meses',
          "Meses do ano com folha da escola no SIOPE (de 1 a 12). $SIOPE_VAZIO", 1],
        ['meses_folha_incompletos', 'CASE WHEN f.cod_inep IS NOT NULL THEN mi.meses END',
          "Meses do ano em que a folha do município veio pela metade: menos categorias de profissionais que o habitual do ano, ou menos da metade dos registros de um mês típico (ex.: \"set, out\"). Nesses meses o gasto e as médias por mês ficam abaixo do real. Sem carga registrada, pode ser a declaração do município ao SIOPE ou a carga; com a carga registrada (a data está em Fontes e metodologia), os dados são os da planilha baixada nessa data, e a falta está na fonte, não na carga. Vazio: nenhum mês incompleto, ou escola sem folha", 0],
        # #561 (QM-01 da P4): para anualizar sem os meses incompletos.
        ['meses_completos', 'f.meses_completos',
          "Meses do ano com folha da escola fora dos meses incompletos do município (veja meses_folha_incompletos). Sem mês incompleto, igual a meses_folha. $SIOPE_VAZIO", 1],
        ['gasto_pessoal_meses_completos', 'f.gasto_completos',
          "O gasto_pessoal_ano só dos meses completos (meses_completos), em reais. Para anualizar sem os meses incompletos: gasto_pessoal_meses_completos × 12 ÷ meses_completos. Dezembro, com o 13º, entra quando está completo. Sem mês incompleto, igual a gasto_pessoal_ano. $SIOPE_VAZIO", 1],
      ] },
    { id => 'porte', label => 'Porte do município', fonte => 'ibge_populacao',
      descricao => 'População estimada do município, a classe de tamanho do IBGE e as crianças na idade da creche e da pré-escola (Censo Demográfico).',
      colunas => [
        ['populacao_municipio', 'pm.populacao_estimada', 'População estimada do município', 1],
        ['porte_municipio', EduMaps::Porte->case_sql('pm.populacao_estimada'), 'Classe de tamanho da população do IBGE (ex.: 10_20mil = de 10 mil a 20 mil habitantes)', 0],
        # #533 (QP-01 da P2): a idade da creche e da pré-escola, do Censo
        # Demográfico (outra fonte e outro ano que a estimativa acima).
        ['populacao_0_3', 'pi.populacao_0_3',
          "Crianças de 0 a 3 anos no município, a idade da creche, contadas no Censo Demográfico (ano em ano_populacao_idade). $TAXA_ATENDIMENTO", 1, 'ibge_populacao_idade'],
        ['populacao_4_5', 'pi.populacao_4_5',
          "Crianças de 4 e 5 anos no município, a idade da pré-escola, contadas no Censo Demográfico (ano em ano_populacao_idade). $TAXA_ATENDIMENTO", 1, 'ibge_populacao_idade'],
      ] },
  ];
}

my %BLOCO = map { $_->{id} => $_ } @{ _blocos() };
sub ids_blocos ($class) { map { $_->{id} } grep { !$_->{fixo} } @{ _blocos() } }

# Catálogo público (sem as expressões SQL), para a tela.
sub catalogo ($class) {
  return [ map {
    my $b = $_;
    +{ id => $b->{id}, label => $b->{label}, descricao => $b->{descricao}, fonte => $b->{fonte},
       fixo => $b->{fixo} ? \1 : \0,
       colunas => [ map { +{ coluna => $_->[0], descricao => $_->[2] } } @{ $b->{colunas} } ] }
  } @{ _blocos() } ];
}

# Anos das bases: o Censo e o INSE mais recentes, as edições do IDEB e o ano
# da estimativa de população (catálogo de fontes).
sub anos ($class, $dbh) {
  my ($censo) = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas');
  my ($inse)  = $dbh->selectrow_array('SELECT max(nu_ano_saeb) FROM clean.inse');
  my $ideb = $dbh->selectcol_arrayref('SELECT DISTINCT ano FROM clean.ideb_notas_escolas ORDER BY ano DESC');
  my $pop = eval { EduMaps::Fontes->versao($dbh, 'ibge_populacao')->{ibge_populacao}{periodo} };
  my $pop_idade = eval { EduMaps::Fontes->versao($dbh, 'ibge_populacao_idade')->{ibge_populacao_idade}{periodo} };
  return {
    censo => defined $censo ? 0 + $censo : undef,
    inse  => defined $inse ? 0 + $inse : undef,
    ideb  => [ map { 0 + $_ } @$ideb ],
    populacao => $pop,
    populacao_idade => $pop_idade,
    indices => $class->indices_versao,
    %{ $class->anos_siope($dbh) },
  };
}

# Anos da folha do SIOPE com dado por escola (#491) e o padrão: o ano
# completo mais recente (12 meses em algum município); sem ano completo, o
# mais recente.
sub anos_siope ($class, $dbh) {
  my $rows = eval {
    $dbh->selectall_arrayref(q{
      SELECT ano, max(meses) AS meses FROM (
        SELECT ano, cod_municipio, count(DISTINCT left(mes, 3)) AS meses
          FROM clean.remuneracao_municipal WHERE cod_inep <> 99999999
         GROUP BY 1, 2) x
       GROUP BY ano ORDER BY ano DESC
    });
  } // [];
  my @anos = map { 0 + $_->[0] } @$rows;
  my ($completo) = map { 0 + $_->[0] } grep { $_->[1] >= 12 } @$rows;
  return { siope => \@anos, siope_padrao => $completo // $anos[0] };
}

# #512 (QZ-01): cobertura da folha por município, para a tela da base e
# para /fontes. Um item por município com folha separada por escola, com o
# código IBGE, o nome e a UF (do Censo) e, por ano, os meses e as escolas.
# Município em que o SIOPE só traz o total da Secretaria fica com 0 escolas.
# Os meses são os das escolas: o mês em que só a Secretaria aparece não conta
# (Cuiabá 2026: julho e agosto só com o total da Secretaria).

# Meses incompletos por "<cod6>|<ano>"; com $cod6, só os desse município.
sub meses_incompletos ($class, $dbh, $cod6 = undef) {
  my $rows = eval { $dbh->selectall_arrayref($SQL_MESES, { Slice => {} }, $cod6, $cod6) } // [];
  my %por;
  for my $r (@$rows) {
    push @{ $por{"$r->{cod6}|$r->{ano}"} }, {
      mes => $r->{mes}, nome => $MESES[ $r->{mes} - 1 ],
      map { $_ => $r->{$_} } qw(registros categorias registros_habitual categorias_habitual),
    };
  }
  return \%por;
}

# #558 (QT-02 da P2): em cada mês, onde está a maior parte do valor
# declarado: nas escolas ou no código da Secretaria (99999999, sem escola).
# Cuiabá 2026: janeiro e fevereiro por escola; de março em diante, quase tudo
# na Secretaria. Chave "<cod6>|<ano>" => { escola => [meses], secretaria => [meses] }.
sub meses_por_lugar ($class, $dbh, $cod6 = undef) {
  my $rows = eval {
    $dbh->selectall_arrayref(<<~"SQL", { Slice => {} }, $cod6, $cod6);
      SELECT cod_municipio::text AS cod6, ano::int AS ano, $MES_NUM AS mes,
             coalesce(sum(salario_total) FILTER (WHERE cod_inep <> 99999999), 0)::float8 AS escolas,
             coalesce(sum(salario_total) FILTER (WHERE cod_inep = 99999999), 0)::float8 AS secretaria
        FROM clean.remuneracao_municipal
       WHERE (?::text IS NULL OR cod_municipio::text = ?)
       GROUP BY 1, 2, 3
       ORDER BY 1, 2, 3
      SQL
  } // [];
  my %por;
  for my $r (grep { defined $_->{mes} } @$rows) {
    my $x = $por{"$r->{cod6}|$r->{ano}"} //= { escola => [], secretaria => [] };
    push @{ $x->{ $r->{escolas} >= $r->{secretaria} ? 'escola' : 'secretaria' } }, $r->{mes};
  }
  return \%por;
}

# #571 (QI-01 da P3): o salário do magistério da rede inteira (escolas e o
# total da Secretaria), por município e ano: por pessoa e mês, sem dezembro
# (13º), a mediana do salário total e do base, e a carga mais comum. Sem
# conversão para 40 horas (B1): a carga pode não estar em horas (#572).
# Chave "<cod6>|<ano>".
sub salario_rede ($class, $dbh, $cod6 = undef) {
  my $PISO_VALUES = join ', ', map { sprintf '(%d, %.2f)', $_, $PISO_MAGISTERIO{$_}{valor} } sort keys %PISO_MAGISTERIO;
  my $rows = eval {
    $dbh->selectall_arrayref(<<~"SQL", { Slice => {} }, $cod6, $cod6);
      WITH pm AS (
        SELECT cod_municipio::text AS cod6, ano::int AS ano, left(mes, 3) AS m, cpf, nome_profissional,
               sum(salario_total) AS t, sum(salario_base) AS b, sum(carga_horaria) AS ch,
               bool_or(cod_inep <> 99999999) AS esc
          FROM clean.remuneracao_municipal
         WHERE tipo = '$MAGISTERIO' AND left(mes, 3) <> 'Dez'
           AND (?::text IS NULL OR cod_municipio::text = ?)
         GROUP BY 1, 2, 3, 4, 5
      )
      , pp AS (
        -- #575: por pessoa, na rede inteira: se teve escola no ano, os meses
        -- pagos e o salário base para 40 horas no mês típico
        SELECT cod6, ano, cpf, nome_profissional, bool_or(esc) AS esc, count(*) AS meses,
               percentile_cont(0.5) WITHIN GROUP (ORDER BY b / ch * 40) AS md
          FROM pm WHERE ch > 0 AND b IS NOT NULL
         GROUP BY 1, 2, 3, 4
      ), piso (ano, valor) AS (VALUES $PISO_VALUES)
      , cont AS (
        SELECT pp.cod6, pp.ano, max(piso.valor) AS piso,
               (count(*) FILTER (WHERE md < piso.valor AND meses >= $MESES_MIN_PISO))::int AS abaixo,
               (count(*) FILTER (WHERE md < piso.valor AND meses >= $MESES_MIN_PISO AND NOT esc))::int AS abaixo_sec
          FROM pp JOIN piso ON piso.ano = pp.ano
         GROUP BY 1, 2
      )
      SELECT pm.cod6, pm.ano,
             count(DISTINCT (cpf, nome_profissional))::int AS pessoas,
             round(percentile_cont(0.5) WITHIN GROUP (ORDER BY t))::float8 AS total,
             round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b))::float8 AS base,
             (mode() WITHIN GROUP (ORDER BY ch))::float8 AS carga,
             -- #572 (QI-02 da P3): a maioria dos pagamentos com carga abaixo
             -- de 20: a carga não parece estar em horas semanais (aulas,
             -- jornada parcial), e as contas por 40 horas não valem.
             (avg((ch < 20)::int) > 0.5) AS suspeita,
             max(cont.piso)::float8 AS piso, max(cont.abaixo) AS abaixo, max(cont.abaixo_sec) AS abaixo_sec
        FROM pm LEFT JOIN cont ON cont.cod6 = pm.cod6 AND cont.ano = pm.ano
       GROUP BY 1, 2
      SQL
  } // [];
  return { map { ("$_->{cod6}|$_->{ano}" => {
    pessoas => $_->{pessoas}, total => $_->{total}, base => $_->{base}, carga_comum => $_->{carga},
    carga_suspeita => ($_->{suspeita} ? \1 : \0),
    # #575 (QH-01 da P5): abaixo do piso na rede inteira (com a Secretaria);
    # sem piso cadastrado ou com a carga fora de horas (#572), sem contagem
    piso => $_->{piso},
    ((defined $_->{piso} && !$_->{suspeita})
      ? (abaixo_piso => $_->{abaixo} // 0, abaixo_piso_so_secretaria => $_->{abaixo_sec} // 0)
      : (abaixo_piso => undef, abaixo_piso_so_secretaria => undef)),
  }) } @$rows };
}

# #564 (QQ-02 da P6): a data de cada carga registrada da folha, por
# "<cod6>|<ano>" => "AAAA-MM-DD". #576 (QH-02 da P5): com a carga
# registrada, os dados são os da planilha baixada nessa data (a folha e o
# registro trocam na mesma transação): um mês incompleto já veio assim.
sub cargas_folha ($class, $dbh) {
  my %carga;
  my ($manifesto) = eval { $dbh->selectrow_array(
    q{SELECT raw_manifest::text FROM clean.import_metadata WHERE table_name = 'clean.remuneracao_municipal'}) };
  for my $e (@{ (eval { Mojo::JSON::decode_json($manifesto // '[]') }) // [] }) {
    next unless ref $e eq 'HASH' && $e->{cod_municipio} && $e->{ano};
    $carga{"$e->{cod_municipio}|$e->{ano}"} = substr($e->{baixado_em} // '', 0, 10) || undef;
  }
  return \%carga;
}

# #589 (P1-FL-03): o salário do magistério de uma escola com a mesma conta
# da rede (salario_rede): por pessoa e mês, sem dezembro, a mediana do total
# e do base e a carga mais comum, sem conversão para 40 horas.
sub salario_escola ($class, $dbh, $cod_inep, $ano) {
  my $r = eval {
    $dbh->selectrow_hashref(<<~"SQL", undef, $cod_inep, $ano);
      WITH pm AS (
        SELECT left(mes, 3) AS m, cpf, nome_profissional,
               sum(salario_total) AS t, sum(salario_base) AS b, sum(carga_horaria) AS ch
          FROM clean.remuneracao_municipal
         WHERE tipo = '$MAGISTERIO' AND left(mes, 3) <> 'Dez' AND cod_inep = ? AND ano = ?
         GROUP BY 1, 2, 3
      )
      SELECT count(DISTINCT (cpf, nome_profissional))::int AS pessoas,
             round(percentile_cont(0.5) WITHIN GROUP (ORDER BY t))::float8 AS total,
             round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b))::float8 AS base,
             (mode() WITHIN GROUP (ORDER BY ch))::float8 AS carga_comum
        FROM pm
      SQL
  };
  return undef unless $r && $r->{pessoas};
  return $r;
}

sub cobertura_siope ($class, $dbh, $uf = undef) {
  my $rows = eval {
    $dbh->selectall_arrayref(q{
      SELECT m.co_municipio::text AS codigo_ibge, m.no_municipio AS municipio, m.sg_uf AS uf,
             r.ano::int AS ano,
             -- meses com folha das escolas; só a Secretaria: os meses dela
             COALESCE(NULLIF(count(DISTINCT left(r.mes, 3)) FILTER (WHERE r.cod_inep <> 99999999), 0),
                      count(DISTINCT left(r.mes, 3)))::int AS meses,
             (count(DISTINCT r.cod_inep) FILTER (WHERE r.cod_inep <> 99999999))::int AS escolas
        FROM clean.remuneracao_municipal r
        JOIN (SELECT DISTINCT co_municipio, no_municipio, sg_uf FROM clean.censo_escolas) m
          ON left(m.co_municipio::text, 6) = r.cod_municipio::text
       WHERE (?::text IS NULL OR m.sg_uf = ?)
       GROUP BY 1, 2, 3, 4
       ORDER BY 3, 2, 4 DESC
    }, { Slice => {} }, $uf, $uf);
  } // [];
  my $inc = $class->meses_incompletos($dbh);
  my $lugar = $class->meses_por_lugar($dbh);
  my $salario = $class->salario_rede($dbh);   # #571
  my %carga = %{ $class->cargas_folha($dbh) };   # #564
  my (@lista, %por);
  for my $r (@$rows) {
    my $m = $por{ $r->{codigo_ibge} } //= do {
      push @lista, { map { $_ => $r->{$_} } qw(codigo_ibge municipio uf) };
      $lista[-1]{anos} = [];
      $lista[-1];
    };
    push @{ $m->{anos} }, { map { $_ => $r->{$_} } qw(ano meses escolas) };
    my $chave = substr($r->{codigo_ibge}, 0, 6) . "|$r->{ano}";
    # #557: os meses com a folha pela metade
    $m->{anos}[-1]{incompletos} = $inc->{$chave} // [];
    $m->{anos}[-1]{carga} = $carga{$chave};   # #564: undef = carga não registrada
    $m->{anos}[-1]{salario_magisterio} = $salario->{$chave};   # #571: a rede inteira
    # #558 (QT-02 da P2): os meses por escola e os da Secretaria, pela maior
    # parte do valor. "meses" conta só os por escola (o mês com um centavo
    # numa escola e o resto na Secretaria não é folha por escola); sem
    # nenhum, os meses da Secretaria, como antes.
    my $l = $lugar->{$chave} // { escola => [], secretaria => [] };
    $m->{anos}[-1]{meses_escola}     = $l->{escola};
    $m->{anos}[-1]{meses_secretaria} = $l->{secretaria};
    $m->{anos}[-1]{meses} = scalar @{ $l->{escola} } || scalar @{ $l->{secretaria} } || $r->{meses}
      if $r->{escolas};
  }
  return \@lista;
}

# #554 (QS-02 da P5): o fechamento da folha de cada município e ano da UF.
# A base tem uma linha por escola do Censo em funcionamento, e a soma delas
# não dá o total declarado: falta a folha da Secretaria (código 99999999,
# sem escola) e a de escolas que o SIOPE declara e a lista do Censo não tem
# (código novo, escola fechada). As quatro somas fecham: escolas_base +
# secretaria + fora_total = total. Chave: "<codigo_ibge de 6 dígitos>|<ano>".
sub fechamento_folha ($class, $dbh, $uf, $ano_censo) {
  my $rows = eval {
    $dbh->selectall_arrayref(q{
      WITH mun AS (
        SELECT DISTINCT left(co_municipio::text, 6) AS cod6
          FROM clean.censo_escolas WHERE sg_uf = ?
      ), lista AS (
        SELECT co_entidade FROM clean.censo_escolas
         WHERE nu_ano_censo = ? AND tp_situacao_funcionamento = 1 AND sg_uf = ?
      )
      SELECT r.cod_municipio::text AS cod6, r.ano::int AS ano,
             CASE WHEN r.cod_inep = 99999999 THEN 'secretaria'
                  WHEN l.co_entidade IS NOT NULL THEN 'base'
                  ELSE 'fora' END AS parte,
             CASE WHEN r.cod_inep = 99999999 OR l.co_entidade IS NOT NULL THEN NULL
                  ELSE r.cod_inep::text END AS inep,
             max(r.escola) AS escola,
             round(sum(r.salario_total))::float8 AS valor,
             -- #579 (QG-01 da P6): a folha inteira por fonte
             coalesce(sum(r.salario_fundeb_max), 0)::float8 AS f70,
             coalesce(sum(r.salario_fundeb_min), 0)::float8 AS f30,
             coalesce(sum(r.salario_outros), 0)::float8 AS fo
        FROM clean.remuneracao_municipal r
        JOIN mun m ON m.cod6 = r.cod_municipio::text
        LEFT JOIN lista l ON l.co_entidade = r.cod_inep
       GROUP BY 1, 2, 3, 4
       ORDER BY 1, 2, 3, valor DESC
    }, { Slice => {} }, $uf, $ano_censo, $uf);
  } // [];
  my %f;
  for my $r (@$rows) {
    my $x = $f{"$r->{cod6}|$r->{ano}"} //= { total => 0, escolas_base => 0, secretaria => 0, fora_total => 0, fora => [],
                                             por_fonte => { fundeb_70 => 0, fundeb_30 => 0, outras => 0 } };
    $x->{total} += $r->{valor};
    # #579: a divisão por fonte da folha inteira (escolas, Secretaria e fora da lista)
    $x->{por_fonte}{fundeb_70} += $r->{f70};
    $x->{por_fonte}{fundeb_30} += $r->{f30};
    $x->{por_fonte}{outras}    += $r->{fo};
    if    ($r->{parte} eq 'base')       { $x->{escolas_base} += $r->{valor} }
    elsif ($r->{parte} eq 'secretaria') { $x->{secretaria}   += $r->{valor} }
    else {
      $x->{fora_total} += $r->{valor};
      push @{ $x->{fora} }, { inep => $r->{inep}, escola => $r->{escola}, valor => $r->{valor} };
    }
  }
  for my $x (values %f) { $_ = 0 + sprintf('%.0f', $_) for values %{ $x->{por_fonte} } }
  return \%f;
}

# #580 (QG-02 da P6): a folha por município, num arquivo: uma linha por
# município e ano com folha na UF, com o que a tela da base diz em frases
# (cobertura, fechamento, fontes, salário e piso da rede, carga). Cada
# coluna: [nome, descrição, numérica?].
our @FOLHA_MUNICIPIO_COLUNAS = (
  ['codigo_ibge', 'Código IBGE do município', 0],
  ['municipio', 'Município', 0],
  ['uf', 'UF', 0],
  ['ano', 'Ano (exercício) da folha do SIOPE', 1],
  ['meses_por_escola', 'Meses em que a maior parte do valor declarado está nas escolas (de 1 a 12). Sem nenhum, os meses da Secretaria', 1],
  ['meses_lista_escola', 'Os meses por escola (1 a 12, separados por vírgula)', 0],
  ['meses_lista_secretaria', 'Os meses em que a maior parte do valor está no total da Secretaria, sem escola (1 a 12)', 0],
  ['meses_incompletos', 'Meses com a folha pela metade (menos categorias que o habitual do ano ou menos da metade dos registros de um mês típico). Com a carga registrada, a falta está na própria planilha do SIOPE', 0],
  ['escolas_com_folha', 'Escolas com folha no ano, como o SIOPE declara (pode incluir escola fora da lista do Censo)', 1],
  ['total_declarado', 'Total da folha declarada ao SIOPE no ano, em reais (escolas, Secretaria e fora da lista)', 1],
  ['total_escolas_base', 'Parte do total nas escolas da lista do Censo (as da base de análise), em reais', 1],
  ['total_secretaria', 'Parte do total no código da Secretaria (99999999), sem escola, em reais', 1],
  ['total_fora_lista', 'Parte do total em escolas que o SIOPE declara e a lista do Censo não tem, em reais', 1],
  ['fundeb_70', 'Parte do total paga com a parcela de 70% do Fundeb, em reais. Não é a verificação do mínimo legal: essa conta usa a receita do Fundeb, que não está na base', 1],
  ['fundeb_30', 'Parte do total paga com a parcela de 30% do Fundeb, em reais', 1],
  ['outras_fontes', 'Parte do total paga com outras fontes, em reais', 1],
  ['magisterio_pessoas', 'Profissionais do magistério pagos no ano em toda a folha (escolas e Secretaria), contados pela pessoa', 1],
  ['salario_total_mediana', 'Mediana do salário total por pessoa e mês do magistério, sem dezembro e sem conversão para 40 horas, em reais', 1],
  ['salario_base_mediana', 'Mediana do salário base (vencimento) por pessoa e mês do magistério, sem dezembro, em reais', 1],
  ['carga_comum', 'Carga horária mais comum do magistério no ano', 1],
  ['carga_nao_parece_horas', '"sim" quando a maioria dos pagamentos tem carga abaixo de 20: a carga não parece estar em horas semanais, e as contas por 40 horas não valem', 0],
  ['piso_ano', 'O piso nacional do magistério do ano, por 40 horas semanais. Vazio: ano sem piso cadastrado', 1],
  ['abaixo_piso_rede', 'Profissionais do magistério de toda a folha com o salário base para 40 horas abaixo do piso no mês típico, entre quem recebeu 3 meses ou mais. Não é a verificação legal do piso. Vazio: sem piso ou com a carga fora de horas', 1],
  ['abaixo_piso_so_secretaria', 'Desses, os que estão só no total da Secretaria (o total da Secretaria pode ter pagamentos parciais)', 1],
  ['data_carga', 'Data em que a planilha do SIOPE foi baixada. Vazio: carga feita antes do registro', 0],
  ['sha256_planilha', 'SHA-256 da planilha do SIOPE baixada nessa carga', 0],
);

sub folha_municipios ($class, $dbh, $uf) {
  my $cob  = $class->cobertura_siope($dbh, $uf);
  my $fech = $class->fechamento_folha($dbh, $uf, $class->anos($dbh)->{censo});
  my %arq;
  my ($manifesto) = eval { $dbh->selectrow_array(
    q{SELECT raw_manifest::text FROM clean.import_metadata WHERE table_name = 'clean.remuneracao_municipal'}) };
  for my $e (@{ (eval { Mojo::JSON::decode_json($manifesto // '[]') }) // [] }) {
    next unless ref $e eq 'HASH' && $e->{cod_municipio} && $e->{ano};
    $arq{"$e->{cod_municipio}|$e->{ano}"} = $e;
  }
  my @abrev = qw(jan fev mar abr mai jun jul ago set out nov dez);
  my @linhas;
  for my $m (@$cob) {
    for my $a (@{ $m->{anos} }) {
      my $k = substr($m->{codigo_ibge}, 0, 6) . "|$a->{ano}";
      my $f = $fech->{$k} // {};
      my $s = $a->{salario_magisterio} // {};
      my $e = $arq{$k} // {};
      push @linhas, [
        $m->{codigo_ibge}, $m->{municipio}, $m->{uf}, $a->{ano}, $a->{meses},
        join(',', @{ $a->{meses_escola} // [] }), join(',', @{ $a->{meses_secretaria} // [] }),
        join(', ', map { $abrev[ $_->{mes} - 1 ] } @{ $a->{incompletos} // [] }),
        $a->{escolas}, $f->{total}, $f->{escolas_base}, $f->{secretaria}, $f->{fora_total},
        @{ $f->{por_fonte} // {} }{qw(fundeb_70 fundeb_30 outras)},
        $s->{pessoas}, $s->{total}, $s->{base}, $s->{carga_comum},
        ($s->{carga_suspeita} && ${ $s->{carga_suspeita} } ? 'sim' : ''),
        $s->{piso}, $s->{abaixo_piso}, $s->{abaixo_piso_so_secretaria},
        (defined $e->{baixado_em} ? substr($e->{baixado_em}, 0, 10) : undef), $e->{sha256},
      ];
    }
  }
  my @cab = map { $_->[0] } @FOLHA_MUNICIPIO_COLUNAS;
  my @num = map { $_->[2] } @FOLHA_MUNICIPIO_COLUNAS;
  return (\@cab, \@linhas, \@num);
}

sub folha_municipios_dicionario ($class) {
  return ([qw(coluna descricao fonte)],
    [ map { [ $_->[0], $_->[1], 'Folha de pagamento da educação (SIOPE) (FNDE)' ] } @FOLHA_MUNICIPIO_COLUNAS ]);
}

# #512 (QZ-01): o ano padrão da folha para a UF: o último ano com 12 meses
# em algum município da UF com escolas; sem ano completo, o mais recente com
# escolas; UF sem folha por escola: undef.
sub siope_padrao_uf ($class, $cobertura) {
  my %meses;
  for my $m (@$cobertura) {
    for my $a (grep { $_->{escolas} > 0 } @{ $m->{anos} }) {
      $meses{ $a->{ano} } = $a->{meses} if ($meses{ $a->{ano} } // 0) < $a->{meses};
    }
  }
  my @anos = sort { $b <=> $a } keys %meses;
  my ($completo) = grep { $meses{$_} >= 12 } @anos;
  return defined $completo ? 0 + $completo : @anos ? 0 + $anos[0] : undef;
}

# #512 (QZ-01): escolas do recorte com folha, por ano.
sub contar_folha ($class, $dbh, $recorte) {
  my $anos = $class->anos($dbh);
  return {} unless defined $anos->{censo};
  my ($where, @b) = _where($recorte, $anos->{censo});
  my $rows = eval {
    $dbh->selectall_arrayref(qq{
      SELECT r.ano, count(DISTINCT e.co_entidade)
        FROM clean.censo_escolas e
        JOIN clean.remuneracao_municipal r ON r.cod_inep = e.co_entidade
       WHERE $where
       GROUP BY 1
    }, undef, @b);
  } // [];
  return { map { ($_->[0] => 0 + $_->[1]) } @$rows };
}

# Recorte: { uf (obrigatória), codigo_ibge?, rede? } → (sql, binds) do WHERE.
sub _where ($recorte, $ano_censo) {
  my $uf = $recorte->{uf} // croak 'UF obrigatória';
  croak "UF inválida: $uf" unless grep { $_ eq $uf } @UFS;
  my @w = ('e.nu_ano_censo = ?', 'e.tp_situacao_funcionamento = 1', 'e.sg_uf = ?');
  my @b = ($ano_censo, $uf);
  if (defined $recorte->{codigo_ibge}) {
    push @w, 'e.co_municipio = ?';
    push @b, 0 + $recorte->{codigo_ibge};
  }
  if (defined $recorte->{rede}) {
    my $deps = $REDE_SQL{ $recorte->{rede} } or croak "Rede inválida: $recorte->{rede}";
    push @w, 'e.tp_dependencia IN (' . join(',', @$deps) . ')';
  }
  return (join(' AND ', @w), @b);
}

sub contar ($class, $dbh, $recorte) {
  my $anos = $class->anos($dbh);
  return 0 unless defined $anos->{censo};
  my ($where, @b) = _where($recorte, $anos->{censo});
  my ($n) = $dbh->selectrow_array("SELECT count(*) FROM clean.censo_escolas e WHERE $where", undef, @b);
  return 0 + $n;
}

# Descrição de ano_ideb (#444, BA-01): o IDEB é cruzado com o Censo mais
# recente (o único carregado), e o dicionário diz. #514 (QY-01): a ressalva
# vale sempre que os anos forem diferentes, inclusive na edição mais recente
# do IDEB (2023 contra o Censo 2025), não só numa edição antiga.
sub _anos_por_extenso ($n) {
  my %ext = (1 => 'um ano', 2 => 'dois anos', 3 => 'três anos', 4 => 'quatro anos');
  return $ext{$n} // "$n anos";
}

sub descricao_ano_ideb ($class, $anos, $ano_ideb) {
  my $censo = $anos->{censo};
  return 'Edição do IDEB/SAEB'
    if !defined $ano_ideb || !defined $censo || $ano_ideb == $censo;
  my $dist = abs($censo - $ano_ideb);
  my $quando = $censo > $ano_ideb ? 'depois' : 'antes';
  my $texto = "Edição do IDEB/SAEB ($ano_ideb), cruzada com o Censo Escolar $censo ("
    . _anos_por_extenso($dist) . " $quando): a lista de escolas, a infraestrutura e a docência são de $censo";
  return $texto . ', e as escolas fechadas depois de ' . $ano_ideb . ' não entram. '
    . "Num modelo, o que vem do Censo foi medido depois do IDEB" if $censo > $ano_ideb;
  return $texto;
}

# #514 (QY-01): o INSE sai do questionário do SAEB; com o IDEB na base, diz
# se a edição é a mesma.
sub descricao_ano_inse ($class, $anos, $ano_ideb, $com_ideb) {
  my $inse = $anos->{inse};
  return 'Edição do SAEB do INSE' unless $com_ideb && defined $inse && defined $ano_ideb;
  return "Edição do SAEB do INSE ($inse), a mesma do IDEB" if $inse == $ano_ideb;
  return "Edição do SAEB do INSE ($inse), diferente da edição do IDEB ($ano_ideb): "
    . 'o INSE só existe na edição mais recente carregada';
}

# Colunas e blocos efetivos, na ordem do catálogo, mais as colunas de versão.
sub colunas ($class, $blocos, $anos, $ano_ideb, $ano_siope = undef) {
  my %quer = map { $_ => 1 } @$blocos;
  my @b = grep { $_->{fixo} || $quer{ $_->{id} } } @{ _blocos() };
  my @versao = (['ano_censo', $anos->{censo}, 'Ano do Censo Escolar', 'censo']);
  push @versao, ['ano_ideb', $ano_ideb, $class->descricao_ano_ideb($anos, $ano_ideb), 'ideb'] if $quer{desempenho};
  push @versao, ['ano_inse', $anos->{inse}, $class->descricao_ano_inse($anos, $ano_ideb, $quer{desempenho}), 'inse'] if $quer{inse};
  push @versao, ['ano_populacao', $anos->{populacao}, 'Ano da estimativa de população', 'ibge_populacao'] if $quer{porte};
  push @versao, ['ano_populacao_idade', $anos->{populacao_idade},
    'Ano do Censo Demográfico da população por idade (populacao_0_3 e populacao_4_5), anterior ao das matrículas', 'ibge_populacao_idade'] if $quer{porte};
  push @versao, ['versao_indice', $anos->{indices}, 'Versão da fórmula dos índices do EduMaps (o histórico está em Fontes e metodologia)', 'indices_edumaps'] if $quer{indices};
  push @versao, ['ano_siope', $ano_siope, 'Ano (exercício) da folha do SIOPE', 'siope'] if $quer{remuneracao};
  return (\@b, \@versao);
}

# Linhas da base: (cabeçalho, linhas como arrays, números como números).
sub linhas ($class, $dbh, $recorte, $blocos, $ano_ideb = undef, $ano_siope = undef) {
  my $anos = $class->anos($dbh);
  return ([], []) unless defined $anos->{censo};
  my ($bl, $versao) = $class->colunas($blocos, $anos, $ano_ideb, $ano_siope);
  my %tem = map { $_->{id} => 1 } @$bl;

  my ($where, @wb) = _where($recorte, $anos->{censo});
  my @sel = map { my $b = $_; map { "$_->[1] AS \"$_->[0]\"" } @{ $b->{colunas} } } @$bl;
  my @num = map { my $b = $_; map { $_->[3] } @{ $b->{colunas} } } @$bl;

  my ($joins, @jb) = ('');
  if ($tem{docencia}) {
    $joins .= ' LEFT JOIN clean.censo_docentes d ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = e.nu_ano_censo';
  }
  if ($tem{desempenho}) {
    my @piv;
    for my $e (@ETAPAS) {
      for my $m (@MEDIDAS_IDEB) {
        push @piv, "max($m->[1]) FILTER (WHERE etapa = '$e->[1]')::float8 AS $m->[0]_$e->[0]";
      }
    }
    $joins .= ' LEFT JOIN (SELECT id_escola, ' . join(', ', @piv)
      . ' FROM clean.ideb_notas_escolas WHERE ano = ? AND sg_uf = ? GROUP BY id_escola) i ON i.id_escola = e.co_entidade';
    push @jb, $ano_ideb, $recorte->{uf};
  }
  if ($tem{inse}) {
    $joins .= ' LEFT JOIN clean.inse x ON x.id_escola = e.co_entidade AND x.nu_ano_saeb = ?';
    push @jb, $anos->{inse} // -1;
  }
  if ($tem{matriculas}) {
    $joins .= ' LEFT JOIN clean.censo_matriculas mm ON mm.co_entidade = e.co_entidade AND mm.nu_ano_censo = e.nu_ano_censo';
  }
  if ($tem{indices}) {
    $joins .= ' LEFT JOIN clean.mv_escolas_scores s ON s.co_entidade = e.co_entidade AND s.nu_ano_censo = e.nu_ano_censo'
            . ' LEFT JOIN clean.censo_matriculas mt ON mt.co_entidade = e.co_entidade AND mt.nu_ano_censo = e.nu_ano_censo'
            . ' LEFT JOIN clean.censo_gestor gs ON gs.co_entidade = e.co_entidade AND gs.nu_ano_censo = e.nu_ano_censo';
  }
  if ($tem{remuneracao}) {
    $joins .= " LEFT JOIN ($SQL_FOLHA) f ON f.cod_inep = e.co_entidade";
    push @jb, undef, undef, $ano_siope // -1,   # meses incompletos (todos os municípios) e o ano
              $class->piso_magisterio($ano_siope // -1);   # #563: o piso do ano (ou vazio)
    # #572 (QI-02 da P3): a carga mais comum do município no ano e se ela não
    # parece em horas (as contas por 40 horas ficam vazias). Códigos de 6
    # dígitos e números vêm do banco; validados antes de entrar no SQL.
    my $sal = $class->salario_rede($dbh);
    my @cm;
    for my $k (sort keys %$sal) {
      my ($c6, $a) = split /\|/, $k;
      next unless defined $ano_siope && $a == $ano_siope && $c6 =~ /^\d{6}$/;
      my $carga = $sal->{$k}{carga_comum};
      push @cm, sprintf("('%s', %s, %s)", $c6, (defined $carga && $carga =~ /^[\d.]+$/ ? $carga : 'NULL'),
        (${ $sal->{$k}{carga_suspeita} } ? 'true' : 'false'));
    }
    $joins .= ' LEFT JOIN (' . (@cm ? 'VALUES ' . join(', ', @cm)
                                    : 'SELECT NULL::text, NULL::float8, NULL::boolean WHERE false')
            . ') AS cm(cod6, carga, suspeita) ON cm.cod6 = left(e.co_municipio::text, 6)';
    # #557: os meses incompletos do município no ano da folha
    $joins .= " LEFT JOIN (SELECT cod6, string_agg((ARRAY['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'])[mes], ', ' ORDER BY mes) AS meses FROM ($SQL_MESES) q WHERE ano = ? GROUP BY cod6) mi"
            . ' ON mi.cod6 = left(e.co_municipio::text, 6)';
    push @jb, undef, undef, $ano_siope // -1;
  }
  if ($tem{porte}) {
    $joins .= ' LEFT JOIN clean.populacao_municipal pm ON pm.codigo_ibge = e.co_municipio::text'
            . ' LEFT JOIN clean.populacao_idade pi ON pi.codigo_ibge = e.co_municipio::text'
            . ' AND pi.ano = (SELECT max(ano) FROM clean.populacao_idade)';
  }

  my $sql = 'SELECT ' . join(', ', @sel) . " FROM clean.censo_escolas e $joins WHERE $where"
          . ' ORDER BY e.no_municipio, e.no_entidade, e.co_entidade';
  my $rows = $dbh->selectall_arrayref($sql, undef, @jb, @wb);

  my @cab = ((map { my $b = $_; map { $_->[0] } @{ $b->{colunas} } } @$bl), map { $_->[0] } @$versao);
  my @v = map { $_->[1] } @$versao;
  my @out = map {
    my $r = $_;
    [ (map { $num[$_] && defined $r->[$_] ? 0 + $r->[$_] : $r->[$_] } 0 .. $#$r), @v ]
  } @$rows;
  return (\@cab, \@out, [ @num, map { $_->[0] eq 'versao_indice' ? 0 : 1 } @$versao ]);
}

# Nome da fonte no dicionário: "nome (órgão)"; base própria sem o órgão
# repetido (#467, RZ-02: era "Índices do EduMaps (EduMaps)").
sub _fonte_nome ($f) { $f->{proprio} ? $f->{nome} : "$f->{nome} ($f->{orgao})" }

# Dicionário: uma linha por coluna da base, com a fonte e o link oficial.
sub dicionario ($class, $dbh, $blocos, $ano_ideb = undef, $ano_siope = undef) {
  my $anos = $class->anos($dbh);
  my ($bl, $versao) = $class->colunas($blocos, $anos, $ano_ideb, $ano_siope);
  my %fonte = map { $_->{id} => $_ } @EduMaps::Fontes::CATALOGO;
  my %ano = (censo => $anos->{censo}, ideb => $ano_ideb, inse => $anos->{inse}, ibge_populacao => $anos->{populacao},
             ibge_populacao_idade => $anos->{populacao_idade},
             indices_edumaps => $anos->{censo}, siope => $ano_siope);
  my @linhas;
  for my $b (@$bl) {
    for my $c (@{ $b->{colunas} }) {
      # Coluna de outra fonte que a do bloco (#533: a população por idade no Porte).
      my $id = $c->[4] // $b->{fonte};
      my $f = $fonte{$id};
      push @linhas, [ $c->[0], $c->[2], $b->{label}, _fonte_nome($f), $ano{$id}, $f->{url} ];
    }
  }
  for my $v (@$versao) {
    my $f = $fonte{ $v->[3] };
    push @linhas, [ $v->[0], $v->[2], 'Versão dos dados', _fonte_nome($f), $v->[1], $f->{url} ];
  }
  return ([qw(coluna descricao bloco fonte ano url_fonte)], \@linhas);
}

# CSV para o Excel em PT-BR: ';', BOM, CRLF e vírgula decimal nos números.
sub csv ($class, $cab, $linhas, $num = []) {
  my $q = sub ($v) {
    return '' unless defined $v;
    $v = "$v";
    return $v =~ /[";\n\r]/ ? '"' . ($v =~ s/"/""/gr) . '"' : $v;
  };
  # Inteiro sai inteiro (população de 12 milhões não vira 1,2e+07).
  my $n = sub ($v) {
    return undef unless defined $v;
    return sprintf('%d', $v) if $v == int($v) && abs($v) < 1e15;
    return sprintf('%.6g', $v) =~ s/\./,/r;
  };
  # Coordenada (#452): 6 casas fixas (cerca de 0,1 m); 6 dígitos
  # significativos cortariam -10,123456 em -10,1235 (cerca de 11 m).
  my $coord = sub ($v) { defined $v ? sprintf('%.6f', $v) =~ s/\./,/r : undef };
  my @out = (join ';', map { $q->($_) } @$cab);
  for my $l (@$linhas) {
    push @out, join ';', map {
      my $f = $num->[$_] // 0;
      $q->($f eq 'coord' ? $coord->($l->[$_]) : $f ? $n->($l->[$_]) : $l->[$_])
    } 0 .. $#$l;
  }
  return "\x{FEFF}" . join("\r\n", @out) . "\r\n";
}

1;
