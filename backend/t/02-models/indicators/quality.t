use strict;
use warnings;
use lib qw(t/lib lib);
use Imports;
use Utils qw(build_r_dataframe);
use ok 'EduMaps::Schema';
use ok 'EduMaps::Analysis::R::Pipe';
use ok 'EduMaps::Model::Indicator::School::IQD';
use ok 'EduMaps::Model::Indicator::School::ISE';
use Text::Table;

my $schema = EduMaps::Schema->go;
my $tag = '[indicator quality] qualidade dos índices:';
my $municipio = 'São Paulo';

# --------------------------------------------------------------------
# Critérios de relevância estatística de um indicador
#
# Cada critério mede uma coisa DIFERENTE e não-redundante entre si:
#
#   - significância (p_max): distingue sinal de ruído amostral. Não diz
#     nada sobre o TAMANHO do efeito - com n grande, ate uma correlação
#     minúscula fica "estatisticamente significativa". Continua sendo a
#     correlação de Spearman UNIVARIADA (indicador vs nota), independente
#     de qualquer fórmula/confundidor usado na regressão - rho mede
#     associação monotônica bruta, não é afetado por controles.
#
#   - força de associação monotônica (rho_min): idem, correlação de
#     Spearman, robusta a outliers e a relações não-lineares (desde que
#     monotônicas). Limiares clássicos de Cohen (1988): |rho| ~ 0.10
#     efeito pequeno, ~0.30 médio, ~0.50 grande. rho_min=0.15 fica entre
#     pequeno e médio.
#
#   - poder explicativo INCREMENTAL (r2_min): quanto de variância do IDEB
#     o indicador acrescenta a um modelo linear, ALÉM do que os
#     confundidores da fórmula (se houver) já explicam sozinhos. Ou seja,
#     r2_gain = R²(modelo completo) - R²(modelo só com os confundidores).
#
#     Isso generaliza o r2 simples do teste anterior: para um indicador
#     sem confundidores na fórmula, o "modelo nulo" é só o intercepto,
#     cujo R² é 0 por definição - logo r2_gain = R²(modelo completo),
#     exatamente como antes. Os limiares de Cohen para r² continuam
#     valendo (~0.01 pequeno, ~0.09 médio, ~0.25 grande) porque r2_gain
#     está na mesma escala/semântica de r² - só que agora "descontando"
#     o que já era explicado por variáveis de controle.
#
#     Sem essa correção, comparar R² bruto entre um indicador com fórmula
#     simples e outro com confundidores seria injusto: adicionar QUALQUER
#     termo a uma regressão aumenta R² mecanicamente, então um indicador
#     fraco com uma fórmula "carregada" de confundidores pareceria melhor
#     só por causa do controle, não por mérito próprio.
#
# NÃO usamos "ganho de RMSE sobre o modelo nulo" como critério de
# aprovação separado (só como diagnóstico na tabela): numa regressão
# linear, RMSE_ganho é uma função determinística de r2_gain do MESMO
# ajuste, então gatear nos dois seria o mesmo critério contado duas
# vezes em escalas diferentes - foi exatamente isso que causou a
# confusão original com 'iqd' (rho passava, "ganho RMSE" não, sem que
# a relação matemática entre os dois estivesse documentada em lugar
# nenhum).
# --------------------------------------------------------------------
my %thresholds = (
  p_max   => 0.10, # significância a 90% de confiança
  rho_min => 0.15, # entre efeito pequeno (0.10) e médio (0.30) - Cohen 1988
  r2_min  => 0.09, # piso do efeito médio para r² (ou r²_gain) - Cohen 1988
  n_min   => 5,
);

