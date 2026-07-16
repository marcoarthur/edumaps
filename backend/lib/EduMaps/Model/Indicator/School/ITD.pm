package EduMaps::Model::Indicator::School::ITD;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Tecnologia Digital';
has 'code'        => 'itd';
has 'description' => 'Avalia o acesso à internet, banda larga e equipamentos para alunos.';
has 'weights'     => sub {
  [
    ['in_internet',             1],
    ['in_banda_larga',          1],
    [ sub ($r) { ($r->{tp_rede_local} // 0) >= 2 ? 1 : 0 }, 1 ], # wifi ou ambas
    [ sub ($r) { 
        ($r->{in_desktop_aluno} || $r->{in_comp_portatil_aluno} || $r->{in_tablet_aluno}) ? 1 : 0 
      }, 1 ],
    ['in_equip_multimidia',     1],
    ['in_equip_lousa_digital',  1],
    [ sub ($r) {
        my $total = ($r->{qt_desktop_aluno} // 0) + ($r->{qt_comp_portatil_aluno} // 0) + ($r->{qt_tablet_aluno} // 0);
        return $total >= 10 ? 1 : 0;
      },
      1 
    ],
  ];
};

has extra_cols   => sub {
  [qw(tp_rede_local in_desktop_aluno in_comp_portatil_aluno in_tablet_aluno qt_desktop_aluno qt_comp_portatil_aluno qt_tablet_aluno)];
};

1;
