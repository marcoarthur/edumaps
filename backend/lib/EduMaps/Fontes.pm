package EduMaps::Fontes;
use Mojo::Base -strict, -signatures;
use utf8;
use Mojo::JSON qw(decode_json);

# ============================================================================
# CATÁLOGO PÚBLICO DAS FONTES (#428, AN-08)
# ============================================================================
#
# As bases por trás das análises públicas, com o que pode ir a público: nome,
# órgão, descrição, links oficiais, o ano/período do dado (calculado da
# própria tabela) e a última carga registrada em clean.import_metadata.
#
# O que NUNCA sai daqui (decisão do developer, 2026-11-15): caminhos internos
# dos arquivos, notas de engenharia e situação de licença não verificada ou
# pendente. Licença só aparece quando verificada; senão o texto aponta os
# termos do próprio órgão.
#
# Carga sem registro (IDEB e folha, carregados antes do import_metadata)
# aparece como "não registrada": nada é inventado para trás.

our @CATALOGO = (
  {
    id        => 'censo',
    nome      => 'Censo Escolar',
    orgao     => 'INEP',
    descricao => 'Escolas, matrículas, docentes, gestores e infraestrutura de todas as escolas de educação básica do país.',
    url       => 'https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/censo-escolar',
    metodologia => 'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
    tabelas   => [qw(clean.censo_escolas clean.censo_docentes clean.censo_matriculas)],
    periodo_sql => 'SELECT max(nu_ano_censo)::text, max(nu_ano_censo)::text FROM clean.censo_escolas',
    # #539: ranking_atendimento = o ranking de redes na taxa de atendimento
    # da educação infantil (matrículas do Censo sobre a população por idade).
    telas     => [qw(comparacao_redes perfil_escola ranking ranking_atendimento agrupamento busca base_analise)],
  },
  {
    id        => 'ideb',
    nome      => 'IDEB e SAEB',
    orgao     => 'INEP',
    descricao => 'Índice de Desenvolvimento da Educação Básica e notas do SAEB por escola e etapa, nas edições bienais.',
    url       => 'https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/ideb',
    metodologia => 'https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/ideb/resultados',
    tabelas   => [qw(clean.ideb_notas_escolas)],
    periodo_sql => 'SELECT min(ano)::text, max(ano)::text FROM clean.ideb_notas_escolas',
    telas     => [qw(comparacao_redes perfil_escola ranking agrupamento base_analise)],
  },
  {
    id        => 'inse',
    nome      => 'Indicador de Nível Socioeconômico (INSE)',
    orgao     => 'INEP',
    descricao => 'Nível socioeconômico médio dos estudantes de cada escola, a partir dos questionários do SAEB.',
    url       => 'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/indicadores-educacionais/nivel-socioeconomico',
    metodologia => 'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/indicadores-educacionais/nivel-socioeconomico',
    tabelas   => [qw(clean.inse)],
    periodo_sql => 'SELECT max(nu_ano_saeb)::text, max(nu_ano_saeb)::text FROM clean.inse',
    telas     => [qw(perfil_escola ranking base_analise)],
  },
  {
    id        => 'siope',
    nome      => 'Folha de pagamento da educação (SIOPE)',
    orgao     => 'FNDE',
    descricao => 'Remuneração dos profissionais da educação declarada pelos municípios ao SIOPE. Cobertura parcial: só os municípios já carregados, listados abaixo com os anos.',
    url       => 'https://www.gov.br/fnde/pt-br/assuntos/sistemas/siope',
    metodologia => 'https://www.gov.br/fnde/pt-br/assuntos/sistemas/siope',
    tabelas   => [qw(clean.remuneracao_municipal)],
    periodo_sql => 'SELECT min(ano)::text, max(ano)::text FROM clean.remuneracao_municipal',
    telas     => [qw(financeiro folha base_analise)],
  },
  {
    id        => 'ibge_malha',
    nome      => 'Malha municipal',
    orgao     => 'IBGE',
    descricao => 'Limites e códigos dos municípios, usados nos mapas e nos recortes por município.',
    url       => 'https://www.ibge.gov.br/geociencias/organizacao-do-territorio/malhas-territoriais.html',
    metodologia => 'https://www.ibge.gov.br/geociencias/organizacao-do-territorio/malhas-territoriais.html',
    tabelas   => [qw(clean.municipios_sp)],
    periodo   => ['2024', '2024'],
    telas     => [qw(comparacao_redes agrupamento busca)],
  },
  {
    id        => 'ibge_populacao',
    nome      => 'Estimativa da população dos municípios',
    orgao     => 'IBGE',
    descricao => 'População estimada de cada município, usada para o porte do município no ranking de redes.',
    url       => 'https://www.ibge.gov.br/estatisticas/sociais/populacao/9103-estimativas-de-populacao.html',
    metodologia => 'https://www.ibge.gov.br/estatisticas/sociais/populacao/9103-estimativas-de-populacao.html',
    tabelas   => [qw(clean.populacao_municipal)],
    # A tabela não guarda o ano; a carga é a estimativa de 2025
    # (data_pipeline/deploy/raw_populacao.sql, pop_2025_mun.csv).
    periodo   => ['2025', '2025'],
    telas     => [qw(ranking ranking_atendimento base_analise)],
  },
  # #533 (QP-01 da P2): a população por idade do Censo 2022, base da taxa
  # de atendimento da creche e da pré-escola (job IBGEPopulacaoIdade).
  {
    id        => 'ibge_populacao_idade',
    nome      => 'População por idade (Censo Demográfico)',
    orgao     => 'IBGE',
    descricao => 'Crianças e jovens de cada idade por município, contados no Censo Demográfico, '
      . 'usados na taxa de atendimento da creche (0 a 3 anos) e da pré-escola (4 e 5 anos).',
    url       => 'https://sidra.ibge.gov.br/tabela/9514',
    metodologia => 'https://www.ibge.gov.br/estatisticas/sociais/trabalho/22827-censo-demografico-2022.html',
    tabelas   => [qw(clean.populacao_idade)],
    periodo_sql => 'SELECT min(ano)::text, max(ano)::text FROM clean.populacao_idade',
    telas     => [qw(comparacao_redes ranking_atendimento base_analise)],
  },
  # #462 (RX-01): os seis índices calculados pelo EduMaps a partir do Censo.
  # Não é base de terceiros: a versão e o histórico vêm do registro em
  # EduMaps::Model::Rank::School, e a "carga" é a última materialização.
  {
    id        => 'indices_edumaps',
    nome      => 'Índices do EduMaps',
    orgao     => 'EduMaps',
    proprio   => 1,
    descricao => 'Seis índices de 0 a 10 por escola, calculados pelo EduMaps a partir do Censo Escolar: '
      . 'infraestrutura, capacidade de atendimento, capacitação docente, diversidade discente, '
      . 'capacidade gestora e sustentabilidade. Cada um é uma média ponderada de itens do Censo; '
      . 'item sem resposta conta como ausente. Para citar, use a versão abaixo.',
    url       => 'https://github.com/marcoarthur/edumaps/blob/main/docs/ajuda/comunidade/rankings.md#o-que-cada-%C3%ADndice-mede',
    metodologia => 'https://github.com/marcoarthur/edumaps/blob/main/docs/analises/ivet.md#22-sistema-b--cleanmv_escolas_scores-mv--can%C3%B4nico',
    tabelas   => [],
    periodo_sql => 'SELECT max(nu_ano_censo)::text, max(nu_ano_censo)::text FROM clean.mv_escolas_scores',
    carga_sql => q{SELECT to_char(max(data_atualizacao) AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD') FROM clean.mv_escolas_scores},
    telas     => [qw(ranking perfil_escola agrupamento)],
    versao_de => 'indices',
  },
  # #489 (RK-02): o IVET, índice próprio de vulnerabilidade de acesso. A
  # versão e o histórico vêm de EduMaps::Model::Ivet::Versao (espelho do
  # `ivet_versao()` do pacote R); a "carga" é o último cálculo do painel.
  {
    id        => 'ivet_edumaps',
    nome      => 'IVET do EduMaps',
    orgao     => 'EduMaps',
    proprio   => 1,
    descricao => 'Índice de vulnerabilidade de acesso de 0 a 1 por escola (maior = mais barreira), '
      . 'calculado pelo EduMaps como a média de sete blocos: a própria escola, o entorno socioeconômico, '
      . 'o acesso, a saúde, a segurança, o meio ambiente e os recursos do município. '
      . 'Só vira número quando a região tem os blocos de acesso, saúde e segurança; '
      . 'bloco sem dado fica fora da média. Para citar, use a versão abaixo.',
    url       => 'https://github.com/marcoarthur/edumaps/blob/main/docs/ajuda/gestor/ivet.md',
    metodologia => 'https://github.com/marcoarthur/edumaps/blob/main/docs/analises/ivet.md',
    tabelas   => [],
    periodo_sql => 'SELECT min(nu_ano_censo)::text, max(nu_ano_censo)::text FROM analytics.ivet_escola',
    carga_sql => q{SELECT to_char(max(calculado_em) AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD') FROM analytics.ivet_escola},
    telas     => [qw(painel_escola)],
    versao_de => 'ivet',
  },
);

# Versão e histórico de uma base própria: `indices` (#462) ou `ivet` (#489).
sub versao_propria ($class, $de) {
  return $class->ivet_versao if ($de // '') eq 'ivet';
  return $class->indices_versao;
}

# Versão e histórico do IVET (#489).
sub ivet_versao ($class) {
  require EduMaps::Model::Ivet::Versao;
  no warnings 'once';
  my @hist = @EduMaps::Model::Ivet::Versao::HISTORICO;
  return {
    versao    => $EduMaps::Model::Ivet::Versao::VERSAO,
    data      => $hist[0]{data},
    historico => [ map { +{ %$_ } } @hist ],
  };
}

# Versão e histórico dos índices próprios (#462). `require` aqui, e não `use`
# no topo: o Model::Rank::School já usa este módulo.
sub indices_versao ($class) {
  require EduMaps::Model::Rank::School;
  no warnings 'once';
  return {
    versao    => $EduMaps::Model::Rank::School::INDICES_VERSAO,
    data      => $EduMaps::Model::Rank::School::INDICES_HISTORICO[0]{data},
    historico => [ map { +{ %$_ } } @EduMaps::Model::Rank::School::INDICES_HISTORICO ],
  };
}

# Licença que pode ir a público: preenchida e sem marca de pendência.
sub licenca_publica ($texto) {
  return undef unless defined $texto && length $texto && $texto ne '-';
  return undef if $texto =~ /n[ãa]o verificad|pendente|decis[ãa]o|exige/i;
  return $texto;
}

# Arquivos do manifesto sem o caminho interno: url, sha256, bytes, data.
sub arquivos_publicos ($manifesto) {
  return [] unless defined $manifesto;
  my $lista = ref $manifesto ? $manifesto : eval { decode_json($manifesto) };
  return [] unless ref $lista eq 'ARRAY';
  return [
    map { +{ url => $_->{url}, sha256 => $_->{sha256}, bytes => $_->{bytes}, baixado_em => $_->{baixado_em} } }
    grep { ref $_ eq 'HASH' && $_->{sha256} } @$lista
  ];
}

# Resolve o catálogo contra o banco. `$dbh` = DBI handle.
sub resolver ($class, $dbh) {
  my @out;
  for my $f (@CATALOGO) {
    my ($ini, $fim) = @{ $f->{periodo} // [] };
    if ($f->{periodo_sql}) {
      ($ini, $fim) = eval { $dbh->selectrow_array($f->{periodo_sql}) };
    }

    # Carga mais recente entre as tabelas da base que tenham registro.
    my $carga;
    for my $tabela (@{ $f->{tabelas} }) {
      my $row = eval {
        $dbh->selectrow_hashref(q{
          SELECT table_name,
                 to_char(COALESCE(retrieved_at, import_timestamp) AT TIME ZONE 'America/Sao_Paulo', 'YYYY-MM-DD') AS data,
                 COALESCE(retrieved_at, import_timestamp) AS ts,
                 source_license, raw_manifest::text AS manifesto, ultimo_status
            FROM clean.import_metadata
           WHERE table_name = ? AND COALESCE(ultimo_status, 'ok') = 'ok'
        }, undef, $tabela);
      };
      next unless $row;
      $carga = $row if !$carga || ($row->{ts} // '') gt ($carga->{ts} // '');
    }

    # Base própria (#462): a data da última materialização, sem arquivos.
    if (!$carga && $f->{carga_sql}) {
      my ($data) = eval { $dbh->selectrow_array($f->{carga_sql}) };
      $carga = { data => $data } if $data;
    }

    push @out, {
      (map { $_ => $f->{$_} } qw(id nome orgao descricao url metodologia telas)),
      ($f->{proprio} ? (proprio => \1, %{ $class->versao_propria($f->{versao_de}) }) : ()),
      periodo => {
        inicio => $ini,
        fim    => $fim,
        texto  => !defined $fim ? undef : (defined $ini && $ini ne $fim ? "$ini–$fim" : "$fim"),
      },
      carga => $carga ? {
        data     => $carga->{data},
        arquivos => arquivos_publicos($carga->{manifesto}),
      } : undef,
      licenca => $carga ? licenca_publica($carga->{source_license}) : undef,
      # #512 (QZ-01): a folha do SIOPE cobre poucos municípios; a lista,
      # com os anos, os meses e as escolas de cada um, fica no cartão.
      ($f->{id} eq 'siope' ? (cobertura => do {
        require EduMaps::BaseAnalise;
        EduMaps::BaseAnalise->cobertura_siope($dbh);
      }) : ()),
    };
  }
  return \@out;
}

# Versão dos dados de algumas bases, para guardar junto de um resultado
# (ex.: execução do agrupamento): { censo => {periodo, carga}, ... }.
sub versao ($class, $dbh, @ids) {
  my %quer = map { $_ => 1 } @ids;
  return {
    map { $_->{id} => { periodo => $_->{periodo}{texto}, carga => $_->{carga} ? $_->{carga}{data} : undef } }
    grep { $quer{ $_->{id} } } @{ $class->resolver($dbh) }
  };
}

1;
