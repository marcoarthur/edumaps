use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Utils qw(random_city_id);
use Test::Mojo;
use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::School';
use open ':std', ':encoding(UTF-8)';

my $schema = EduMaps::Schema->go;
my $model = EduMaps::Model::School->new(schema => $schema);

my $tag = '[school model] clustering:';

subtest qq/
$tag <clustering baseado em quantiles - clustering simples no db>
 - listagem das escolas via geotagging (parametro codigo_ibge)
 - teste happy-day, pega 1 codigo_ibge existente e avalia resposta
/ => sub {
  my $id = random_city_id->first->codigo_ibge;
  my $result = $model->simple_cluster_school({codigo_ibge => $id});
  fail "cidade $id->{codigo_ibge} não tem escolas com notas" if $result->size == 0;
  
  like(
    $result->[0],
    hash {
      field cluster_id => qr/[0-9]/;
      field escolas => array {
        item '0' => hash {
          field aprovacao => number_ge(0) && number_le(100);
          field cluster_id => qr/[0-9]/;
          field escola => L();
          field latitude => L();
          field longitude => L();
          field municipio => L();
          field rede => L();
          field tendencia => L();
        };
        etc();
      };
     field media_aprovacao_percent => number_ge(0) && number_le(100);
     field media_ideb => number_ge(0) && number_le(10);
     field media_notas => number_ge(0) && number_le(10);
    },
    'Estrutura do cluster obedece contrato',
  );

  ok 1, "cidade $id passou no teste";
};


subtest qq/
$tag <clustering baseado em quantiles - clustering simples no db>
 - teste de performance do método
 - avalia tempo de resposta com uma cidade real
 - garante que o overhead de processamento do DB e decode JSON está sob controle
/ => sub {
  my $id = random_city_id->first->codigo_ibge;

  # 1. Marca o início do cronômetro
  my $t0 = [gettimeofday];

  my $result = $model->simple_cluster_school({ codigo_ibge => $id });

  # 2. Calcula o intervalo de tempo decorrido
  my $elapsed = tv_interval($t0);

  # 3. Asserções de sanidade e performance
  ok(defined $result, "Método executou com sucesso para a cidade $id");

  # Um limite saudável para queries analíticas locais/testes com CTEs complexas é 500ms (0.5s)
  my $threshold = 0.5;

  ok(
    $elapsed <=
    $threshold, 
    sprintf("Tempo de execução (%.4fs) ficou abaixo do limite aceitável (%.2fs)", $elapsed, $threshold)
  );

  # Diagnóstico útil no terminal se rodar com yath -v
  note sprintf("Performance Info -> Cidade: %s | Grupos gerados: %d | Tempo total: %.4f segundos", 
    $id, 
    $result ? $result->size : 0, 
    $elapsed
  );
};

done_testing;
