package EduMaps::Model::Indicator::School::ISE;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

# Mapeamento fixo dos rotulos ordinais do INSE (metodologia nacional do
  # INEP, ja normatizada) para um nivel numerico 1..7. Como a classificacao
# ja e nacionalmente calibrada (nao e um corte relativo ao municipio),
# nao ha necessidade de normalizacao populacional aqui - diferente de uma
# metrica continua crua (tipo razao aluno-professor), que exigiria bounds
# ou z-score dependente da amostra.
my %INSE_LEVELS = (
  'Nível I'   => 1,
  'Nível II'  => 2,
  'Nível III' => 3,
  'Nível IV'  => 4,
  'Nível V'   => 5,
  'Nível VI'  => 6,
  'Nível VII' => 7,
);

has 'name'        => 'Nível Socioeconômico';
has 'code'        => 'ise';
has 'description' => 'Mede o nível socioeconômico médio dos alunos da escola, a partir da classificação nacional do INSE/INEP (Nível I a VII).';

# NOTA: escolas sem registro de INSE (cerca de 5% em Brasília, ex: escolas
  # muito pequenas ou fora do ciclo do SAEB) recebem score 0 aqui - o mesmo
# tipo de "zeragem por ausencia de dado" que causou o problema original
# nos indicadores de infraestrutura, so que numa fatia bem menor da
# amostra. Se isso se mostrar relevante no teste estatistico, considere
# excluir essas escolas do dataset de validacao em vez de zera-las
# (ao contrario de infraestrutura, ausencia de INSE nao significa
  # necessariamente "nivel socioeconomico ruim").
has 'weights'     => sub {
  [
    [ sub ($r) {
        my $label = $r->{inse_classificacao} // return 0;
        my $level = $INSE_LEVELS{$label} // return 0;
        return ($level - 1) / 6;
      }, 1
    ],
  ];
};

has extra_cols => sub { [qw(inse_classificacao)] };

1;
