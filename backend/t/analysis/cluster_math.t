use Mojo::Base -signatures;
use Test2::V0;
use PDL;
use EduMaps::Analysis::Clusterization;

# ============================================================================
# FONTE DA VERDADE: Dados Sintéticos Controlados Matematicamente
# ============================================================================
my $dados_originais = [
  [ 0.0,  0.0 ], [ 0.1,  0.2 ], [ 0.2,  0.1 ], # Grupo Baixo
  [ 5.0,  5.0 ], [ 5.1,  5.2 ], [ 5.2,  5.1 ], # Grupo Médio
  [10.0, 10.0 ], [10.1, 10.2 ], [10.2, 10.1 ], # Grupo Alto
];

my $dados_normalizados_esperados = [
  [ 0.0,                  0.0 ],
  [ 0.1/10.2,             0.2/10.2 ],
  [ 0.2/10.2,             0.1/10.2 ],
  [ 5.0/10.2,             5.0/10.2 ],
  [ 5.1/10.2,             5.2/10.2 ],
  [ 5.2/10.2,             5.1/10.2 ],
  [ 10.0/10.2,            10.0/10.2 ],
  [ 10.1/10.2,            10.2/10.2 ],
  [ 10.2/10.2,            10.1/10.2 ],
];

my $clusterer = EduMaps::Analysis::Clusterization->new(n_clusters => 3, random_seed => 42);

subtest 'Verificação Estatística: Ingestão e Formato (_to_pdl)' => sub {
  my $pdl = $clusterer->_to_pdl($dados_originais);

  is([$pdl->dims], [2, 9], 'FONTE DA VERDADE: O PDL precisa ter shape [2, 9] (2 variáveis, 9 escolas)');
  is($pdl->at(0,0), 0.0, 'Valor [0,0] mapeado corretamente');
  is($pdl->at(0,8), 10.2, 'Valor [0,8] mapeado corretamente (fim da matriz)');
};

subtest 'Verificação Estatística: Normalização Matemática (_normalize)' => sub {
  my $pdl = $clusterer->_to_pdl($dados_originais);
  my $pdl_obtido = $clusterer->_normalize($pdl);

  for my $i (0..8) {
    for my $j (0..1) {
      my $val_obtido = $pdl_obtido->at($j, $i);
      my $val_esperado = $dados_normalizados_esperados->[$i][$j];

      # CORREÇÃO: Sintaxe correta do Test2::Tools::Compare::within
      is(
        $val_obtido, 
        Test2::Tools::Compare::within($val_esperado, 0.0001), 
        sprintf("Elemento [%d,%d] normalizado corretamente (Obtido: %.4f)", $i, $j, $val_obtido)
      );
    }
  }
};

subtest 'Verificação Estatística: Corretude da Divisão por Zero' => sub {
  my $dados_constantes = [ [1.0, 2.0], [1.0, 4.0], [1.0, 6.0] ];
  my $pdl_const = $clusterer->_to_pdl($dados_constantes);

  my $pdl_norm = eval { $clusterer->_normalize($pdl_const) };
  is($@, '', 'O código do módulo não pode estourar exceção com colunas constantes');

  my $coluna_com_zero = $pdl_norm->slice("0,:");
  ok(($coluna_com_zero == 0)->all, 'FONTE DA VERDADE: Variável sem variância deve ser zerada na normalização');
};

subtest 'Verificação Estatística: Consistência do Agrupamento K-Means' => sub {
  my $res = $clusterer->cluster($dados_originais);
  my $vector = $res->{cluster};

  # Validações de consistência geométrica dos grupos
  is($vector->at(0), $vector->at(1), 'Escola 0 e Escola 1 precisam estar no mesmo cluster');
  is($vector->at(1), $vector->at(2), 'Escola 1 e Escola 2 precisam estar no mesmo cluster');

  is($vector->at(3), $vector->at(4), 'Escola 3 e Escola 4 precisam estar no mesmo cluster');
  is($vector->at(4), $vector->at(5), 'Escola 4 e Escola 5 precisam estar no mesmo cluster');

  is($vector->at(6), $vector->at(7), 'Escola 6 e Escola 7 precisam estar no mesmo cluster');
  is($vector->at(7), $vector->at(8), 'Escola 7 e Escola 8 precisam estar no mesmo cluster');

  ok($vector->at(0) != $vector->at(3), 'Cluster do Grupo Baixo difere do Grupo Médio');
  ok($vector->at(3) != $vector->at(6), 'Cluster do Grupo Médio difere do Grupo Alto');

  ok($res->{r2} > 0.95, sprintf("FONTE DA VERDADE: O R² explicativo deve ser robusto (Obtido: %.4f)", $res->{r2}));
};

done_testing;
