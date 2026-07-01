use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use EduMaps::Schema;
use EduMaps::Model::School;
use open ':std', ':encoding(UTF-8)';
use utf8;

my $schema = EduMaps::Schema->go;
my $model = EduMaps::Model::School->new(schema => $schema);

subtest q{[school model] profile: informacão básica de uma escola} => sub {

  # --- 1. Código INEP existente ---
  my $info = $model->info({ codigo_inep => 35011162 });
  ok(defined $info, 'Busca por código existente retorna algo definido');

  is(
    $info,
    hash {
      field codigo_inep  => L();
      field escola       => L();
      field municipio    => L();
      field uf           => L();
      field endereco     => L();
      field telefone     => L();
      field whatsapp     => match(qr{^https://wa\.me/});
      field latitude       => number_gt(-90) && number_lt(90);
      field longitude      => number_gt(-180) && number_lt(180);
      field osm          => match(qr{^https://www\.openstreetmap\.org/});
      field tipo         => L();
      field porte_escola => L();
      field modalidades  => array { item L(); etc(); };
      etc();   # permite campos extras, caso apareçam
    },
    'Estrutura da resposta de info está correta'
  );

  # --- 2. Código INEP inexistente ---
  my $info_invalido = $model->info({ codigo_inep => 99999999 });
  ok(!defined $info_invalido, 'Busca por código inexistente retorna undef');
};

done_testing;
