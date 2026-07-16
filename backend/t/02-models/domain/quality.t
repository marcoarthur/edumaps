use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::Domain::SchoolQuality';
use open ':std', ':encoding(UTF-8)';
use utf8;

my $schema = EduMaps::Schema->go;
my $tag = '[school quality] índices:';

# local $SIG{__WARN__} = sub {
#   my $msg = shift;
#   die $msg;
# };

my $municipio = 'Ubatuba' ;

subtest qq/
$tag <cálculo dos índices para município $municipio>
 - verifica estrutura e intervalos
/ => sub {
  my $sq = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag         => $municipio,
    null_treatment  => 'imputation',
    schema          => $schema,
    id_column       => 'co_entidade',
  );

  # Testa cada índice individualmente
  for my $method (qw(ifs itd ips ige iai ioc)) {
    my $scores = $sq->$method;
    ok($scores, "Método $method retornou uma coleção");
    isa_ok($scores, 'Mojo::Collection');
    cmp_ok($scores->size, '>=', 1, "$method: pelo menos uma escola no município");

    #Verifica se todos os scores estão entre 0 e 1 (escala padrão)
    $scores->each(sub ($score,$idx) {
      cmp_ok($score, '>=', 0, "$method: score >= 0");
      cmp_ok($score, '<=', 1, "$method: score <= 1");
    });
  }

  # Testa o método all_scores
  my $all = $sq->all_scores;
  ok($all, "all_scores retornou uma coleção");
  isa_ok($all, 'Mojo::Collection');
  cmp_ok($all->size, '>=', 1, "all_scores: tamanho compatível");

  $all->each(sub ($scores_hash,$idx) {
    # Verifica se é um hashref com as chaves esperadas
    like(
      $scores_hash,
      hash {
        field ifs => number_ge(0);
        field itd => number_ge(0);
        field ips => number_ge(0);
        field ige => number_ge(0);
        field iai => number_ge(0);
        field ioc => number_ge(0);
        etc();
      },
      'Estrutura de all_scores contém todos os índices'
    );
    # Verifica limites superiores (≤ 1)
    for my $key (qw(ifs itd ips ige iai ioc)) {
      cmp_ok($scores_hash->{$key}, '<=', 1, "Chave $key <= 1");
    }
  });

};

subtest qq/
$tag <tratamento de nulos>
 - compara imputation vs discard
/ => sub {
  my $sq_imp = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag        => $municipio,
    null_treatment => 'imputation',
    schema         => $schema,
    id_column      => 'co_entidade',
  );
  my $sq_disc = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag        => $municipio,
    null_treatment => 'discard',
    schema         => $schema,
    id_column      => 'co_entidade',
  );

  # O discard deve retornar no máximo o mesmo número de escolas que o imputation
  cmp_ok($sq_disc->ifs->size, '<=', $sq_imp->ifs->size,
         'discard filtra escolas com nulos (≤ imputation)');

  # Verifica que discard não retorna scores undef
  $sq_disc->ifs->each(sub ($score, $idx) {
    ok(defined $score, 'discard: score definido');
  });

};


subtest qq/
$tag <testando similaridade>
  - implementação Perl puro
