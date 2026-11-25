package EduMaps::Roles::Business::School::Finance;
use Mojo::Base -role, -signatures;
use Mojo::Exception qw(raise);
use DateTime;
use DateTime::Format::Strptime;
use Carp qw(croak);
use EduMaps::BaseAnalise ();   # #557: meses incompletos da folha
use Mojo::Collection ();

requires qw(schema default_columns);

with 'EduMaps::Model::Role::CensoLabels';   # rótulos canônicos (issue #228)

has parser => sub {
  DateTime::Format::Strptime->new(
    pattern   => '%m-%Y',
    locale    => 'pt_BR',
    on_error  => 'croak',
  );
};

# #491 (RJ-01): a pessoa é o CPF mascarado E o nome. O SIOPE publica o CPF
# como `xxx.NNN.NNN-xx`; dos seis dígitos, o último é a região fiscal, quase
# sempre a mesma no município. Sobram ~100 mil combinações, e contar só pelo
# CPF juntava pessoas diferentes (Cuiabá 2025: 10.120 em vez de 10.557).
# Mesma chave do perfil da cidade (City::Profile).
our $PESSOA = '(cpf, nome_profissional)';

sub payroll($self, $cod_inep, $dt = DateTime->now(locale => 'pt')) {
  my $rs = $self->schema->resultset('Escolas');

  my $SQL =<<~'EOQ';
  WITH dados_escola AS (
      SELECT DISTINCT
          e.escola,
          e.codigo_inep,
          e.uf,
          e.municipio,
          e.localizacao,
          e.endereco,
          e.telefone,
          e.dependencia_administrativa,
          e.porte_escola
      FROM clean.escolas e
      WHERE e.codigo_inep = :cod_inep
  ),
  totais_gerais AS (
      SELECT 
          COUNT(DISTINCT (r.cpf, r.nome_profissional)) AS total_profissionais,
          COUNT(*) AS total_registros,
          SUM(r.salario_total) AS total_salario_geral,
          ROUND(AVG(r.salario_total), 2) AS media_salario
      FROM clean.remuneracao_municipal r
      WHERE r.cod_inep = :cod_inep
        AND r.ano = :ano
        AND r.mes = :mes
  ),
  profissionais_detalhados AS (
      SELECT 
          JSON_AGG(
              JSONB_BUILD_OBJECT(
                  'nome', r.nome_profissional,
                  'cpf', r.cpf,
                  'categoria', r.categoria,
                  'tipo', r.tipo,
                  'segmento_ensino', r.segmento_ensino,
                  'carga_horaria', r.carga_horaria,
                  'situacao', r.situacao,
                  'salario_base', r.salario_base,
                  'salario_fundeb_max', r.salario_fundeb_max,
                  'salario_fundeb_min', r.salario_fundeb_min,
                  'salario_outros', r.salario_outros,
                  'salario_total', r.salario_total
              )
              ORDER BY r.categoria, r.nome_profissional
          ) AS profissionais
      FROM clean.remuneracao_municipal r
      WHERE r.cod_inep = :cod_inep
        AND r.ano = :ano
        AND r.mes = :mes
  ),
  resumo_categoria AS (
      SELECT 
          JSON_AGG(
              JSONB_BUILD_OBJECT(
                  'categoria', categoria,
                  'profissionais', profissionais,
                  'total_salarios', total_salarios
              )
          ) AS resumo_categoria
      FROM (
          SELECT 
              categoria,
              COUNT(DISTINCT (cpf, nome_profissional)) AS profissionais,
              SUM(salario_total) AS total_salarios
          FROM clean.remuneracao_municipal
          WHERE cod_inep = :cod_inep
            AND ano = :ano
            AND mes = :mes
          GROUP BY categoria
          ORDER BY categoria
      ) cat
  ),
  resumo_segmento AS (
      SELECT 
          JSON_AGG(
              JSONB_BUILD_OBJECT(
                  'segmento', segmento_ensino,
                  'profissionais', profissionais,
                  'total_salarios', total_salarios
              )
          ) AS resumo_segmento
      FROM (
          SELECT 
              segmento_ensino,
              COUNT(DISTINCT (cpf, nome_profissional)) AS profissionais,
              SUM(salario_total) AS total_salarios
          FROM clean.remuneracao_municipal
          WHERE cod_inep = :cod_inep
            AND ano = :ano
            AND mes = :mes
          GROUP BY segmento_ensino
          ORDER BY segmento_ensino
      ) seg
  )
  SELECT 
      e.*,
      :ano AS ano,
      :mes AS mes,
      t.*,
      p.profissionais,
      c.resumo_categoria,
      s.resumo_segmento
  FROM 
      dados_escola e
  CROSS JOIN 
      totais_gerais t
  CROSS JOIN 
      profissionais_detalhados p
  CROSS JOIN 
      resumo_categoria c
  CROSS JOIN 
      resumo_segmento s
  EOQ

  my ($year, $month) = ($dt->year, ucfirst($dt->month_name));
  my $params = {cod_inep => $cod_inep , ano => $year, mes => $month};
  my $resolved = $self->resolve_bindings($SQL, $params);
  my ($aggregates, $school_data) = (
    [qw(profissionais resumo_segmento resumo_categoria)],
    [qw(ano mes escola codigo_inep endereco telefone dependencia_administrativa)]
  );

  my $payroll = $rs->custom_query(
    $resolved->{sql},
    [@$aggregates, @$school_data],
    $resolved->{bind_values},
  )->as_hash->first;

  return unless $payroll;

  # reorganize school data under escola key
  my %data = map { 
    my ($k, $v) = ($_ , delete $payroll->{$_});
    $k => $v;
  } @$school_data;
  $payroll->{escola} = \%data;

  return $payroll;

  # unless ($payroll) {
  #   return $self->json->encode({
  #       error => "Nenhum dado encontrado para a escola $cod_inep em $month/$year",
  #       escola => $cod_inep,
  #       periodo => "$month/$year"
  #     });
  # }
  #
  # my $null = "null";
  # my %dados_escola = map { $_ => $payroll->{$_} } @$school_data;
  # my $json = sprintf q/{"escola":%s, "profissionais":%s, "resumo_categoria":%s, "resumo_segmento":%s}/,
  # $self->json->encode(\%dados_escola),
  # $payroll->{profissionais}     || $null,
  # $payroll->{resumo_categoria}  || $null,
  # $payroll->{resumo_segmento}   || $null;
  #
  # return $json;
}

