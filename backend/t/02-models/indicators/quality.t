use strict;
use warnings;
use utf8;
use lib qw(t/lib lib);
use Imports;
use CI;
# Qualidade do indicador de qualificação docente (IQD), com o nível
# socioeconômico (ISE) como referência.
#
# O IQD mede a formação do quadro docente (superior e pós-graduação), uma
# condição da escola, não um resultado. Por isso o teste NÃO exige que ele
# preveja o IDEB: exige que esteja em [0,1], tenha variação, não fique colado
# no teto ou no zero e não dependa de campos ausentes. A relação com o IDEB
# sai como diagnóstico, por etapa e descontando o nível socioeconômico (nota
# técnica 184 e docs/analises/ivet.md, §2.3.2). Mesmo molde de
# t/02-models/indicators_quality.t.
#
# BEGIN porque os `use ok` rodam em tempo de compilação e emitem testes.
BEGIN { CI->skip_r('qualificação docente comparada no R') }
use ok 'EduMaps::Schema';
use ok 'EduMaps::Analysis::R::Pipe';
use ok 'EduMaps::Model::Indicator::School::IQD';
use ok 'EduMaps::Model::Indicator::School::ISE';

use Mojo::File qw(tempfile);
use Text::Table;

# UFs de regiões diferentes: um município só (o teste antigo usava São José
# dos Campos) tem condições parecidas entre escolas e achata a associação.
my @UFS    = qw(DF SP BA PA RS);
my $ANO    = 2023;
my %limite = (
  n_min_etapa => 200,    # linhas escola×etapa por etapa
  dp_min      => 0.05,   # desvio-padrão mínimo do indicador
  teto_max    => 0.50,   # fração máxima de escolas no valor 1
  zero_max    => 0.50,   # fração máxima de escolas no valor 0
  ausente_max => 0.10,   # fração máxima de escolas com campo ausente
);

my $iqd = EduMaps::Model::Indicator::School::IQD->new;
my $ise = EduMaps::Model::Indicator::School::ISE->new;
my @indicators = ($iqd, $ise);
my @codes      = map { $_->code } @indicators;
# O ISE é o próprio nível socioeconômico: entra na distribuição e na
# correlação bruta como referência, nunca no ajuste por INSE.
my @ajustaveis = ($iqd->code);

my @col_docentes = $iqd->extra_cols->@*;

my $dbh = EduMaps::Schema->go->storage->dbh;
my $sql = sprintf <<~'SQL', join ',', map {"d.$_"} @col_docentes;
  SELECT e.co_entidade, e.sg_uf, e.tp_dependencia, i.etapa, i.nota_media,
         inse.media_inse, inse.inse_classificacao, %s
    FROM clean.censo_escolas e
    JOIN clean.ideb_notas_escolas i
      ON i.id_escola = e.co_entidade AND i.ano = ? AND i.nota_media > 0
    LEFT JOIN clean.inse inse ON inse.id_escola = e.co_entidade
    LEFT JOIN clean.censo_docentes d ON d.co_entidade = e.co_entidade
   WHERE e.tp_situacao_funcionamento = 1 AND e.sg_uf = ANY(?)
  SQL

my $sth = $dbh->prepare($sql);
$sth->execute($ANO, \@UFS);

# Uma linha por escola×etapa: o IDEB tem escala diferente em cada etapa.
my $csv = tempfile(SUFFIX => '.csv');
my $fh  = $csv->open('>:encoding(UTF-8)');
print $fh join(',', qw(co_entidade sg_uf dependencia etapa nota media_inse n_ausente), @codes), "\n";
my %linhas_por_etapa;
while (my $r = $sth->fetchrow_hashref) {
  my $ausentes = grep { !defined $r->{$_} } @col_docentes;
  print $fh join(',',
    @$r{qw(co_entidade sg_uf tp_dependencia etapa nota_media)},
    $r->{media_inse} // 'NA', $ausentes,
    map { $_->calculate($r) } @indicators), "\n";
  $linhas_por_etapa{ $r->{etapa} }++;
}
close $fh;

ok(scalar(keys %linhas_por_etapa), "há IDEB $ANO nas UFs @UFS")
  or do { done_testing; exit };
for my $etapa (sort keys %linhas_por_etapa) {
  cmp_ok($linhas_por_etapa{$etapa}, '>=', $limite{n_min_etapa},
    "amostra suficiente em $etapa ($linhas_por_etapa{$etapa} linhas)");
}

