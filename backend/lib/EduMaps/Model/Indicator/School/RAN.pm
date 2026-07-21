package EduMaps::Model::Indicator::School::RAN;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;
use EduMaps::Schema;
use Data::Fake qw/Core/;

has 'name'        => 'Indicador randômico';
has 'code'        => 'ran';
has 'description' => 'Esse é um indicador dummy randômico feito com geradores de funções';

# defaults para o gerador
has opts  => sub {
  {
    n_features  => 100,    # nro de features
    w_range     => [1,6],  # intervalo de pesos
  };
};

# gerador da tabela features/peso
has _weight_generator => sub($self) {
  state $feats = fake_pick(
    EduMaps::Schema->go->resultset('CensoEscolas')->result_source->columns
  );

  state $gen = fake_array(
    $self->opts->{n_features},
    sub {[$feats->(), fake_int($self->opts->{w_range}->@*)->()]}
  );

  $gen;
};

has weights => sub($self) {
  state $w = $self->_weight_generator->();
};

1;
