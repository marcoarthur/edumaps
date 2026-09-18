package EduMaps::Controller::Gestor;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

# API do painel do gestor escolar (/api/gestor/...).

sub panel($self) {
  my $cod_inep = $self->param('cod_inep');
  my $model = $self->instantiate_model(model => 'Gestor');
  my $result = $model->panel({ cod_inep => $cod_inep });

  unless ($result) {
    return $self->render(
      json => { error => "Escola não encontrada para o INEP $cod_inep" },
      status => 404,
    );
  }

  $self->render(json => $result);
}

sub similares($self) {
  my $cod_inep = $self->param('cod_inep');
  my $model = $self->instantiate_model(model => 'Gestor');
  my $result = $model->similar_schools({
    cod_inep => $cod_inep,
    scope    => $self->param('scope'),
    limit    => $self->param('limit'),
  });

  unless ($result) {
    return $self->render(
      json => { error => "Escola não encontrada para o INEP $cod_inep" },
      status => 404,
    );
  }

  $self->render(json => $result);
}

1;

=head1 NAME

EduMaps::Controller::Gestor - API do painel do gestor escolar

=head1 DESCRIPTION

Raio-x de uma escola para o gestor: matrículas (etapa, turno, modalidade e
faixa etária), salas, docentes (formação, vínculo e disciplina),
infraestrutura, equipamentos e acessibilidade, a partir do Censo Escolar.

=head1 AUTHOR

EduMaps Development Team

=cut
