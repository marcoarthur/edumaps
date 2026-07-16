package EduMaps::Model::Indicator::School::IOC;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Integralidade e Oferta Curricular';
has 'code'        => 'ioc';
has 'description' => 'Avalia a diversidade de etapas oferecidas e a oferta de tempo integral ou EJA.';
has 'weights'     => sub {
  [
    ['in_comum_creche',      1],
    ['in_comum_pre',         1],
    ['in_comum_fund_ai',     1],
    ['in_comum_fund_af',     1],
    ['in_comum_medio_medio', 1],
    [ sub ($r) { ($r->{in_comum_eja_fund} || $r->{in_comum_eja_medio}) ? 1 : 0 }, 1 ],
    ['in_comum_prof',        1],
    [ sub ($r) { ($r->{in_educacao_indigena} || $r->{in_material_ped_quilombola}) ? 1 : 0 }, 1 ],
    [ sub ($r) {
        my $tp = $r->{tp_atividade_complementar} // 0;
        return 2 if $tp == 2; # integral
        return 1 if $tp == 3; # ambos
        return 0;
      }, 1
    ],
  ];
};

has extra_cols   => sub {
  [qw(in_comum_eja_fund in_comum_eja_medio in_educacao_indigena in_material_ped_quilombola tp_atividade_complementar)];
};

1;
