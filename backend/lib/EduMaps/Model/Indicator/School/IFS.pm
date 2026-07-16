package EduMaps::Model::Indicator::School::IFS;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Infraestrutura Física e Saneamento';
has 'code'        => 'ifs';
has 'description' => 'Mapeia as condições físicas básicas e saneamento da escola.';
has 'weights'     => sub {
    [
        ['in_cozinha',                1],
        ['in_energia_rede_publica',   2],
        ['in_esgoto_rede_publica',    2],
        ['in_esgoto_fossa_septica',   1],
        ['in_banheiro',               1],
        ['in_refeitorio',             1],
        ['in_agua_potavel',           2],
    ];
};

1;