my $r_codes = 'c(' . join(',', map {"'$_'"} @codes) . ')';
my $r_ajust = 'c(' . join(',', map {"'$_'"} @ajustaveis) . ')';
my $arquivo = $csv->to_string;
my $script  = <<~"EOS";
  library(jsonlite)
  d <- read.csv('$arquivo', stringsAsFactors = FALSE)
  codes <- $r_codes
  ajustaveis <- $r_ajust
  z <- function(x) (x - mean(x)) / sd(x)

  u <- d[!duplicated(d\$co_entidade), ]
  dist <- lapply(setNames(codes, codes), function(k) list(
    media   = mean(u[[k]]),
    dp      = sd(u[[k]]),
    min     = min(u[[k]]),
    max     = max(u[[k]]),
    teto    = mean(u[[k]] >= 0.9999),
    zero    = mean(u[[k]] == 0),
    rho_ise = cor(u[[k]], u\$media_inse, method = 'spearman', use = 'complete.obs')
  ))

  etapas <- sort(unique(d\$etapa))
  assoc <- lapply(setNames(etapas, etapas), function(e) {
    x <- d[d\$etapa == e, ]
    xa <- x[!is.na(x\$media_inse), ]
    lapply(setNames(codes, codes), function(k) {
      bruto <- cor(x[[k]], x\$nota, method = 'spearman')
      ajust <- if (k %in% ajustaveis && nrow(xa) > 30 && sd(xa[[k]]) > 0) {
        f <- lm(z(nota) ~ z(xa[[k]]) + media_inse + factor(sg_uf) + factor(dependencia), data = xa)
        unname(coef(f)[2])
      } else NA
      list(n = nrow(x), rho_bruto = bruto, beta_ajustado = ajust)
    })
  })

  cat(toJSON(list(
    n_escolas = nrow(u),
    ausente   = mean(u\$n_ausente > 0),
    dist      = dist,
    assoc     = assoc
  ), auto_unbox = TRUE, na = 'null', digits = 6))
  EOS

my $r = eval { EduMaps::Analysis::R::Pipe->new->run({script => $script, paths => []}) };
ok($r, 'R devolveu as estatísticas') or do { diag $@; done_testing; exit };

diag sprintf "%d escolas de %s, IDEB %d", $r->{n_escolas}, join('/', @UFS), $ANO;

# Construto: escala, variação e cobertura (critérios de aprovação).
cmp_ok($r->{ausente}, '<=', $limite{ausente_max},
  sprintf 'campos de docentes ausentes em %.1f%% das escolas', 100 * $r->{ausente});

my $tab_dist = Text::Table->new('Indicador', 'média', 'dp', 'mín', 'máx', 'no teto', 'no zero', 'ρ com INSE');
for my $code (@codes) {
  my $d = $r->{dist}{$code};
  $tab_dist->add($code, map({ sprintf '%.2f', $_ } @$d{qw(media dp min max)}),
    map({ sprintf '%.0f%%', 100 * $_ } @$d{qw(teto zero)}), sprintf '%.2f', $d->{rho_ise} // 'NaN');
  subtest "$code: em [0,1] e discrimina escolas" => sub {
    cmp_ok($d->{min},  '>=', 0, sprintf 'mínimo %.3f', $d->{min});
    cmp_ok($d->{max},  '<=', 1, sprintf 'máximo %.3f', $d->{max});
    cmp_ok($d->{dp},   '>=', $limite{dp_min},   sprintf 'dp %.3f', $d->{dp});
    cmp_ok($d->{teto}, '<=', $limite{teto_max}, sprintf '%.1f%% no teto', 100 * $d->{teto});
    cmp_ok($d->{zero}, '<=', $limite{zero_max}, sprintf '%.1f%% no zero', 100 * $d->{zero});
  };
}
diag "\nDistribuição (uma linha por escola)\n" . $tab_dist;

# Relação com o IDEB: diagnóstico, não critério (nota técnica 184).
my %ajusta = map { $_ => 1 } @ajustaveis;
my $tab_assoc = Text::Table->new('Etapa', 'N',
  map { ("$_ bruto", $ajusta{$_} ? ("$_ ajust.") : ()) } @codes);
for my $etapa (sort keys $r->{assoc}->%*) {
  my $a = $r->{assoc}{$etapa};
  my @celulas;
  for my $code (@codes) {
    my $s = $a->{$code};
    push @celulas, sprintf('%.2f', $s->{rho_bruto});
    push @celulas, defined $s->{beta_ajustado} ? sprintf('%.2f', $s->{beta_ajustado}) : '-'
      if $ajusta{$code};
  }
  $tab_assoc->add($etapa, $a->{ $codes[0] }{n}, @celulas);
  for my $code (@codes) {
    ok(defined $a->{$code}{rho_bruto}, "$etapa/$code: correlação calculada (sem NA)");
  }
}
diag "\nAssociação com o IDEB (ρ de Spearman bruto; β padronizado descontando INSE, UF e rede)\n" . $tab_assoc;

done_testing;
