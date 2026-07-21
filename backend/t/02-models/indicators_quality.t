use strict;
use warnings;
use lib qw(t/lib lib);
use Imports;
use Utils qw(build_r_dataframe);
use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::Domain::SchoolQuality';
use ok 'EduMaps::Analysis::R::Pipe';
use ok 'EduMaps::Model::Indicator::School::IFS';
use ok 'EduMaps::Model::Indicator::School::IPS';
use ok 'EduMaps::Model::Indicator::School::IGE';
use ok 'EduMaps::Model::Indicator::School::IAI';

use Text::Table;

my $schema = EduMaps::Schema->go;
my $tag = '[indicator quality] qualidade dos índices:';
my $municipio = 'Brasília';

# Adicionada a métrica de evolução mínima sobre o modelo nulo
my %thresholds = (
    rho_min      => 0.15,
    p_max        => 0.10,
    rmse_gain_min => 0.05, # Modelo precisa ser no mínimo 5% melhor que a média
    n_min        => 5,   
);

subtest ' - Validação estatística dos indicadores com IDEB usando R::Pipe ' => sub {

  my $schools_rs = $schema->resultset('CensoEscolas')
  ->search(
    {no_municipio => $municipio, tp_situacao_funcionamento => 1}
  );

  my @indicators = (
    EduMaps::Model::Indicator::School::IFS->new,
    EduMaps::Model::Indicator::School::IPS->new,
    EduMaps::Model::Indicator::School::IGE->new,
    EduMaps::Model::Indicator::School::IAI->new,
  );

  # 2. Extrair scores e notas do IDEB
  my @dataset;
  while (my $school = $schools_rs->next) {
    my $ultimo_ideb = $school->nota_ideb->search(
      { nota_media => { '!=' => undef } },
      { order_by => { -desc => 'ano' }, rows => 1 }
    )->first;

    next unless $ultimo_ideb;
    my $nota = $ultimo_ideb->nota_media;
    next if $nota <= 0;

    my %scores;
    for my $ind (@indicators) {
      my %data = $school->get_columns;
      $scores{$ind->code} = $ind->calculate(\%data);
    }

    push @dataset, {
      co_entidade => $school->co_entidade,
      nota        => $nota,
      scores      => \%scores,
    };
  }

  my $n = scalar @dataset;
  diag "Número de escolas em $municipio para validação: $n";
  if ($n < $thresholds{n_min}) {
    fail("Amostra insuficiente ($n < $thresholds{n_min}) - pulando análise estatística.");
    return;
  }

  # 3. Preparar dados e construir o dataframe R de forma dinâmica usando o Helper
  my %column_data = (
    nota => [ map { $_->{nota} } @dataset ]
  );

  for my $ind (@indicators) {
    my $code = $ind->code;
    $column_data{$code} = [ map { $_->{scores}{$code} } @dataset ];
  }

  my $r_df_definition = build_r_dataframe('df', \%column_data);

  # 4. Construir script R dinâmico injetando as estatísticas e gerando JSON no final
  my @codes = map { $_->code } @indicators;
  my $r_codes_array = "c(" . join(',', map { "'$_'" } @codes) . ")";

  my $script_conteudo = <<~"EOS";
  library(jsonlite)

  $r_df_definition

  codes <- $r_codes_array
  results <- list()

  # Baseline: RMSE do modelo nulo (prever apenas a média) equivale ao desvio padrão amostral
  # Usamos n-1 para consistência com os resíduos do modelo linear
  n_df <- nrow(df)
  rmse_null <- sqrt(sum((df\$nota - mean(df\$nota))^2) / n_df)

  for (code in codes) {
    # Correlação de Spearman
    sp <- cor.test(df[[code]], df\$nota, method='spearman', exact=FALSE)
    rho <- as.numeric(sp\$estimate)
    p_val <- as.numeric(sp\$p.value)

    # Regressão linear
    lm_fit <- lm(nota ~ df[[code]], data=df)
    r2 <- as.numeric(summary(lm_fit)\$r.squared)
    rmse <- as.numeric(sqrt(mean(lm_fit\$residuals^2)))
    coef_val <- as.numeric(coef(lm_fit)[2])

    # Ganho percentual de redução do RMSE em relação ao modelo nulo
    rmse_gain <- if (rmse_null > 0) (rmse_null - rmse) / rmse_null else 0

    # SEM TRATAMENTO SILENCIOSO DE NA: Deixamos estourar se houver inconsistência nos vetores
    results[[code]] <- list(
      rho = rho,
      p_val = p_val,
      r2 = r2,
      rmse = rmse,
      rmse_null = rmse_null,
      rmse_gain = rmse_gain,
      coef = coef_val
    )
  }

  cat(jsonlite::toJSON(results, auto_unbox=TRUE))
  quit(status = 0)
  EOS

  # 5. Executar via Pipe nativo do EduMaps
  my $rpipe = EduMaps::Analysis::R::Pipe->new;
  my $r_params = {
    script => $script_conteudo,
    paths => [], 
  };
  my $r_out;

  eval {
    $r_out = $rpipe->run($r_params);
  };
  if ($@) {
    fail("Falha catastrófica ao rodar o Pipe do R: $@");
    return;
  }

  # 6. Exibir a tabela de resultados com dados da baseline incluídos
  my $table = Text::Table->new(
    'Indicador', 'ρ (Spearman)', 'p-valor', 'R²', 'RMSE', 'RMSE Nulo', 'Ganho %'
  );
  for my $ind (@indicators) {
    my $code = $ind->code;
    my $res  = $r_out->{$code};
    
    # Tratamento seguro para exibição caso o R retorne campos nulos/indefinidos
    my $rho       = defined $res->{rho}       ? sprintf("%.3f", $res->{rho})       : 'NaN';
    my $p_val     = defined $res->{p_val}     ? sprintf("%.4f", $res->{p_val})     : 'NaN';
    my $r2        = defined $res->{r2}        ? sprintf("%.3f", $res->{r2})        : 'NaN';
    my $rmse      = defined $res->{rmse}      ? sprintf("%.3f", $res->{rmse})      : 'NaN';
    my $rmse_null = defined $res->{rmse_null} ? sprintf("%.3f", $res->{rmse_null}) : 'NaN';
    my $gain      = defined $res->{rmse_gain} ? sprintf("%.1f%%", $res->{rmse_gain} * 100) : '0.0%';

    $table->add($code, $rho, $p_val, $r2, $rmse, $rmse_null, $gain);
  }
  diag("\n" . $table);

  # 7. Assertivas rígidas baseadas nos thresholds (Garante falha em caso de NA ou estouro de limite)
  for my $ind (@indicators) {
    my $code = $ind->code;
    my $res  = $r_out->{$code};

    # Falha imediata caso o R tenha retornado campos indefinidos (antigos NAs mascarados)
    if (!defined $res->{rho} || !defined $res->{p_val} || !defined $res->{rmse_gain}) {
      fail("$code REPROVADO: Dados estatísticos inválidos ou corrompidos (NA gerado no R).");
      next;
    }

    my $rho_ok       = $res->{rho} >= $thresholds{rho_min};
    my $p_ok         = $res->{p_val} < $thresholds{p_max};
    my $rmse_gain_ok = $res->{rmse_gain} >= $thresholds{rmse_gain_min};

    my $msg = sprintf("%s: rho=%.2f (p=%.3f), R²=%.2f, Ganho RMSE=%.1f%%", 
      $code, $res->{rho}, $res->{p_val}, $res->{r2}, $res->{rmse_gain} * 100
    );

    # Agora o ok() avalia de verdade a condição e reprova o teste se falhar
    ok($rho_ok && $p_ok && $rmse_gain_ok, "Validação de relevância para: $msg")
      or diag(sprintf("  -> Falhou nos critérios: esperado rho >= %.2f, p < %.2f, ganho RMSE >= %.1f%%",
        $thresholds{rho_min}, $thresholds{p_max}, $thresholds{rmse_gain_min} * 100
      ));
  }
};

done_testing;
