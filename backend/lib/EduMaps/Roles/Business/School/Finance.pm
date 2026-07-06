package EduMaps::Roles::Business::School::Finance;
use Mojo::Base -role, -signatures;
use Mojo::Exception qw(raise);
use DateTime;

requires qw(schema default_columns);

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

1;
