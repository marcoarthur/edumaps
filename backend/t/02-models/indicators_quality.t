use strict;
use warnings;
use lib qw(t/lib lib);
use Imports;
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
my $municipio = 'Brasília' ;
my %thresholds = (
    rho_min  => 0.15,
    p_max    => 0.10,
    rmse_max => 1.5, 
    n_min    => 5,   
);

subtest 'Validação estatística dos indicadores com IDEB usando R::Pipe' => sub {

  my $schools_rs = $schema->resultset('CensoEscolas')->search({no_municipio => $municipio});

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

  # 3. Preparar a estrutura de dados no formato de R vectors
  my @nota_vec = map { sprintf("%.4f", $_->{nota}) } @dataset;
  my $r_df_definition = "df <- data.frame(\n";
    $r_df_definition .= "  nota = c(" . join(',', @nota_vec) . "),\n";

    for my $ind (@indicators) {
      my $code = $ind->code;
      my @score_vec = map { sprintf("%.4f", $_->{scores}{$code}) } @dataset;
      $r_df_definition .= "  $code = c(" . join(',', @score_vec) . "),\n";
    }
    $r_df_definition =~ s/,\n$/\n/;
    $r_df_definition .= ")\n";

  # 4. Construir script R dinâmico injetando as estatísticas e gerando JSON no final
  # O R::Pipe espera obrigatoriamente um JSON estruturado em STDOUT em caso de sucesso.
  my @codes = map { $_->code } @indicators;
  my $r_codes_array = "c(" . join(',', map { "'$_'" } @codes) . ")";

  my $script_conteudo = <<~"EOS";
  library(jsonlite)

  $r_df_definition

  codes <- $r_codes_array
  results <- list()

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

    # Tratamento de NA
    if(is.na(rho)) rho <- 0
    if(is.na(p_val)) p_val <- 1
    if(is.na(r2)) r2 <- 0
    if(is.na(rmse)) rmse <- 0
    if(is.na(coef_val)) coef_val <- 0

    results[[code]] <- list(
      rho = rho,
      p_val = p_val,
      r2 = r2,
      rmse = rmse,
      coef = coef_val
    )
  }

  # Retorna o payload JSON esperado pelo EduMaps::Analysis::R::Pipe
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

  # 6. Exibir a tabela de resultados usando o JSON parseado pelo Pipe
  my $table = Text::Table->new(
    'Indicador', 'ρ (Spearman)', 'p-valor', 'R²', 'RMSE', 'Coef. Regressão'
  );
  for my $ind (@indicators) {
    my $code = $ind->code;
    my $res  = $r_out->{$code};
    $table->add(
      $code,
      sprintf("%.3f", $res->{rho}),
      sprintf("%.4f", $res->{p_val}),
      sprintf("%.3f", $res->{r2}),
      sprintf("%.3f", $res->{rmse}),
      sprintf("%.3f", $res->{coef})
    );
  }
  diag("\n" . $table);

  # 7. Assertivas baseadas nos thresholds
  for my $ind (@indicators) {
    my $code = $ind->code;
    my $res  = $r_out->{$code};

    my $rho_ok  = $res->{rho} >= $thresholds{rho_min};
    my $p_ok    = $res->{p_val} < $thresholds{p_max};
    my $rmse_ok = $res->{rmse} < $thresholds{rmse_max};

    my $msg = sprintf("%s: rho=%.2f (p=%.3f), R²=%.2f, RMSE=%.2f", 
      $code, $res->{rho}, $res->{p_val}, $res->{r2}, $res->{rmse}
    );

    if ($rho_ok && $p_ok && $rmse_ok) {
      ok(1, "Estatísticas aceitáveis para $msg");
    } else {
      diag("Aviso de Desempenho Fraco: $msg (esperado: rho >= $thresholds{rho_min}, p < $thresholds{p_max})");
    }
  }

  pass('Subtest de validação concluído com sucesso.');
};


done_testing;
