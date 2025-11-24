package EduMaps::Schema::ResultSet::AnaliseCoberturaEscolar;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;

sub sumario_municipio($self) {

  my $coberta = "(ST_Area(area_coberta::geography) / 1000000)" ;
  my $vazio = "(ST_Area(vazio_educacional::geography) / 1000000)";
  my $percentual ="($coberta /($coberta + $vazio))*100"; 
  my $rs = $self->search_rs(
    undef,
    {
      columns => [
        'nome_municipio',
        { area_coberta_km2 => \$coberta},
        { vazio_educacional_km2 =>  \$vazio},
        { percentual_cobertura => \"$percentual"},
      ],
    }
  );
}
1;
