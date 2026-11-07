package EduMaps::Model::Indicator::School::IGE;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Qualidade da Gestão';
has 'code'        => 'ige';
has 'description' => 'Mede instâncias de participação democrática e infraestrutura administrativa.';
has 'weights'     => sub {
    [
        ['in_orgao_conselho_escolar', 1],
        ['in_orgao_ass_pais_mestres', 1],
        ['in_orgao_gremio_estudantil', 1],
        # O score é sum(valor*peso)/sum(pesos): cada item tem de ficar em 0..1,
        # senão o índice passa de 1. A gradação vai no valor; a importância,
        # no peso.
        [ sub ($r) {
            my $tp = $r->{tp_proposta_pedagogica} // 0;
            return 1   if $tp == 1; # própria
            return 0.5 if $tp == 3; # adaptada
            return 0;               # da rede ou indefinida
          }, 2
        ],
        ['in_internet_administrativo', 1],
        [ sub ($r) { (($r->{qt_prof_gestao} // 0) > 0 || ($r->{qt_prof_coordenador} // 0) > 0) ? 1 : 0 }, 1 ],
    ];
};

has extra_cols   => sub {
  [qw(qt_prof_gestao qt_prof_coordenador tp_proposta_pedagogica)];
};

1;
