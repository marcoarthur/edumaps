package CI;
use Mojo::Base -strict, -signatures;

# ---------------------------------------------------------------------------
# Guardas de ambiente para a suíte Perl
#
# O objetivo é que o CI rode a MESMA suíte de t/, sem um arquivo paralelo de
# testes "de CI" — mas sem depender do banco de desenvolvimento (765 MB, dados
# de produção) nem de serviços externos. Os testes declaram aqui o que precisam;
# em dev as guardas são no-op e nada muda.
#
# O sinalizador é EDUMAPS_FIXTURES=1, setado pelo workflow .github/workflows/
# backend-tests.yml. Sem ele, tudo passa direto.
#
#   EDUMAPS_FIXTURES=1 prove -r -l t/
#
# Duas armadilhas que já custaram tempo, vale não repetir:
#
# 1. Chame sempre com parênteses — `CI->skip_r('motivo')`. Sem eles o Perl
#    lê `CI->skip_r 'motivo'` como a sintaxe de objeto indireto e morre com
#    "String found where operator expected".
#
# 2. Use `Test::More::plan(skip_all => ...)`, não `Test::More::skip_all(...)`.
#    O Test::Builder que vem com o Test2 (Perl >= 5.26) trata as duas de forma
#    diferente: skip_all sai com status 255 e o prove reclama "No plan found in
#    TAP output". `plan(skip_all => ...)` é o caminho comum entre Test::More e
#    Test2::V0 e sai com 0.
# ---------------------------------------------------------------------------

use Test::More ();

# Verdadeiro quando a suíte roda contra o banco de fixtures (db/fixtures/).
sub fixtures { return $ENV{EDUMAPS_FIXTURES} ? 1 : 0 }

sub _skip ($motivo) { Test::More::plan(skip_all => "CI/fixtures: $motivo") }

# Pula a suíte inteira com a razão, mas só no banco de fixtures. Para o que
# precisa de volume de dados (o fixture tem 18 municípios, não 5570).
#
#   CI->skip_fixtures('kmeans exige N>=8 escolas com nota por município');
sub skip_fixtures ($self, $motivo) {
  return unless fixtures();
  _skip($motivo);
}

# Precisa do R (edumapsr) e das tabelas que SÓ o job de análise popula.
# `clean.school_indicators` nasce vazia: nenhuma migration a preenche, é o R
# que roda depois do deploy. Vale para quality, analytics, clustering,
# similarity, injeção de relações e rpipe.
sub skip_r ($self, $motivo) {
  return unless fixtures();
  _skip("exige R/edumapsr e as tabelas do job de analise - $motivo");
}

# Executa o R NO HOST (R::Pipe/Rscript) e precisa do pacote edumapsr
# instalado nele. Vale fora do CI também: sem o pacote, o job falha no R e o
# teste cai com um erro que parece de código. Para rodar de verdade, instalar
# o pacote no R do host (ver AGENTS.md, "Running tests (backend)").
#
#   CI->skip_r_host('clustering por kmeans executado no R');
my $edumapsr_no_host;
sub edumapsr_no_host {
  $edumapsr_no_host //= do {
    my $rc = system('Rscript', '-e',
      'quit(status = if (requireNamespace("edumapsr", quietly = TRUE)) 0 else 1)');
    $rc == 0 ? 1 : 0;
  };
}

sub skip_r_host ($self, $motivo) {
  $self->skip_r($motivo);    # no CI: mesma razão de sempre
  return if edumapsr_no_host();
  Test::More::plan(skip_all =>
    "exige o pacote edumapsr instalado no R do host (R CMD INSTALL analysis/edumapsr) - $motivo");
}

# Precisa da rede (Overpass/OSM, SIOPE). Nenhum espelho em CI.
sub skip_network ($self, $motivo) {
  return unless fixtures();
  _skip("exige servico externo - $motivo");
}

# Precisa do schema `staging`, que é criado pelo tooling de dev e não por
# migration — o `sqitch deploy` do fixture não o produz.
sub skip_staging ($self, $motivo) {
  return unless fixtures();
  _skip("exige o schema staging - $motivo");
}

1;
