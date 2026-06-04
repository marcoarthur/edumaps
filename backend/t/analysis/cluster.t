use Mojo::Base -signatures;
use Test2::V0; # Framework moderno recomendado. Se preferir, pode trocar por Test::More.
use PDL;
use EduMaps::Analysis::Clusterization;

# 1. Massa de teste sintética (3 grupos claros em 2D para testar K-Means)
my $dados_teste = [
  [0.1, 0.1], [0.15, 0.2],  # Grupo 1 (Valores baixos)
  [5.0, 5.1], [5.2,  4.9],  # Grupo 2 (Valores médios)
  [9.5, 9.8], [10.0, 9.2],  # Grupo 3 (Valores altos)
];

subtest 'Instanciação e Configuração Inicial' => sub {
  my $clusterer = EduMaps::Analysis::Clusterization->new(n_clusters => 3);
  isa_ok($clusterer, ['EduMaps::Analysis::Clusterization'], 'Instancia objeto com sucesso');
  is($clusterer->n_clusters, 3, 'Parâmetro n_clusters setado via construtor');
  is($clusterer->normalize, 1, 'Valor padrão de normalização é ativo (1)');
};

subtest 'Pipeline de Conversão de Dados e Normalização Interna' => sub {
  my $clusterer = EduMaps::Analysis::Clusterization->new(normalize => 1);

  # Testando _to_pdl com ArrayRef
  my $pdl = $clusterer->_to_pdl($dados_teste);
  isa_ok($pdl, ['PDL'], 'Conversão para objeto PDL');
  is([$pdl->dims], [2, 6], 'Shape do PDL correto (colunas, linhas) -> (vars, obs)');

  # Testando a normalização Min-Max
  my $pdl_norm = $clusterer->_normalize($pdl);
  is($pdl_norm->min, 0, 'Valor mínimo após normalização é exatamente 0');
  is($pdl_norm->max, 1, 'Valor máximo após normalização é exatamente 1');

  # Testando blindagem contra divisão por zero (coluna com valores idênticos)
  my $dados_constantes = [ [1.0, 5.0], [1.0, 5.0], [1.0, 5.0] ];
  my $pdl_const = $clusterer->_to_pdl($dados_constantes);
  my $pdl_const_norm = eval { $clusterer->_normalize($pdl_const) };

  is($@, '', 'Normalização não crasha com colunas sem variância');
};

subtest 'Execução do K-Means e Disparo de Eventos (Mojo::EventEmitter)' => sub {
  my $clusterer = EduMaps::Analysis::Clusterization->new(n_clusters => 3, random_seed => 42);

  # Hashes para capturar se os eventos foram disparados
  my %eventos_chamados;

  $clusterer->on(start => sub ($self, $args) {
      $eventos_chamados{start} = 1;
      is($args->{data_shape}, 'ARRAY', 'Evento start emite o tipo de dado correto');
    });

  $clusterer->on(loaded => sub ($self, $args) {
      $eventos_chamados{loaded} = 1;
      is($args->{dims}, [2, 6], 'Evento loaded envia as dimensões corretas do PDL');
    });

  $clusterer->on(clustered => sub ($self, $args) {
      $eventos_chamados{clustered} = 1;
      isa_ok($args->{clusters}, ['PDL'], 'Payload de clusters é um PDL');
      isa_ok($args->{centers},  ['PDL'], 'Payload de centros é um PDL');
      ok(exists $args->{r2}, 'Payload de R2 existe');
    });

  # Executa a clusterização
  my $res = $clusterer->cluster($dados_teste);

  # Validações do retorno
  ok($eventos_chamados{start}, 'Evento "start" foi disparado');
  ok($eventos_chamados{loaded}, 'Evento "loaded" foi disparado');
  ok($eventos_chamados{clustered}, 'Evento "clustered" foi disparado');

  is(ref($res), 'HASH', 'O retorno do método cluster é uma HashRef');
  is($res->{cluster}->nelem, 6, 'Retornou classificação para os 6 municípios');

  # Verifica se os elementos do mesmo grupo receberam o mesmo id de cluster
  is($res->{cluster}->at(0), $res->{cluster}->at(1), 'Grupo 1 caiu no mesmo cluster');
  is($res->{cluster}->at(2), $res->{cluster}->at(3), 'Grupo 2 caiu no mesmo cluster');
  is($res->{cluster}->at(4), $res->{cluster}->at(5), 'Grupo 3 caiu no mesmo cluster');
};

subtest 'Integração e Mock do DBIx::Class::ResultSet' => sub {
  my $clusterer = EduMaps::Analysis::Clusterization->new(n_clusters => 2);

  my @dados = (
    [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
    [1.1, 2.1, 3.1, 4.1, 5.1, 6.1],
    [0.9, 1.9, 2.9, 3.9, 4.9, 5.9],
    [2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
    [0.5, 1.5, 2.5, 3.5, 4.5, 5.5],
  );

  # Create an array of row mocks, each with numeric_features
  my @mock_rows;
  for my $scores (@dados) {
    my $row = mock {} => (
      add => [
        numeric_features => sub { $scores }
      ]
    );
    push @mock_rows, $row;
  }

  # Create a resultset mock that returns these rows via next
  my $iterator = 0;
  my $mock_rs = mock {} => (
    add => [
      next => sub {
        return $mock_rows[$iterator++];
      }
    ]
  );

  my $res = eval { $clusterer->cluster($mock_rs) };
  is($@, '', 'Módulo aceita e processa ResultSets sem erros');
  is($res->{cluster}->nelem, scalar(@dados), 'Processou todas as linhas mockadas');
};
done_testing;
