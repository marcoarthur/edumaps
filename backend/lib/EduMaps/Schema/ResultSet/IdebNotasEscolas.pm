package EduMaps::Schema::ResultSet::IdebNotasEscolas;

use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;

sub all_grades_for($self, $params = {}) {
  my $grades = {};
  my $escola = {};
  my $rendimento = {};
  my $ideb = {};

  my $results = $self->filter_by(id_escola => $params->{id_escola})->get_all->each(
    sub {
      $grades->{notas_por_serie}{$_->etapa}{matematica}{$_->ano} = $_->nota_matematica/50;
      $grades->{notas_por_serie}{$_->etapa}{portugues}{$_->ano}  = $_->nota_portugues/50;
      $grades->{notas_por_serie}{$_->etapa}{media}{$_->ano}      = $_->nota_media;
      $rendimento->{$_->etapa}{$_->ano}{'serie_1'} = $_->aprovacao_1;
      $rendimento->{$_->etapa}{$_->ano}{'serie_2'} = $_->aprovacao_2;
      $rendimento->{$_->etapa}{$_->ano}{'serie_3'} = $_->aprovacao_3;
      $rendimento->{$_->etapa}{$_->ano}{'serie_4'} = $_->aprovacao_4;
      $rendimento->{$_->etapa}{$_->ano}{'total_serie'} = $_->aprovacao_si_4;
      $ideb->{$_->ano}{observado} = $_->ideb_observado;
      $ideb->{$_->ano}{projecao}  = $_->ideb_projecao;
    }
  );
  return unless $results->size > 0;

  if ($results && (my $e = $results->[0])) {
    $escola->{id} = $params->{id_escola};
    $escola->{nome} = $e->no_escola;
    $escola->{municipio} = $e->no_municipio;
    $escola->{codigo_ibge} = $e->co_municipio;
    $escola->{rede} = $e->rede;
  }

  return {
    escola => $escola,
    indicador_rendimento => $rendimento,
    valores_observados_e_projecoes => $ideb,
    %$grades,
  };
}

1;
