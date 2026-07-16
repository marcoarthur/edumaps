package EduMaps::Model::Indicator::School::IPS;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Qualidade Pedagógica (Suporte e Recursos)';
has 'code'        => 'ips';
has 'description' => 'Mede a disponibilidade de materiais pedagógicos diversificados e profissionais de apoio.';
has 'weights'     => sub {
  [
    ['in_material_ped_multimidia', 1],
    ['in_material_ped_jogos',      1],
    ['in_material_ped_artisticas', 1],
    ['in_material_ped_cientifico', 1],
    ['in_material_ped_musical',    1],
    [ sub ($r) { ($r->{qt_prof_pedagogia} // 0) > 0 ? 1 : 0 }, 2 ],
    [ sub ($r) { ($r->{qt_prof_psicologo} // 0) > 0 ? 1 : 0 }, 2 ],
    [ sub ($r) { (($r->{in_biblioteca} // 0) || ($r->{qt_prof_bibliotecario} // 0) > 0) ? 1 : 0 }, 2 ],
  ];
};

has extra_cols   => sub {
  [qw(qt_prof_pedagogia qt_prof_psicologo in_biblioteca)];
};

1;