sub payroll_monthly($self, $cod_inep, $months, $year) {
  my @dates = map { 
    raise 'EduMaps::Exception::Date', "$_ month is out of range" if ($_ < 1 || $_ > 12);
    DateTime->new(year => $year, month => $_, locale => 'pt');
  } $months->@*;
  my @reports = map {$self->payroll($cod_inep, $_)} @dates;
  return sprintf "[%s]", join(',', @reports);
}

sub school_payroll($self, $params) {
  croak "need date %m-%Y" unless $params->{date};
  croak "need cod_inep" unless $params->{cod_inep};

  my $rs = $self->schema->resultset('RemuneracaoMunicipal');
  my $dt = $self->parser->parse_datetime($params->{date});
  my ($year, $month) = ($dt->year, ucfirst($dt->month_name));
  my $cod = $params->{cod_inep};

  my $results = $rs->search_rs({ano => $year, mes => $month, cod_inep => $cod})
  ->as_hash->get_all->each(
    # force numeric values
    sub {
      $_->{salario_base} += 0;
      $_->{salario_total} += 0;
      $_->{salario_fundeb_max} += 0;
      $_->{salario_fundeb_min} += 0;
      $_->{salario_outros} += 0;
    }
  );

  return $results;
}

# #585 (QE-01 da P2): a folha detalhada do total da Secretaria (código
# 99999999) do município da escola, no mês: as pessoas sem escola informada
# no SIOPE. Só para escola da rede municipal (o SIOPE é a folha municipal).
# Pública, pela mesma decisão da folha por escola.
sub secretaria_payroll($self, $params) {
  croak "need date %m-%Y" unless $params->{date};
  croak "need cod_inep" unless $params->{cod_inep};
  my $siope = $self->siope_status($params->{cod_inep});
  return Mojo::Collection->new unless $siope->{habilitado};

  my $dt = $self->parser->parse_datetime($params->{date});
  my ($year, $month) = ($dt->year, ucfirst($dt->month_name));
  my $results = $self->schema->resultset('RemuneracaoMunicipal')
    ->search_rs({ ano => $year, mes => $month, cod_inep => 99999999, cod_municipio => "$siope->{cod_municipio}" })
    ->as_hash->get_all->each(sub {
      $_->{salario_base} += 0;
      $_->{salario_total} += 0;
      $_->{salario_fundeb_max} += 0;
      $_->{salario_fundeb_min} += 0;
      $_->{salario_outros} += 0;
    });
  return $results;
}

