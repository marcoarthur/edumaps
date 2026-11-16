package EduMaps::BaseAnalise;
use Mojo::Base -strict, -signatures;
use utf8;
use Carp qw(croak);
use EduMaps::Fontes;
use EduMaps::Porte;

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

# Infraestrutura: as mesmas 11 colunas do conjunto pronto do agrupamento.
my @INFRA = (
  [in_agua_potavel            => 'Tem água potável (1 = sim, 0 = não)'],
  [in_energia_rede_publica    => 'Energia da rede pública (1 = sim, 0 = não)'],
  [in_esgoto_rede_publica     => 'Esgoto na rede pública (1 = sim, 0 = não)'],
  [in_lixo_servico_coleta     => 'Coleta de lixo pelo serviço público (1 = sim, 0 = não)'],
  [in_banheiro                => 'Tem banheiro (1 = sim, 0 = não)'],
  [in_biblioteca              => 'Tem biblioteca (1 = sim, 0 = não)'],
  [in_laboratorio_ciencias    => 'Tem laboratório de ciências (1 = sim, 0 = não)'],
  [in_laboratorio_informatica => 'Tem laboratório de informática (1 = sim, 0 = não)'],
  [in_quadra_esportes         => 'Tem quadra de esportes (1 = sim, 0 = não)'],
  [in_internet                => 'Tem internet (1 = sim, 0 = não)'],
  [in_acessibilidade_rampas   => 'Tem rampas de acessibilidade (1 = sim, 0 = não)'],
);

# Docência: as mesmas fórmulas do agrupamento (Task::Clustering). A contagem
# é a do Censo Escolar, por escola: quem dá aula em mais de uma escola conta
# em cada uma (#444, BA-04).
my $DENOM = 'docentes da escola (qt_docentes)';
my @DOCENCIA = (
  [qt_docentes             => 'd.qt_doc_bas', 'Docentes da educação básica da escola. Quem dá aula em mais de uma escola conta em cada uma (contagem do Censo Escolar)'],
  [prop_licenciatura       => 'd.qt_doc_bas_esco_sup_grad_licen::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com licenciatura ÷ $DENOM"],
  [prop_mestrado           => 'd.qt_doc_bas_esco_sup_pos_mestra::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com mestrado ÷ $DENOM"],
  [prop_doutorado          => 'd.qt_doc_bas_esco_sup_pos_douto::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes com doutorado ÷ $DENOM"],
  [prop_efetivos           => 'd.qt_doc_bas_vinculo_concur::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes concursados (efetivos) ÷ $DENOM"],
  [prop_sem_especializacao => 'd.qt_doc_bas_espec_nenhum::float8 / NULLIF(d.qt_doc_bas, 0)', "Docentes sem especialização ÷ $DENOM"],
);

# Cada bloco: colunas [nome, expressão SQL, descrição, numérica?] e a fonte.
sub _blocos {
  my @ideb;
  for my $e (@ETAPAS) {
    my ($suf, $etapa, $nome_etapa) = @$e;
    for my $m (@MEDIDAS_IDEB) {
      my ($col, $origem, $desc) = @$m;
      push @ideb, ["${col}_$suf", "i.${col}_$suf", "$desc, $nome_etapa", 1];
    }
  }
  return [
    { id => 'identificacao', label => 'Identificação', fixo => 1, fonte => 'censo',
      descricao => 'INEP, nome, município, UF, rede e localização da escola (sempre incluído).',
      colunas => [
        ['inep',        'e.co_entidade::text', 'Código INEP da escola', 0],
        ['escola',      'e.no_entidade', 'Nome da escola', 0],
        ['codigo_ibge', 'e.co_municipio::text', 'Código IBGE do município', 0],
        ['municipio',   'e.no_municipio', 'Município', 0],
        ['uf',          'e.sg_uf', 'UF', 0],
        ['rede',        q{CASE e.tp_dependencia WHEN 1 THEN 'Federal' WHEN 2 THEN 'Estadual' WHEN 3 THEN 'Municipal' WHEN 4 THEN 'Privada' END}, 'Rede (dependência administrativa)', 0],
        ['localizacao', q{CASE e.tp_localizacao WHEN 1 THEN 'Urbana' WHEN 2 THEN 'Rural' END}, 'Localização (urbana ou rural)', 0],
      ] },
    { id => 'infraestrutura', label => 'Infraestrutura', fonte => 'censo',
      descricao => 'Água, energia, esgoto, lixo, banheiro, biblioteca, laboratórios, quadra, internet e rampas.',
      colunas => [ map { [$_->[0], "e.$_->[0]", $_->[1], 1] } @INFRA ] },
    { id => 'docencia', label => 'Docência', fonte => 'censo',
      descricao => 'Número de docentes e proporções de formação, mestrado, doutorado, efetivos e sem especialização, sobre o total de docentes da escola. Quem dá aula em mais de uma escola conta em cada uma.',
      colunas => [ map { [$_->[0], $_->[1], $_->[2], 1] } @DOCENCIA ] },
    { id => 'desempenho', label => 'IDEB e SAEB por etapa', fonte => 'ideb', usa_ano_ideb => 1,
      descricao => 'IDEB, notas e aprovação nos anos iniciais (_ai), finais (_af) e no ensino médio (_em), na edição escolhida.',
      colunas => \@ideb },
    { id => 'inse', label => 'Nível socioeconômico (INSE)', fonte => 'inse',
      descricao => 'INSE médio dos alunos e o nível (I a VIII), na edição mais recente do SAEB.',
      colunas => [
        ['inse_media',         'x.media_inse', 'INSE médio dos alunos da escola', 1],
        ['inse_classificacao', 'x.inse_classificacao', 'Nível do INSE (I a VIII)', 0],
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
  return (\@cab, \@out, [ @num, (1) x @$versao ]);
}

# Dicionário: uma linha por coluna da base, com a fonte e o link oficial.
sub dicionario ($class, $dbh, $blocos, $ano_ideb = undef) {
  my $anos = $class->anos($dbh);
  my ($bl, $versao) = $class->colunas($blocos, $anos, $ano_ideb);
  my %fonte = map { $_->{id} => $_ } @EduMaps::Fontes::CATALOGO;
  my %ano = (censo => $anos->{censo}, ideb => $ano_ideb, inse => $anos->{inse}, ibge_populacao => $anos->{populacao});
  my @linhas;
  for my $b (@$bl) {
    my $f = $fonte{ $b->{fonte} };
    push @linhas, [ $_->[0], $_->[2], $b->{label}, "$f->{nome} ($f->{orgao})", $ano{ $b->{fonte} }, $f->{url} ]
      for @{ $b->{colunas} };
  }
  for my $v (@$versao) {
    my $f = $fonte{ $v->[3] };
    push @linhas, [ $v->[0], $v->[2], 'Versão dos dados', "$f->{nome} ($f->{orgao})", $v->[1], $f->{url} ];
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
  my @out = (join ';', map { $q->($_) } @$cab);
  for my $l (@$linhas) {
    push @out, join ';', map { $q->($num->[$_] ? $n->($l->[$_]) : $l->[$_]) } 0 .. $#$l;
  }
  return "\x{FEFF}" . join("\r\n", @out) . "\r\n";
}

1;