# --------------------------------------------------------------------
# Fórmulas por indicador
#
# Cada entrada define o lado direito (RHS) da fórmula usada no lm() para
# medir o efeito do indicador, e o RHS do modelo "nulo" correspondente -
# ou seja, o modelo de comparação para calcular r2_gain/rmse_gain (ver
# nota acima). 'covariates' lista as colunas extras (além do próprio
# indicador e de 'nota') que a fórmula usa e que precisam ser
# carregadas/injetadas no dataframe R.
#
# Indicadores que não aparecem aqui usam o default:
#   rhs => "<code>", null_rhs => "1", covariates => []
# (equivalente ao comportamento original: regressão simples indicador ~ nota,
# comparado contra o modelo de intercepto/média global.)
#
# 'iqd' entra aqui porque a análise anterior mostrou correlação
# INSTÁVEL entre municípios (positiva em Brasília, negativa em São Paulo,
# ambas com p<0.0001 e n grande o suficiente para não ser ruído) - um
# padrão clássico de confundimento por composição de rede de ensino
# (paradoxo de Simpson). Controlar por 'tp_dependencia' testa se o
# efeito do indicador se mantém DENTRO de cada rede, em vez de misturado
# entre redes com perfis de alunado muito diferentes.
# --------------------------------------------------------------------
my %formulas = (
  iqd => {
    rhs        => 'iqd + factor(tp_dependencia)',
    null_rhs   => 'factor(tp_dependencia)',
    covariates => [qw/tp_dependencia/],
  },
);

sub formula_for {
  my $code = shift;
  my $cfg  = $formulas{$code} // {};
  return {
    rhs        => $cfg->{rhs}        // $code,
    null_rhs   => $cfg->{null_rhs}   // '1',
    covariates => $cfg->{covariates} // [],
  };
}

sub is_significant {
  my $res = shift;
  return defined $res->{p_val} && $res->{p_val} < $thresholds{p_max};
}

sub has_monotonic_association {
  my $res = shift;
  return defined $res->{rho} && $res->{rho} >= $thresholds{rho_min};
}

sub has_explanatory_power {
  my $res = shift;
  return defined $res->{r2_gain} && $res->{r2_gain} >= $thresholds{r2_min};
}

# Um indicador é considerado relevante apenas se passar nos TRÊS
# critérios simultaneamente - cada um cobre uma lacuna que os outros
# dois não cobrem.
sub indicator_is_relevant {
  my $res = shift;
  return 0 unless defined $res->{rho} && defined $res->{p_val} && defined $res->{r2_gain};
  return is_significant($res) && has_monotonic_association($res) && has_explanatory_power($res);
}

# Colunas extras trazidas via join (docente, inse), alem das nativas de
# CensoEscolas ja cobertas por get_columns(). Ver nota sobre get_columns()
# vs +select/+as no merge explicito abaixo.
my @EXTRA_DOCENTE_COLS = qw(
  qt_doc_bas
  qt_doc_bas_esco_sup_grad
  qt_doc_bas_esco_sup_pos_espec
  qt_doc_bas_esco_sup_pos_mestra
  qt_doc_bas_esco_sup_pos_douto
);
my @EXTRA_INSE_COLS = qw(media_inse inse_classificacao);

