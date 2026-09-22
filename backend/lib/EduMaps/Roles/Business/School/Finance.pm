package EduMaps::Roles::Business::School::Finance;
use Mojo::Base -role, -signatures;
use Mojo::Exception qw(raise);
use DateTime;
use DateTime::Format::Strptime;
use Carp qw(croak);

requires qw(schema default_columns);

has parser => sub {
  DateTime::Format::Strptime->new(
    pattern   => '%m-%Y',
    locale    => 'pt_BR',
    on_error  => 'croak',
  );
};

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
          COUNT(DISTINCT r.cpf) AS total_profissionais,
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
              COUNT(DISTINCT cpf) AS profissionais,
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
              COUNT(DISTINCT cpf) AS profissionais,
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
  return { 1 => 'Federal', 2 => 'Estadual', 3 => 'Municipal', 4 => 'Privada' }->{$tp};
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

  my $cod_municipio = $self->_cod_municipio_escola($cod);
  my $origem = 'escola';
  my $where  = 'cod_inep = ?';
  my @bind   = ($cod);
  if (!$tem_escola && defined $cod_municipio) {
    $where = 'cod_municipio::text = ?';
    @bind  = ($cod_municipio);
    $origem = 'secretaria';
  }

  my $series = $dbh->selectall_arrayref(<<~"SQL", { Slice => {} }, @bind);
    SELECT
      ano,
      mes,
      $month_case AS mes_num,
      COALESCE(SUM(salario_total), 0)::float AS total_salario,
      COUNT(DISTINCT cpf)::int               AS total_profissionais
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
      COUNT(DISTINCT cpf)::int               AS total_profissionais
    FROM clean.remuneracao_municipal
    WHERE $where
    GROUP BY categoria, tipo
    ORDER BY total_salario DESC
  SQL

  # Total de profissionais distintos (todos os meses/anos) — o card do painel
  # usa este total; a competência mais recente pode ter 1 servidor e parecer
  # que a escola só tem 1.
  my ($total_profissionais) = $dbh->selectrow_array(
    "SELECT COUNT(DISTINCT cpf)::int FROM clean.remuneracao_municipal WHERE $where",
    undef, @bind,
  );

  my $siope = $self->siope_status($cod);

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
    series     => $series     // [],
    categorias => $categorias // [],
    siope      => {
      habilitado     => $siope->{habilitado},
      cod_municipio  => $siope->{cod_municipio},
      ano_inicial    => 2020,
      ano_atual      => DateTime->now->year,
      anos_presentes => $siope->{anos_presentes},
    },
  };
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
