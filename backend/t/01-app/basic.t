use Mojo::Base -strict, -signatures;
use lib qw(./lib ./t/lib);
use Imports;
use Test::Mojo;
use EduMaps;

my $t = Test::Mojo->new('EduMaps');

subtest 'custom validations - is_ibge_code' => sub {
  my $vv = $t->app->validator;
  isa_ok $vv, 'Mojolicious::Validator';

  my @valid = qw(1100015 1200401 1302603 1501402);

  for my $ibge (@valid) {
    my $v = $vv->validation;
    $v->input({ ibge => $ibge });
    $v->required('ibge')->is_ibge_code;
    is $v->has_error, F, "valid IBGE: $ibge";
  }

  my @invalid = (
    '123456',      # 6 dígitos
    '123456789',   # 9 dígitos
    'abc1234',     # letras
    '12.3456',     # ponto
    '12-345',      # traço
    '123 456',     # espaço
    '',            # vazio
    undef,         # indefinido
    '1234abc',     # mistura
    '1100015 ',    # espaço no final
    ' 1100015',    # espaço no início
    '1100015x',    # letra no final
  );

  for my $ibge (@invalid) {
    my $v = $vv->validation;
    $v->input({ ibge => $ibge });
    $v->required('ibge')->is_ibge_code;
    is $v->has_error, T, "invalid IBGE: $ibge";
  }
};

subtest 'custom validations - is_inep_code' => sub {
  my $vv = $t->app->validator;
  my $v = $vv->validation;

  # Válido: 8 dígitos
  $v->input({ inep => '12345678' });
  $v->required('inep')->is_inep_code;
  is $v->has_error, F, 'valid INEP code (8 digits)';

  # Inválido: menos de 8 dígitos
  $v->input({ inep => '1234567' });
  $v->required('inep')->is_inep_code;
  is $v->has_error, T, 'invalid INEP code (7 digits)';

  # Inválido: mais de 8 dígitos
  $v->input({ inep => '123456789' });
  $v->required('inep')->is_inep_code;
  is $v->has_error, T, 'invalid INEP code (9 digits)';

  # Inválido: contém letras
  $v->input({ inep => 'abcdefgh' });
  $v->required('inep')->is_inep_code;
  is $v->has_error, T, 'invalid INEP code (non-numeric)';
};

subtest 'custom validations - is_latitude' => sub {
  my $vv = $t->app->validator;
  my $v = $vv->validation;

  # Válidas
  my @valid_lats = (0, 90, -90, 45.5, -23.5678, '12.34');
  for my $lat (@valid_lats) {
    $v->input({ lat => $lat });
    $v->required('lat')->is_latitude;
    is $v->has_error, F, "valid latitude: $lat";
  }

  # Inválidas
  my @invalid = (91, -91, 100, 'abc', undef, '12,34', '90.1', '-90.1', 'N/A');
  for my $lat (@invalid) {
    $v->input({ lat => $lat });
    $v->required('lat')->is_latitude;
    is $v->has_error, T, "invalid latitude: $lat";
  }
};

subtest 'custom validations - is_longitude' => sub {
  my $vv = $t->app->validator;
  my $v = $vv->validation;

  # Válidas
  my @valid_lons = (0, 180, -180, -45.5, 123.456, '-12.34');
  for my $lon (@valid_lons) {
    $v->input({ lon => $lon });
    $v->required('lon')->is_longitude;
    is $v->has_error, F, "valid longitude: $lon";
  }

  # Inválidas
  my @invalid = (181, -181, 200, 'abc', undef, '12,34', '180.1', '-180.1');
  for my $lon (@invalid) {
    $v->input({ lon => $lon });
    $v->required('lon')->is_longitude;
    is $v->has_error, T, "invalid longitude: $lon";
  }
};

done_testing;
