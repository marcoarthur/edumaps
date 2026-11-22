package EduMaps::Model::Ivet::Versao;
use strict;
use warnings;
use utf8;

# Versão citável do IVET (#489, RK-02), publicada em /fontes como a dos
# índices (#462). A fórmula vive no pacote R (`ivet_versao()` em
# analysis/edumapsr/R/ivet.R); este registro é o espelho que a API publica.
#
# Mudou a versão do IVET → atualizar no mesmo PR os quatro lugares:
# `ivet_versao()` (R), `formula` de inst/ivet-card.yml, o cabeçalho de
# docs/analises/ivet.md e o topo de @HISTORICO abaixo.
# t/02-models/ivet_versao.t falha se divergirem.

our @HISTORICO = (
  { versao => 'ivet-v1.9', data => '2026-11-22',
    mudou => 'Bloco A: na capacitação docente, a parte de concursados fica de fora nas escolas privadas, onde o Censo não pergunta o vínculo, com o peso redistribuído (indices-v7, #524).' },
  { versao => 'ivet-v1.8', data => '2026-11-17',
    mudou => 'Bloco A: na capacidade gestora, a parte de gestores por aluno fica de fora sem matrícula e a de acesso ao cargo nas privadas, com o peso redistribuído (indices-v6, #475).' },
  { versao => 'ivet-v1.7', data => '2026-11-17',
    mudou => 'Bloco A: a lotação da capacidade de atendimento passou a ser por sala e por turno (indices-v5, #473).' },
  { versao => 'ivet-v1.6', data => '2026-11-17',
    mudou => 'Bloco A: a diversidade de cor/raça passou a ser sobre as matrículas com cor declarada (indices-v4, #471).' },
  { versao => 'ivet-v1.5', data => '2026-11-17',
    mudou => 'Bloco A: escola sem registro de matrículas, docentes ou gestores fica sem o índice que depende dele, em vez de 0 (indices-v3, #467).' },
  { versao => 'ivet-v1.4', data => '2026-11-16',
    mudou => 'Bloco A: a inclusão da diversidade discente passou a ser a educação especial em classe comum; antes somava os turnos (#459).' },
  { versao => 'ivet-v1.3', data => '2026-11-10',
    mudou => 'Bloco C: escala logarítmica nos dois acessos (a pé e de carro). O bloco C ficou mais baixo; os valores não se comparam com os da v1.2 (#295).' },
  { versao => 'ivet-v1.2', data => '2026-10-17',
    mudou => 'Bloco B: a renda média do responsável entrou no cálculo padrão.' },
  { versao => 'ivet-v1.1', data => '2026-10-16',
    mudou => 'Bloco B: instrução e saneamento do entorno.' },
  { versao => 'ivet-v1.0', data => '2026-10-15',
    mudou => 'Primeira versão: sete blocos com peso igual; o IVET só sai com os blocos C, D e E.' },
);

our $VERSAO = $HISTORICO[0]{versao};

# Blocos territoriais mínimos (letras do painel): sem algum deles, o IVET não
# vira número. Espelho de `ivet_blocos_territoriais_minimos()` no R e de
# `blocos_territoriais_minimos` do card; o teste confere.
our @BLOCOS_TERRITORIAIS = qw(C D E);

1;