sub payroll_dates($self, $params) {
  croak "need cod_inep" unless $params->{cod_inep};
  my %months = (
      'Janeiro'   => 1,
      'Fevereiro' => 2,
      'Março'     => 3,
      'Abril'     => 4,
      'Maio'      => 5,
      'Junho'     => 6,
      'Julho'     => 7,
      'Agosto'    => 8,
      'Setembro'  => 9,
      'Outubro'   => 10,
      'Novembro'  => 11,
      'Dezembro'  => 12,
  );

 return $self->schema->resultset('RemuneracaoMunicipal')
  ->search_rs(
    {cod_inep => $params->{cod_inep}}
  )->columns([qw(ano mes)])->distinct
  ->as_hash->get_all->map(
    sub {
      # Março pode estar em latin1 então qualquer falha se deve a ele
      my $dt_str = sprintf "%s-%s", $months{$_->{mes}} // 3, $_->{ano};
      $self->parser->parse_datetime($dt_str);
    }
  );
}

# ---------------------------------------------------------------------------
# SIOPE (remuneração municipal): rede da escola, município e anos já baixados.
# Só a rede municipal tem dados (o SIOPE é o agregado do município). A unidade
# do download é o código antigo do IBGE (6 dígitos) do MUNICÍPIO da escola —
# não o prefixo do cod_inep.
# ---------------------------------------------------------------------------

sub _rede_escola($self, $cod_inep) {
  my $dbh = $self->schema->storage->dbh;
  my ($rede) = $dbh->selectrow_array(
    'SELECT dependencia_administrativa FROM clean.escolas WHERE codigo_inep = ? LIMIT 1',
    undef, $cod_inep,
  );
  return $rede if defined $rede;

  my ($tp) = $dbh->selectrow_array(
    'SELECT tp_dependencia FROM clean.censo_escolas WHERE co_entidade = ? LIMIT 1',
    undef, $cod_inep,
  );
  return undef unless defined $tp;
  return $self->censo_labels->rede_label($tp);
}

sub _siope_anos_presentes($self, $cod_municipio) {
  my $rows = $self->schema->storage->dbh->selectall_arrayref(
    'SELECT DISTINCT ano FROM clean.remuneracao_municipal
     WHERE cod_municipio::text = ? ORDER BY ano',
    undef, $cod_municipio,
  );
  return [ map { $_->[0] + 0 } @$rows ];
}

# Código antigo do IBGE (6 dígitos) do município da escola. NÃO é o prefixo do
# cod_inep (ex.: INEP 51065592 é de Cuiabá, cujo código antigo é 510340).
# Fonte primária: clean.censo_escolas.co_municipio (7 dígitos) -> 6 dígitos.
# Fallback: nome+UF da escola curada mapeados em raw.br_municipios_2024.
sub _cod_municipio_escola($self, $cod_inep) {
  my $dbh = $self->schema->storage->dbh;

  my ($co_mun) = $dbh->selectrow_array(
    'SELECT co_municipio FROM clean.censo_escolas WHERE co_entidade = ? LIMIT 1',
    undef, $cod_inep,
  );
  return substr("$co_mun", 0, 6) if defined $co_mun;

  my ($nome, $uf) = $dbh->selectrow_array(
    'SELECT municipio, uf FROM clean.escolas WHERE codigo_inep = ? LIMIT 1',
    undef, $cod_inep,
  );
  return undef unless defined $nome && defined $uf;

  my $cd = eval {
    my ($v) = $dbh->selectrow_array(
      'SELECT cd_mun FROM raw.br_municipios_2024
       WHERE nm_mun ILIKE ? AND sigla_uf = ? LIMIT 1',
      undef, $nome, $uf,
    );
    $v;
  };
  return defined $cd ? substr("$cd", 0, 6) : undef;
}

