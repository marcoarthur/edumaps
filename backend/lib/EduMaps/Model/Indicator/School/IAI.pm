package EduMaps::Model::Indicator::School::IAI;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Acessibilidade e Inclusão';
has 'code'        => 'iai';
has 'description' => 'Mapeia a acessibilidade física estrutural e o suporte à educação especial.';
has 'weights'     => sub {
  [
    ['in_acessibilidade_rampas',        2],
    ['in_acessibilidade_corrimao',      2],
    ['in_acessibilidade_pisos_tateis',  2],
    ['in_acessibilidade_sinal_visual',  2],
    ['in_acessibilidade_vao_livre',     2],
    [ sub ($r) { (($r->{tp_aee} // 0) && ($r->{tp_aee} // 0) != 8) ? 1 : 0 }, 3 ],
    [ sub ($r) { ($r->{qt_prof_trad_libras} // 0) > 0 ? 1 : 0 }, 3 ],
    [ sub ($r) { ($r->{qt_prof_revisor_braille} // 0) > 0 ? 1 : 0 }, 3 ],
  ];
};

has extra_cols   => sub {
  [qw(tp_aee qt_prof_trad_libras qt_prof_revisor_braille)];
};

1;