/ => sub {
  my $sq = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag        => $municipio,
    null_treatment => 'discard',
    schema => $schema,
    id_column => 'co_entidade',
  );

  my $all_scores = $sq->all_scores;
  ok($all_scores, "all_scores retornou dados");
  cmp_ok($all_scores->size, '>=', 2, "Pelo menos duas escolas para testar similaridade");

  # Encontra uma escola com vetor não-nulo (para usar como referência)
  my $ref_school;
  for my $school ($all_scores->each) {
    my $sum = $school->{ifs} + $school->{itd} + $school->{ips} +
    $school->{ige} + $school->{iai} + $school->{ioc};
    if ($sum > 0) {
      $ref_school = $school;
      last;
    }
  }

  # Se nenhuma escola com dados existir, pula o teste
  if (!$ref_school) {
    plan skip_all => "Nenhuma escola com dados disponíveis para testar similaridade";
    return;
  }

  # --- Teste normal (vetor não-nulo) ---
  my $similar = $sq->find_similar_schools($ref_school->{escola}, 5);
  ok($similar, "find_similar_schools retornou uma coleção");
  isa_ok($similar, 'Mojo::Collection');
  cmp_ok($similar->size, '<=', 5, "Retornou no máximo 5 escolas");

  # Verifica a estrutura do primeiro resultado
  my $closest = $similar->first;
  ok($closest->{record}{co_entidade}, "Resultado contém co_entidade");
  ok($closest->{record}{no_entidade}, "Resultado contém no_entidade");

  # Verifica ordenação crescente das distâncias
  my @distances = map { $_->{distance} } $similar->each;
  for my $i (1 .. $#distances) {
    cmp_ok($distances[$i], '>=', $distances[$i-1],
      "Distâncias em ordem crescente ($distances[$i-1] <= $distances[$i])");
  }

};

subtest qq/
$tag <novas distâncias entre vetores>
 - valida manhattan e chebyshev matematicamente e via busca
/ => sub {
  my $sq = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag        => $municipio,
    null_treatment => 'discard',
    schema => $schema,
    id_column => 'co_entidade',
  );

  # 1. Teste Unitário Matemático Direto
  # Vetores de teste bem conhecidos
  my $v1 = [ 1.0, 0.8, 0.6, 0.8, 0.5, 0.7 ];
  my $v2 = [ 0.8, 0.8, 0.2, 1.0, 0.5, 0.9 ];
  
  # Diferenças absolutas por posição:
  # [ 0.2,  0.0,  0.4,  0.2,  0.0,  0.2 ]
  # Soma (Manhattan) = 1.0
  # Máxima (Chebyshev) = 0.4

  my $dist_manhattan = $sq->_manhattan_distance($v1, $v2);
  is(sprintf("%.2f", $dist_manhattan), "1.00", "Manhattan: matemática está correta (soma das diferenças)");

  my $dist_chebyshev = $sq->_chebyshev_distance($v1, $v2);
  is(sprintf("%.2f", $dist_chebyshev), "0.40", "Chebyshev: matemática está correta (pior diferença individual)");


  # 2. Teste de Integração Dinâmica no find_similar_schools
  my $all_scores = $sq->all_scores;
  if ($all_scores->size < 2) {
    plan skip_all => "Escolas insuficientes para rodar testes de integração de distâncias";
    return;
  }

  my $ref_school = $all_scores->first;

  # A. Instanciação/Busca usando Manhattan
  my $sq_manhattan = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag        => $municipio,
    null_treatment => 'discard',
    metric         => 'manhattan',
    schema         => $schema,
    id_column      => 'co_entidade',
  );

  my $manhattan = $sq_manhattan->find_similar_schools($ref_school->{escola}, 3);
  ok($manhattan, "Busca usando métrica _manhattan_distance executada com sucesso");
  ok(
    $manhattan->first->{record}{co_entidade} != $ref_school->{escola}{co_entidade},
    "Manhattan: escola mais próxima NÃO é ela mesma"
  );

  # B. Instanciação/Busca usando Chebyshev
  my $sq_chebyshev = EduMaps::Model::Domain::SchoolQuality->new(
    geo_tag        => $municipio,
    null_treatment => 'discard',
    metric         => 'chebyshev',
    id_column      => 'co_entidade',
    schema         => $schema,
  );

  my $chebyshev = $sq_chebyshev->find_similar_schools($ref_school->{escola}, 3);
  ok($chebyshev, "Busca usando métrica _chebyshev_distance executada com sucesso");
  ok(
   $chebyshev->first->{record}{co_entidade} != $ref_school->{escola}{co_entidade},
   "Chebyshev: escola mais próxima NÃO é ela mesma"
  );
};

done_testing;