# Metadados do SIOPE para uma escola (usado pelo painel financeiro).
sub siope_status($self, $cod_inep) {
  my $rede          = $self->_rede_escola($cod_inep);
  my $cod_municipio = $self->_cod_municipio_escola($cod_inep);
  my $eh_municipal  = defined $rede && $rede =~ /municipal/i;
  my $pode          = $eh_municipal && defined $cod_municipio;

  return {
    escola_existe  => defined $rede ? 1 : 0,
    rede           => $rede,
    habilitado     => $pode ? 1 : 0,
    cod_municipio  => $cod_municipio,
    anos_presentes => $pode ? $self->_siope_anos_presentes($cod_municipio) : [],
  };
}

# Pode enfileirar o download do SIOPE para a escola/ano? (regras de negócio)
sub siope_disponivel($self, $cod_inep, $ano) {
  my $st = $self->siope_status($cod_inep);
  return { error => 'escola_inexistente' } unless $st->{escola_existe};
  return { error => 'nao_municipal' }     unless $st->{habilitado};
  return { error => 'ano_existente' }
    if grep { $_ == $ano } @{ $st->{anos_presentes} };
  return { ok => 1, cod_municipio => $st->{cod_municipio} };
}

# Cobertura da folha (#422): um item por município com remuneração
# carregada. `escolas` conta as unidades com folha própria; 0 quando o SIOPE
# só traz o agregado da secretaria (código 99999999).
sub folha_cobertura($self) {
  my $dbh = $self->schema->storage->dbh;
  # Agrega a folha antes e busca o nome na malha municipal local (#591): a
  # raw.br_municipios_2024 é tabela estrangeira (relê o arquivo da malha a
  # cada consulta: 2,5 s em todo painel financeiro).
  my $sql_nome = <<~'SQL';
    WITH a AS (
      SELECT cod_municipio,
             MIN(ano)::int AS ano_inicial,
             MAX(ano)::int AS ano_final,
             (COUNT(DISTINCT cod_inep) FILTER (WHERE cod_inep <> 99999999))::int AS escolas
        FROM clean.remuneracao_municipal
       GROUP BY cod_municipio
    )
    SELECT a.cod_municipio, m.nome_municipio AS municipio, m.sigla_uf AS uf,
           a.ano_inicial, a.ano_final, a.escolas
      FROM a
      LEFT JOIN clean.malha_municipio m ON left(m.codigo_ibge::text, 6) = a.cod_municipio::text
     ORDER BY m.nome_municipio NULLS LAST, a.cod_municipio
  SQL
  # Sem a tabela de municípios (ambiente parcial), sai sem o nome.
  my $rows = eval { $dbh->selectall_arrayref($sql_nome, { Slice => {} }) }
    // eval {
      $dbh->selectall_arrayref(<<~'SQL', { Slice => {} });
        SELECT cod_municipio, NULL AS municipio, NULL AS uf,
               MIN(ano)::int AS ano_inicial, MAX(ano)::int AS ano_final,
               (COUNT(DISTINCT cod_inep) FILTER (WHERE cod_inep <> 99999999))::int AS escolas
          FROM clean.remuneracao_municipal
         GROUP BY cod_municipio ORDER BY cod_municipio
        SQL
    }
    // [];
  return { municipios => scalar(@$rows), lista => $rows };
}

