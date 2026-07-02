use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::School';
use open ':std', ':encoding(UTF-8)';

my $schema = EduMaps::Schema->go;
my $model = EduMaps::Model::School->new(schema => $schema);

my $tag = '[school model] searching:';

subtest qq/
$tag <busca de escolas>
- listagem das escolas texto
/ => sub {

  my $params = { escola => 'EMEF' };  # deve encontrar várias escolas com "EMEF"
  my $results = $model->search($params);

  isa_ok($results, 'Mojo::Collection');
  ok( $results->size >0,qq{Encontrou pelo menos uma escola com "EMEF"}  );

  my $first = $results->first;
  is(
    $first,
    hash {
      field codigo_inep => L();
      field escola      => match(qr/EMEF/);
      field municipio   => L();
      field uf          => L();
      field endereco    => L();
      field telefone    => L();
      field whatsapp    => match(qr{^https://wa\.me/});
      field latitude    => number_gt(-90);
      field longitude   => number_gt(-180);
      field osm         => match(qr{^https://www\.openstreetmap\.org/});
      field tipo        => L();
      field porte_escola => E();
      field modalidades => E();
      etc();
    },
    'Estrutura correta para escola com "EMEF"'
  );
};

subtest 'busca por município (parcial)' => sub {
  my $params = { municipio => 'Ubatuba' };
  my $results = $model->search($params);

  isa_ok($results, 'Mojo::Collection');
  ok( $results->size >0,qq{Encontrou pelo menos uma escola com "EMEF"}  );

  my $first = $results->first;
  is(
    $first,
    hash {
      field codigo_inep => L();
      field escola      => L();
      field municipio   => match(qr/Ubatuba/i);
      field uf          => 'SP';
      field endereco    => L();
      field telefone    => L();
      field whatsapp    => match(qr{^https://wa\.me/});
      field latitude    => number_gt(-90);
      field longitude   => number_gt(-180);
      field osm         => match(qr{^https://www\.openstreetmap\.org/});
      field tipo        => L();
      field porte_escola => L();
      field modalidades => array { item L(); etc(); };
      etc();
    },
    'Estrutura correta para escola em Ubatuba'
  );
};

# 3. Busca combinada (escola + município)
subtest 'busca combinada (escola + município)' => sub {
  my $params = {
    escola    => 'Maria',
    municipio => 'Ubatuba'
  };

  my $results = $model->search($params);

  isa_ok($results, 'Mojo::Collection');
  ok( $results->size > 0, qq{Encontrou pelo menos uma escola com "EMEF"}  );

  if ($results->size > 0) {
    my $first = $results->first;
    like(
      $first,
      hash {
        field codigo_inep => L();
        field escola      => match(qr/Maria/i);
        field municipio   => match(qr/Ubatuba/i);
        field uf          => 'SP';
        field endereco    => L();
        field telefone    => L();
        field whatsapp    => match(qr{^https://wa\.me/});
        field latitude    => number_gt(-90);
        field longitude   => number_gt(-180);
        field osm         => match(qr{^https://www\.openstreetmap\.org/});
        field tipo        => L();
        field porte_escola => L();
        field modalidades => array { item L(); etc(); };
        etc();
      },
      'Estrutura correta para escola com "EMEF" em Ubatuba'
    );
  } else {
    pass('Nenhuma escola encontrada com EMEF em Ubatuba (pular)');
  }
};

# 4. Busca sem parâmetros (deve falhar)
subtest 'busca sem parâmetros (deve falhar)' => sub {
  like(
    dies { $model->search({}) },
    qr/Sem parâmetros válidos/,
    'Mensagem de erro correta'
  );
};

# 5. Busca com parâmetros vazios ou muito curtos (deve falhar)
subtest 'busca com termo curto (menos de 3 caracteres)' => sub {
  my $params = { escola => 'EM' };  # menor que 3
  like(
    dies {$model->search($params)},
    qr/Erro dos parametros/, 
    'Mensagem de erro correta'
  );
};

# 6. Busca com termo que não existe
subtest 'busca com termo que não existe' => sub {
  my $params = { escola => 'ESCOLA_INEXISTENTE_XYZ' };
  my $results = $model->search($params);

  isa_ok($results, 'Mojo::Collection');
  is(scalar @$results, 0, 'Nenhuma escola encontrada');
};

done_testing;
