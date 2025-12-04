package EduMaps::Schema::ResultSet::InepNotasDesagregadas;
use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;

sub with_deltas($self) {
  my $alias = $self->current_source_alias;
  my $tmpl  = "(%s - LAG(%s) OVER ( PARTITION BY %s ORDER BY %s ))::numeric";
  my ($por, $mat, $esc, $ano) =  ("$alias.nota_por", "$alias.nota_mat", "$alias.no_escola", "$alias.ano");
  $self->search_rs(
    undef,
    {
      '+select' => [
        { round => [ \sprintf($tmpl, $por, $por, $esc, $ano), 2], -as => 'delta_por' },
        { round => [ \sprintf($tmpl, $mat, $mat, $esc, $ano), 2], -as => 'delta_mat' },
      ],
      '+as' => [ qw(delta_por delta_mat) ],
    }
  );
}

1;
