use strict;
use warnings;
use utf8;
use lib qw(t/lib lib);
use Imports;
use CI;
# Qualidade dos indicadores de condição da escola (IFS, IPS, IGE, IAI).
#
# Eles medem condições e direitos (infraestrutura, recursos pedagógicos,
# gestão democrática, acessibilidade), não resultado. Por isso o teste NÃO
# exige que prevejam o IDEB: exige que sirvam para descrever escolas, ou seja,
# que tenham variação, não fiquem colados no teto ou no zero e não dependam de
# campos ausentes (que o `clean_value` conta como 0). A relação com o IDEB sai
# como diagnóstico, por etapa e descontando o nível socioeconômico (nota
# técnica 183 e docs/analises/ivet.md, §2.3.1).
#
# BEGIN porque os `use ok` rodam em tempo de compilação e emitem testes.
BEGIN { CI->skip_r('qualidade dos indicadores comparada no R') }
use ok 'EduMaps::Schema';
use ok 'EduMaps::Analysis::R::Pipe';
use ok 'EduMaps::Model::Indicator::School::IFS';
use ok 'EduMaps::Model::Indicator::School::IPS';
use ok 'EduMaps::Model::Indicator::School::IGE';
use ok 'EduMaps::Model::Indicator::School::IAI';

use Mojo::File qw(tempfile);
use Text::Table;

# UFs de regiões diferentes: um município só (o teste antigo usava Brasília)
# tem condições parecidas entre escolas e achata qualquer associação.
my @UFS    = qw(DF SP BA PA RS);
my $ANO    = 2023;
my %limite = (
  n_min_etapa   => 200,    # linhas escola×etapa por etapa
  dp_min        => 0.05,   # desvio-padrão mínimo do indicador
  teto_max      => 0.50,   # fração máxima de escolas no valor 1
  zero_max      => 0.50,   # fração máxima de escolas no valor 0
  ausente_max   => 0.10,   # fração máxima de escolas com campo ausente
);

my @indicators = map { "EduMaps::Model::Indicator::School::$_"->new } qw(IFS IPS IGE IAI);
my @codes      = map { $_->code } @indicators;

# Colunas do Censo que cada indicador lê (as closures leem colunas próprias,
# declaradas em extra_cols).
my %colunas;
for my $ind (@indicators) {
  for my $par ($ind->weights->@*) { $colunas{ $par->[0] } = 1 unless ref $par->[0] }
  $colunas{$_} = 1 for $ind->extra_cols->@*;
}
my @colunas = sort keys %colunas;

my $dbh = EduMaps::Schema->go->storage->dbh;
my $sql = sprintf <<~'SQL', join ',', map {"e.$_"} @colunas;
  SELECT e.co_entidade, e.sg_uf, e.tp_dependencia, i.etapa, i.nota_media,
         inse.media_inse, %s
    FROM clean.censo_escolas e
    JOIN clean.ideb_notas_escolas i
      ON i.id_escola = e.co_entidade AND i.ano = ? AND i.nota_media > 0
    LEFT JOIN clean.inse inse ON inse.id_escola = e.co_entidade
   WHERE e.tp_situacao_funcionamento = 1 AND e.sg_uf = ANY(?)
  SQL

my $sth = $dbh->prepare($sql);
$sth->execute($ANO, \@UFS);

# Uma linha por escola×etapa: o IDEB tem escala diferente em cada etapa
# (fundamental I, II e médio), então nunca se misturam etapas numa correlação.
my $csv = tempfile(SUFFIX => '.csv');
my $fh  = $csv->open('>:encoding(UTF-8)');
print $fh join(',', qw(co_entidade sg_uf dependencia etapa nota media_inse n_ausente), @codes), "\n";
my %linhas_por_etapa;
while (my $r = $sth->fetchrow_hashref) {
  my $ausentes = grep { !defined $r->{$_} } @colunas;
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
my $arquivo = $csv->to_string;
my $script  = <<~"EOS";
  library(jsonlite)
  d <- read.csv('$arquivo', stringsAsFactors = FALSE)
  codes <- $r_codes
  z <- function(x) (x - mean(x)) / sd(x)

  # Distribuição: uma linha por escola.
  u <- d[!duplicated(d\$co_entidade), ]
  dist <- lapply(setNames(codes, codes), function(k) list(
    media   = mean(u[[k]]),
    dp      = sd(u[[k]]),
    teto    = mean(u[[k]] >= 0.9999),
    zero    = mean(u[[k]] == 0),
    rho_ise = cor(u[[k]], u\$media_inse, method = 'spearman', use = 'complete.obs')
  ))

  # Associação com o IDEB, por etapa: bruta (Spearman) e ajustada (coeficiente
  # padronizado descontando INSE, UF e rede).
  etapas <- sort(unique(d\$etapa))
  assoc <- lapply(setNames(etapas, etapas), function(e) {
    x <- d[d\$etapa == e, ]
    xa <- x[!is.na(x\$media_inse), ]
    lapply(setNames(codes, codes), function(k) {
      bruto <- cor(x[[k]], x\$nota, method = 'spearman')
      ajust <- if (nrow(xa) > 30 && sd(xa[[k]]) > 0) {
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

# Construto: variação e cobertura (critérios de aprovação).
cmp_ok($r->{ausente}, '<=', $limite{ausente_max},
  sprintf 'campos ausentes em %.1f%% das escolas', 100 * $r->{ausente});

my $tab_dist = Text::Table->new('Indicador', 'média', 'dp', 'no teto', 'no zero', 'ρ com INSE');
for my $code (@codes) {
  my $d = $r->{dist}{$code};
  $tab_dist->add($code, map({ sprintf '%.2f', $_ } @$d{qw(media dp)}),
    map({ sprintf '%.0f%%', 100 * $_ } @$d{qw(teto zero)}), sprintf '%.2f', $d->{rho_ise} // 'NaN');
  subtest "$code: discrimina escolas" => sub {
    cmp_ok($d->{dp},   '>=', $limite{dp_min},   sprintf 'dp %.3f', $d->{dp});
    cmp_ok($d->{teto}, '<=', $limite{teto_max}, sprintf '%.1f%% no teto', 100 * $d->{teto});
    cmp_ok($d->{zero}, '<=', $limite{zero_max}, sprintf '%.1f%% no zero', 100 * $d->{zero});
  };
}
diag "\nDistribuição (uma linha por escola)\n" . $tab_dist;

# Relação com o IDEB: diagnóstico, não critério. Com os dados de 2023 a
# correlação bruta é moderada, mas quase toda vem do nível socioeconômico;
# descontado ele, o efeito próprio fica perto de zero (nota técnica 183).
my $tab_assoc = Text::Table->new('Etapa', 'N', map { ("$_ bruto", "$_ ajust.") } @codes);
for my $etapa (sort keys $r->{assoc}->%*) {
  my $a = $r->{assoc}{$etapa};
  $tab_assoc->add($etapa, $a->{ $codes[0] }{n},
    map { my $s = $a->{$_}; (sprintf('%.2f', $s->{rho_bruto}),
      defined $s->{beta_ajustado} ? sprintf('%.2f', $s->{beta_ajustado}) : '-') } @codes);
  for my $code (@codes) {
    ok(defined $a->{$code}{rho_bruto}, "$etapa/$code: correlação calculada (sem NA)");
  }
}
diag "\nAssociação com o IDEB (ρ de Spearman bruto; β padronizado descontando INSE, UF e rede)\n" . $tab_assoc;

done_testing;