sub financial_summary($self, $params) {
  croak "need cod_inep" unless $params->{cod_inep};

  my $cod = $params->{cod_inep};
  my $dbh = $self->schema->storage->dbh;

  my ($nome) = $dbh->selectrow_array(
    'SELECT escola FROM clean.escolas WHERE codigo_inep = ? LIMIT 1',
    undef, $cod,
  );

  # O mês é texto em PT ("Janeiro".."Dezembro"), com um caso conhecido de
  # latin1 ("Março"). Derivamos o número pelo prefixo (robusto a encoding)
  # apenas para ordenar a linha do tempo.
  my @month_whens = map {
    sprintf "        WHEN mes LIKE '%s%%' THEN %d", $_->[0], $_->[1]
  } (
    ['Jan', 1], ['Fev', 2], ['Mar', 3], ['Abr', 4], ['Mai', 5], ['Jun', 6],
    ['Jul', 7], ['Ago', 8], ['Set', 9], ['Out', 10], ['Nov', 11], ['Dez', 12],
  );

  my $month_case = join "\n",
    '      CASE',
    @month_whens,
    '        ELSE 0',
    '      END';

  # A folha pode estar na própria escola OU agregada no município (código
  # 99999999 = "SEC MUN DE EDUC ..."), quando o SIOPE não declara por escola.
  # Tenta a escola; se não houver, cai para o agregado do município.
  my ($tem_escola) = $dbh->selectrow_array(
    'SELECT 1 FROM clean.remuneracao_municipal WHERE cod_inep = ? LIMIT 1',
    undef, $cod,
  );

  # #422: o agregado só vale para escola da REDE MUNICIPAL (o SIOPE é a
  # remuneração municipal) e soma só as linhas da secretaria (99999999).
  # Antes somava o município inteiro e valia para qualquer rede: uma escola
  # estadual de Cuiabá aparecia com a folha municipal toda (13.547
  # profissionais) rotulada como "Folha da Secretaria".
  my $siope  = $self->siope_status($cod);
  my $origem = 'escola';
  my $where  = 'cod_inep = ?';
  my @bind   = ($cod);
  if (!$tem_escola && $siope->{habilitado}) {
    $where  = 'cod_municipio::text = ? AND cod_inep = 99999999';
    @bind   = ($siope->{cod_municipio});
    $origem = 'secretaria';
  }

  # #491 (RJ-02): tudo é de um ano (exercício). Sem o ano pedido, o mais
  # recente; ano sem folha é erro do pedido (o controller dá 400).
  my $anos = $dbh->selectcol_arrayref(
    "SELECT DISTINCT ano FROM clean.remuneracao_municipal WHERE $where ORDER BY ano DESC",
    undef, @bind,
  );
  $anos = [ map { 0 + $_ } @$anos ];
  my $ano = $params->{ano};
  if (defined $ano && @$anos && !grep { $_ == $ano } @$anos) {
    return { error => 'ano_sem_folha', anos => $anos };
  }
  $ano //= $anos->[0];
  if (defined $ano) {
    $where .= ' AND ano = ?';
    push @bind, $ano;
  }

  my $series = $dbh->selectall_arrayref(<<~"SQL", { Slice => {} }, @bind);
    SELECT
      ano,
      mes,
      $month_case AS mes_num,
      COALESCE(SUM(salario_total), 0)::float AS total_salario,
      COUNT(DISTINCT $PESSOA)::int               AS total_profissionais
    FROM clean.remuneracao_municipal
    WHERE $where
    GROUP BY ano, mes
    ORDER BY ano, mes_num
  SQL

  my $categorias = $dbh->selectall_arrayref(<<~"SQL", { Slice => {} }, @bind);
    SELECT
      categoria,
      tipo,
      COALESCE(SUM(salario_total), 0)::float AS total_salario,
      COUNT(DISTINCT $PESSOA)::int               AS total_profissionais
    FROM clean.remuneracao_municipal
    WHERE $where
    GROUP BY categoria, tipo
    ORDER BY total_salario DESC
  SQL

  # #553 (QS-01 da P5): a folha do ano por fonte de recurso, como o SIOPE a
  # declara em cada pagamento: a parcela de 70% do Fundeb, a de 30% e as
  # outras fontes. As três somam o salário total; o que faltar (campo vazio
  # numa carga) vai em nao_informado, para a soma sempre fechar.
  my $fonte = $dbh->selectrow_hashref(<<~"SQL", undef, @bind);
    SELECT COALESCE(SUM(salario_fundeb_max), 0)::float AS fundeb_70,
           COALESCE(SUM(salario_fundeb_min), 0)::float AS fundeb_30,
           COALESCE(SUM(salario_outros), 0)::float     AS outras,
           COALESCE(SUM(salario_total), 0)::float      AS total
      FROM clean.remuneracao_municipal
     WHERE $where
  SQL
  my $por_fonte;
  if ($fonte && $fonte->{total} > 0) {
    my $resto = $fonte->{total} - $fonte->{fundeb_70} - $fonte->{fundeb_30} - $fonte->{outras};
    $por_fonte = { %$fonte, nao_informado => (abs($resto) < 0.01 ? 0 : 0 + sprintf('%.2f', $resto)) };
  }

  # Total de profissionais distintos no ano — o card do painel usa este
  # total; a competência mais recente pode ter 1 servidor e parecer que a
  # escola só tem 1.
  my ($total_profissionais) = $dbh->selectrow_array(
    "SELECT COUNT(DISTINCT $PESSOA)::int FROM clean.remuneracao_municipal WHERE $where",
    undef, @bind,
  );

  # #422: sem série, dizer POR QUE (ausência não é erro nem zero, #154).
  my $ausencia;
  if (!@{ $series // [] }) {
    $ausencia = !$siope->{escola_existe}          ? 'escola_inexistente'
              : !$siope->{habilitado}             ? 'nao_municipal'
              : @{ $siope->{anos_presentes} // [] } ? 'escola_sem_folha'
              :                                     'municipio_sem_carga';
    $origem = 'escola';   # nada veio do agregado
  }

  return {
    escola     => {
      codigo_inep                => $cod,
      nome                       => $nome,
      dependencia_administrativa => $siope->{rede},
      cod_municipio              => $siope->{cod_municipio},
    },
    # origem: 'escola' (folha da própria unidade) ou 'secretaria' (agregado do
    # município — o SIOPE não declara por escola em parte das cidades).
    origem     => $origem,
    rotulo_origem => $origem eq 'secretaria'
      ? 'Folha da Secretaria municipal (o SIOPE não detalha por escola neste município)'
      : undef,
    total_profissionais => ($total_profissionais // 0) + 0,
    # null quando há dado; senão 'escola_inexistente', 'nao_municipal' (o
    # SIOPE só cobre a remuneração da rede municipal), 'escola_sem_folha' (o
    # município tem folha carregada, mas não desta escola nem agregado da
    # secretaria) ou 'municipio_sem_carga'.
    ausencia   => $ausencia,
    # Onde há folha carregada: municípios, anos e se o SIOPE detalha por
    # escola ou só pelo agregado da secretaria.
    cobertura  => $self->folha_cobertura,
    # #491 (RJ-02): o ano mostrado, os anos com folha e o período do ano.
    ano        => $ano,
    anos       => $anos,
    periodo    => _periodo($series),
    series     => $series     // [],
    categorias => $categorias // [],
    por_fonte  => $por_fonte,
    # #558 (QT-02 da P2): os meses do ano em que o município declarou a
    # folha (quase) só no total da Secretaria: neles a folha da escola não
    # aparece. Só faz sentido quando o painel é da escola.
    # #576 (QH-02 da P5): a data da carga registrada do município e ano (os
    # dados são os da planilha baixada nessa data); sem registro, undef.
    carga_folha => (defined $ano && $siope->{cod_municipio}
      ? EduMaps::BaseAnalise->cargas_folha($dbh)->{"$siope->{cod_municipio}|$ano"}
      : undef),
    # #571 (QI-01 da P3): o salário do magistério da rede inteira no ano,
    # com a folha da Secretaria (vale também no painel da Secretaria).
    salario_rede => (defined $ano && $siope->{cod_municipio}
      ? EduMaps::BaseAnalise->salario_rede($dbh, "$siope->{cod_municipio}")->{"$siope->{cod_municipio}|$ano"}
      : undef),
    # #589 (P1-FL-03): o salário do magistério da escola, na mesma conta da
    # rede (só no painel da escola)
    salario_escola => ($origem eq 'escola' && defined $ano
      ? EduMaps::BaseAnalise->salario_escola($dbh, $cod, $ano) : undef),
    # #567 (P1-FL-01): os docentes do Censo ao lado da folha, e quantos
    # profissionais do magistério do município estão só no total da
    # Secretaria (sem escola). Só no painel da escola.
    ($origem eq 'escola' && defined $ano ? (docentes => $self->_docentes_folha_censo($dbh, $cod, $ano, $siope->{cod_municipio})) : ()),
    meses_secretaria => (defined $ano && $siope->{cod_municipio} && $origem eq 'escola'
      ? ((EduMaps::BaseAnalise->meses_por_lugar($dbh, "$siope->{cod_municipio}")->{"$siope->{cod_municipio}|$ano"} // {})->{secretaria} // [])
      : []),
    # #557 (QT-01 da P2): os meses do ano em que a folha do município veio
    # pela metade (vale para todas as escolas dele).
    meses_incompletos => (defined $ano && $siope->{cod_municipio}
      ? (EduMaps::BaseAnalise->meses_incompletos($dbh, "$siope->{cod_municipio}")->{"$siope->{cod_municipio}|$ano"} // [])
      : []),
    siope      => {
      habilitado     => $siope->{habilitado},
      cod_municipio  => $siope->{cod_municipio},
      ano_inicial    => 2020,
      ano_atual      => DateTime->now->year,
      anos_presentes => $siope->{anos_presentes},
    },
  };
}

# #567 (P1-FL-01 da P1): folha e Censo lado a lado. A folha conta as pessoas
# do magistério pagas no ano e a média por mês (a mais perto do Censo, que é
# a fotografia de um dia de maio); o Censo, os docentes da educação básica da
# escola no ano mais recente. Do município no ano: os profissionais do
# magistério só no total da Secretaria (99999999), sem nenhuma escola.
sub _docentes_folha_censo ($self, $dbh, $cod, $ano, $cod_mun) {
  my $folha = $dbh->selectrow_hashref(<<~"SQL", undef, $cod, $ano);
    SELECT count(DISTINCT $PESSOA)::int AS ano,
           round(count(*)::numeric / NULLIF(count(DISTINCT left(mes, 3)), 0), 1)::float8 AS por_mes
      FROM (SELECT DISTINCT left(mes, 3) AS mes, cpf, nome_profissional
              FROM clean.remuneracao_municipal
             WHERE cod_inep = ? AND ano = ? AND tipo = 'Profissionais do magistério') x
    SQL
  my $censo = $dbh->selectrow_hashref(
    'SELECT qt_doc_bas::int AS docentes, nu_ano_censo::int AS ano FROM clean.censo_docentes
      WHERE co_entidade = ? ORDER BY nu_ano_censo DESC LIMIT 1', undef, $cod);
  my $sec = $cod_mun ? $dbh->selectrow_hashref(q{
    SELECT count(*)::int AS total, (count(*) FILTER (WHERE sec AND NOT esc))::int AS so_secretaria
      FROM (SELECT bool_or(cod_inep = 99999999) AS sec, bool_or(cod_inep <> 99999999) AS esc
              FROM clean.remuneracao_municipal
             WHERE cod_municipio::text = ? AND ano = ? AND tipo = 'Profissionais do magistério'
             GROUP BY cpf, nome_profissional) p
  }, undef, "$cod_mun", $ano) : undef;
  return {
    folha_ano     => ($folha->{ano} // 0) + 0,
    folha_por_mes => $folha->{por_mes},
    censo         => $censo ? { docentes => $censo->{docentes}, ano => $censo->{ano} } : undef,
    municipio     => $sec && $sec->{total} ? {
      magisterio    => $sec->{total},
      so_secretaria => $sec->{so_secretaria},
      # B1: o aviso só com 10% ou mais só na Secretaria
      avisar        => ($sec->{so_secretaria} >= 0.1 * $sec->{total} ? \1 : \0),
    } : undef,
  };
}

# Período coberto pela série de um ano: primeiro e último mês e quantos meses.
sub _periodo ($series) {
  my @m = sort { $a <=> $b } grep { $_ } map { $_->{mes_num} } @{ $series // [] };
  return undef unless @m;
  return { mes_inicial => 0 + $m[0], mes_final => 0 + $m[-1], meses => scalar @m };
}

sub last_payroll_available($self, $params) {
  croak "need cod_inep" unless $params->{cod_inep};
  my $dates = $self->payroll_dates({ cod_inep => $params->{cod_inep} });
  return $dates unless $dates->size > 0;

  my $max = $dates->reduce(sub{$a > $b ? $a : $b});
  return $self->schema->resultset('RemuneracaoMunicipal')->search_rs(
    { 
      cod_inep => $params->{cod_inep},
      ano => $max->year, mes => ucfirst($max->month_name),
    }
  )->as_hash->get_all->each(
    # force numeric values
    sub {
      $_->{salario_base} += 0;
      $_->{salario_total} += 0;
      $_->{salario_fundeb_max} += 0;
      $_->{salario_fundeb_min} += 0;
      $_->{salario_outros} += 0;
    }
  );
}

1;
