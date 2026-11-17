package EduMaps::BaseAnalise;
use Mojo::Base -strict, -signatures;
use utf8;
use Carp qw(croak);
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
  } @INDICES ), @DIVERSIDADE, @ATENDIMENTO, @GESTORA ];
}
sub indices_versao ($class) { $EduMaps::Model::Rank::School::INDICES_VERSAO }

my $DENOM = 'docentes da escola (qt_docentes)';
# Proporção sobre qt_doc_bas limitada a 1; vazia sem docentes (#469).
sub _ate_um ($num) {
  "CASE WHEN d.qt_doc_bas > 0 THEN LEAST(1, ($num)::float8 / d.qt_doc_bas) END";
}
my @DOCENCIA = (
  [qt_docentes             => 'd.qt_doc_bas', 'Docentes da educação básica da escola. Quem dá aula em mais de uma escola conta em cada uma (contagem do Censo Escolar)'],
  [prop_licenciatura       => 'd.qt_doc_bas_esco_sup_grad_licen::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com licenciatura ÷ $DENOM"],
  [prop_mestrado           => 'd.qt_doc_bas_esco_sup_pos_mestra::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com mestrado ÷ $DENOM"],
  [prop_doutorado          => 'd.qt_doc_bas_esco_sup_pos_douto::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com doutorado ÷ $DENOM"],
  [prop_efetivos           => 'd.qt_doc_bas_vinculo_concur::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes concursados (efetivos) ÷ $DENOM. Parte de 20% do índice de capacitação docente"],
  [prop_sem_especializacao => 'd.qt_doc_bas_espec_nenhum::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes sem especialização ÷ $DENOM"],
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
   "Formações continuadas dos docentes (soma das formações específicas do Censo) ÷ $DENOM, limitada a 1. Parte de 20% do índice de capacitação docente"],
);

# #471 (RT-03): o INSE só existe para escolas com alunos no SAEB.
my $INSE_VAZIO = 'Vazio: a escola não teve alunos avaliados no SAEB daquela edição. As privadas nunca têm INSE, e as creches e pré-escolas quase nunca';

# Cada bloco: colunas [nome, expressão SQL, descrição, numérica?] e a fonte.
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
      descricao => 'INEP, nome, município, UF, região, rede, localização (urbana ou rural) e as coordenadas da escola (sempre incluído).',
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
        ['latitude',    'e.latitude::float8',  'Latitude da escola, em graus decimais (WGS84), como declarada ao Censo Escolar, sem verificação; vazia quando o Censo não traz', 'coord'],
        ['longitude',   'e.longitude::float8', 'Longitude da escola, em graus decimais (WGS84), como declarada ao Censo Escolar, sem verificação; vazia quando o Censo não traz', 'coord'],
      ] },
    # #461 (RX-02): a oferta separa "não oferece a etapa" de "não teve IDEB".
    { id => 'etapas', label => 'Etapas oferecidas', fonte => 'censo',
      descricao => 'Se a escola oferece creche, pré-escola, anos iniciais, anos finais, ensino médio, EJA e educação profissional, e se tem classe especial exclusiva. Com o IDEB, separa "não oferece a etapa" de "não teve nota".',
      colunas => [ map { [$_->[0], $_->[1], $_->[2], 1] } @ETAPAS_OFERTA ] },
    { id => 'infraestrutura', label => 'Infraestrutura', fonte => 'censo',
      descricao => 'Água, energia, esgoto (e se a escola não tem água, energia ou esgoto), lixo, banheiro, biblioteca, laboratórios, quadra, internet e rampas.',
      colunas => [ map { [$_->[0], "e.$_->[0]", $_->[1], 1] } @INFRA ] },
    { id => 'docencia', label => 'Docência', fonte => 'censo',
      descricao => 'Número de docentes e proporções de licenciatura, mestrado, doutorado, efetivos, sem especialização, ensino superior, pós-graduação e formação continuada, sobre o total de docentes da escola (as quatro partes do índice de capacitação docente). Quem dá aula em mais de uma escola conta em cada uma.',
      colunas => [ map { [$_->[0], $_->[1], $_->[2], 1] } @DOCENCIA ] },
    { id => 'desempenho', label => 'IDEB e SAEB por etapa', fonte => 'ideb', usa_ano_ideb => 1,
      descricao => 'IDEB, notas e aprovação nos anos iniciais (_ai), finais (_af) e no ensino médio (_em), na edição escolhida. O IDEB falta sobretudo nas escolas pequenas, rurais e sem infraestrutura: marque também as etapas oferecidas.',
      colunas => \@ideb },
    # #465 (RY-01): os índices próprios, com a versão da fórmula.
    { id => 'indices', label => 'Índices do EduMaps', fonte => 'indices_edumaps',
      descricao => 'Os seis índices de 0 a 10 do EduMaps (infraestrutura, capacidade de atendimento, capacitação docente, diversidade discente, capacidade gestora e sustentabilidade), calculados a partir do Censo Escolar, e as partes dos índices de diversidade, de capacidade de atendimento e de capacidade gestora, com a versão da fórmula em versao_indice. Notas de versões diferentes não são comparáveis.',
      colunas => _indices_colunas() },
    { id => 'inse', label => 'Nível socioeconômico (INSE)', fonte => 'inse',
      descricao => 'INSE médio dos alunos e o nível (I a VIII), na edição mais recente do SAEB.',
      colunas => [
        ['inse_media',         'x.media_inse', "INSE médio dos alunos da escola. $INSE_VAZIO", 1],
        ['inse_classificacao', 'x.inse_classificacao', "Nível do INSE (I a VIII). $INSE_VAZIO", 0],
      ] },
    { id => 'porte', label => 'Porte do município', fonte => 'ibge_populacao',
      descricao => 'População estimada do município e a classe de tamanho do IBGE.',
      colunas => [
        ['populacao_municipio', 'pm.populacao_estimada', 'População estimada do município', 1],
        ['porte_municipio', EduMaps::Porte->case_sql('pm.populacao_estimada'), 'Classe de tamanho da população do IBGE (ex.: 10_20mil = de 10 mil a 20 mil habitantes)', 0],
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
  return {
    censo => defined $censo ? 0 + $censo : undef,
    inse  => defined $inse ? 0 + $inse : undef,
    ideb  => [ map { 0 + $_ } @$ideb ],
    populacao => $pop,
    indices => $class->indices_versao,
  };
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

# Descrição de ano_ideb (#444, BA-01): com uma edição antiga, o IDEB é
# cruzado com o Censo mais recente (o único carregado), e o dicionário diz.
sub descricao_ano_ideb ($class, $anos, $ano_ideb) {
  my $ultimo = $anos->{ideb}[0];
  return 'Edição do IDEB/SAEB'
    if !defined $ano_ideb || !defined $ultimo || $ano_ideb >= $ultimo || !defined $anos->{censo};
  return "Edição do IDEB/SAEB ($ano_ideb), cruzada com o Censo Escolar $anos->{censo}: "
       . "a lista de escolas, a infraestrutura e a docência são de $anos->{censo}, "
       . "e as escolas fechadas depois de $ano_ideb não entram";
}

# Colunas e blocos efetivos, na ordem do catálogo, mais as colunas de versão.
sub colunas ($class, $blocos, $anos, $ano_ideb) {
  my %quer = map { $_ => 1 } @$blocos;
  my @b = grep { $_->{fixo} || $quer{ $_->{id} } } @{ _blocos() };
  my @versao = (['ano_censo', $anos->{censo}, 'Ano do Censo Escolar', 'censo']);
  push @versao, ['ano_ideb', $ano_ideb, $class->descricao_ano_ideb($anos, $ano_ideb), 'ideb'] if $quer{desempenho};
  push @versao, ['ano_inse', $anos->{inse}, 'Edição do SAEB do INSE', 'inse'] if $quer{inse};
  push @versao, ['ano_populacao', $anos->{populacao}, 'Ano da estimativa de população', 'ibge_populacao'] if $quer{porte};
  push @versao, ['versao_indice', $anos->{indices}, 'Versão da fórmula dos índices do EduMaps (o histórico está em Fontes e metodologia)', 'indices_edumaps'] if $quer{indices};
  return (\@b, \@versao);
}

# Linhas da base: (cabeçalho, linhas como arrays, números como números).
sub linhas ($class, $dbh, $recorte, $blocos, $ano_ideb = undef) {
  my $anos = $class->anos($dbh);
  return ([], []) unless defined $anos->{censo};
  my ($bl, $versao) = $class->colunas($blocos, $anos, $ano_ideb);
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
  if ($tem{indices}) {
    $joins .= ' LEFT JOIN clean.mv_escolas_scores s ON s.co_entidade = e.co_entidade AND s.nu_ano_censo = e.nu_ano_censo'
            . ' LEFT JOIN clean.censo_matriculas mt ON mt.co_entidade = e.co_entidade AND mt.nu_ano_censo = e.nu_ano_censo'
            . ' LEFT JOIN clean.censo_gestor gs ON gs.co_entidade = e.co_entidade AND gs.nu_ano_censo = e.nu_ano_censo';
  }
  if ($tem{porte}) {
    $joins .= ' LEFT JOIN clean.populacao_municipal pm ON pm.codigo_ibge = e.co_municipio::text';
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
sub dicionario ($class, $dbh, $blocos, $ano_ideb = undef) {
  my $anos = $class->anos($dbh);
  my ($bl, $versao) = $class->colunas($blocos, $anos, $ano_ideb);
  my %fonte = map { $_->{id} => $_ } @EduMaps::Fontes::CATALOGO;
  my %ano = (censo => $anos->{censo}, ideb => $ano_ideb, inse => $anos->{inse}, ibge_populacao => $anos->{populacao},
             indices_edumaps => $anos->{censo});
  my @linhas;
  for my $b (@$bl) {
    my $f = $fonte{ $b->{fonte} };
    push @linhas, [ $_->[0], $_->[2], $b->{label}, _fonte_nome($f), $ano{ $b->{fonte} }, $f->{url} ]
      for @{ $b->{colunas} };
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