subtest ' - Validação estatística dos indicadores com IDEB usando R::Pipe ' => sub {
  # 'docente' e has_many + INNER JOIN (escolas sem nenhum docente
  # registrado, ex: paralisadas, saem do resultset - o que e desejavel
  # aqui). 'inse' e has_one, portanto LEFT JOIN por padrao (escolas sem
  # INSE continuam no resultset, so com inse_classificacao undef).
  my $schools_rs = $schema->resultset('CensoEscolas')
    ->search({ 'me.no_municipio' => $municipio })
    ->join([qw/docente inse/])
    ->search(undef, {
      '+select' => [
        (map { "docente.$_" } @EXTRA_DOCENTE_COLS),
        (map { "inse.$_" } @EXTRA_INSE_COLS),
      ],
      '+as' => [ @EXTRA_DOCENTE_COLS, @EXTRA_INSE_COLS ],
    });

  my @indicators = (
    EduMaps::Model::Indicator::School::IQD->new,
    EduMaps::Model::Indicator::School::ISE->new,
  );
  my @codes = map { $_->code } @indicators;

  # Colunas de covariáveis (confundidores) exigidas pelas fórmulas dos
  # indicadores efetivamente em uso - união de todas, sem duplicar.
  my %covariate_cols;
  for my $code (@codes) {
    $covariate_cols{$_} = 1 for @{ formula_for($code)->{covariates} };
  }
  my @EXTRA_COVARIATE_COLS = sort keys %covariate_cols;

  # 2. Extrair scores, covariáveis e notas do IDEB
  my @dataset;
  while (my $school = $schools_rs->next) {
    my $ultimo_ideb = $school->nota_ideb->search(
      { nota_media => { '!=' => undef } },
      { order_by => { -desc => 'ano' }, rows => 1 }
    )->first;
    next unless $ultimo_ideb;
    my $nota = $ultimo_ideb->nota_media;
    next if $nota <= 0;

    my %data = $school->get_columns;

    # merge explicito das colunas extras trazidas via +select/+as - nao
    # confiamos em get_columns() trazer isso sozinho (comportamento
    # inconsistente entre versoes do DBIx::Class)
    for my $extra (@EXTRA_DOCENTE_COLS, @EXTRA_INSE_COLS) {
      my $val = eval { $school->get_column($extra) };
      $data{$extra} = $val unless $@;
    }

    my %scores;
    for my $ind (@indicators) {
      $scores{$ind->code} = $ind->calculate(\%data);
    }

    my %covariates = map { $_ => $data{$_} } @EXTRA_COVARIATE_COLS;

    push @dataset, {
      co_entidade => $school->co_entidade,
      nota        => $nota,
      scores      => \%scores,
      covariates  => \%covariates,
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
  for my $code (@codes) {
    $column_data{$code} = [ map { $_->{scores}{$code} } @dataset ];
  }
  for my $cov (@EXTRA_COVARIATE_COLS) {
    $column_data{$cov} = [ map { $_->{covariates}{$cov} } @dataset ];
  }
  my $r_df_definition = build_r_dataframe('df', \%column_data);

  # 4. Construir o literal R com as fórmulas por indicador
  my $formulas_r_literal = "list(\n" . join(",\n", map {
    my $code = $_;
    my $f = formula_for($code);
    qq{    $code = list(rhs = "$f->{rhs}", null_rhs = "$f->{null_rhs}")};
  } @codes) . "\n  )";

  # 5. Construir script R dinâmico injetando as estatísticas e gerando JSON no final
  my $r_codes_array = "c(" . join(',', map { "'$_'" } @codes) . ")";
  my $script_conteudo = <<~"EOS";
  library(jsonlite)
  $r_df_definition
  codes <- $r_codes_array
  formulas <- $formulas_r_literal
  results <- list()
  for (code in codes) {
    f <- formulas[[code]]

    # Correlação de Spearman - univariada (indicador vs nota), não é
    # afetada por confundidores/fórmula
    sp <- cor.test(df[[code]], df\$nota, method='spearman', exact=FALSE)
    rho <- as.numeric(sp\$estimate)
    p_val <- as.numeric(sp\$p.value)

    # Modelo completo (indicador + confundidores da fórmula) vs modelo
    # nulo (só os confundidores, ou só o intercepto quando não há)
    fit_full <- lm(as.formula(paste("nota ~", f\$rhs)), data = df)
    fit_null <- lm(as.formula(paste("nota ~", f\$null_rhs)), data = df)

    r2_full <- as.numeric(summary(fit_full)\$r.squared)
    r2_null <- as.numeric(summary(fit_null)\$r.squared)
    r2_gain <- r2_full - r2_null

    rmse_full <- as.numeric(sqrt(mean(fit_full\$residuals^2)))
    rmse_null <- as.numeric(sqrt(mean(fit_null\$residuals^2)))
    rmse_gain <- if (rmse_null > 0) (rmse_null - rmse_full) / rmse_null else 0

    # Coeficiente e p-valor PRÓPRIOS do termo do indicador dentro do
    # modelo completo (controlando pelos confundidores, quando houver) -
    # diagnóstico complementar ao rho univariado
    coefs <- summary(fit_full)\$coefficients
    coef_val <- if (code %in% rownames(coefs)) as.numeric(coefs[code, "Estimate"]) else NA
    coef_p   <- if (code %in% rownames(coefs)) as.numeric(coefs[code, "Pr(>|t|)"]) else NA

    # SEM TRATAMENTO SILENCIOSO DE NA: Deixamos estourar se houver inconsistência nos vetores
    results[[code]] <- list(
      rho = rho,
      p_val = p_val,
      r2 = r2_full,
      r2_null = r2_null,
      r2_gain = r2_gain,
      rmse = rmse_full,
      rmse_null = rmse_null,
      rmse_gain = rmse_gain,
      coef = coef_val,
      coef_p = coef_p,
      formula = f\$rhs
    )
  }
  cat(jsonlite::toJSON(results, auto_unbox=TRUE))
  quit(status = 0)
  EOS

  # 6. Executar via Pipe nativo do EduMaps
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

  # 7. Exibir a tabela de resultados com dados da baseline incluídos
  my $table = Text::Table->new(
    'Indicador', 'Fórmula', 'ρ (Spearman)', 'p-valor', 'R² (modelo)', 'R² ganho', 'Ganho RMSE %'
  );
  for my $code (@codes) {
    my $res  = $r_out->{$code};

    my $rho      = defined $res->{rho}      ? sprintf("%.3f", $res->{rho})      : 'NaN';
    my $p_val    = defined $res->{p_val}    ? sprintf("%.4f", $res->{p_val})    : 'NaN';
    my $r2       = defined $res->{r2}       ? sprintf("%.3f", $res->{r2})       : 'NaN';
    my $r2_gain  = defined $res->{r2_gain}  ? sprintf("%.3f", $res->{r2_gain})  : 'NaN';
    my $gain     = defined $res->{rmse_gain} ? sprintf("%.1f%%", $res->{rmse_gain} * 100) : '0.0%';
    $table->add($code, $res->{formula} // $code, $rho, $p_val, $r2, $r2_gain, $gain);
  }
  diag("\n" . $table);

  # 8. Assertivas baseadas nos critérios de relevância (ver funções acima)
  for my $code (@codes) {
    my $res  = $r_out->{$code};
    if (!defined $res->{rho} || !defined $res->{p_val} || !defined $res->{r2_gain}) {
      fail("$code REPROVADO: Dados estatísticos inválidos ou corrompidos (NA gerado no R).");
      next;
    }
    my $msg = sprintf(
      "%s [%s]: rho=%.2f (p=%.3f), R²ganho=%.3f, Ganho RMSE=%.1f%% (diagnóstico, não é critério)",
      $code, $res->{formula} // $code, $res->{rho}, $res->{p_val}, $res->{r2_gain}, ($res->{rmse_gain} // 0) * 100
    );
    ok(indicator_is_relevant($res), "Validação de relevância para: $msg")
      or diag(join("\n",
        sprintf("  -> significância (p < %.2f): %s (p=%.4f)",
          $thresholds{p_max}, is_significant($res) ? 'OK' : 'FALHOU', $res->{p_val}),
        sprintf("  -> associação monotônica (rho >= %.2f): %s (rho=%.3f)",
          $thresholds{rho_min}, has_monotonic_association($res) ? 'OK' : 'FALHOU', $res->{rho}),
        sprintf("  -> poder explicativo incremental (r2_gain >= %.2f): %s (r2_gain=%.3f, r2_modelo=%.3f, r2_nulo=%.3f)",
          $thresholds{r2_min}, has_explanatory_power($res) ? 'OK' : 'FALHOU',
          $res->{r2_gain}, $res->{r2} // 0, $res->{r2_null} // 0),
      ));
  }
};

done_testing;
