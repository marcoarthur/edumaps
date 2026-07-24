package EduMaps::Controller::Rank;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

=head1 NAME

EduMaps::Controller::Rank - API de ranking de escolas por indicador

=head1 DESCRIPTION

Expõe EduMaps::Model::Rank::School. Não inclui informação de cluster —
isso permanece responsabilidade do endpoint /api/school/cluster existente
(K-means por codigo_ibge) até que seja adaptado para aceitar indicador,
o que ficou fora do escopo desta iteração.

=cut

sub indicators ($self) {
  my $model = $self->instantiate_model(model => 'Rank::School');
  my $result = $model->available_indicators($self->param('cod_inep'));
  $self->render(json => $result);
}

sub ranking ($self) {
  my $v = $self->validation;
  # Whitelist de formato apenas — a validação de "indicador existe de fato"
  # acontece na model, via indicator_registry (fonte única da verdade).
  $v->required('indicador', 'trim')->like(qr/^[a-z0-9_]+$/);
  $v->optional('national')->in(qw/0 1/);
  $v->optional('rede')->in(qw/municipal estadual privada/);
  return $self->bad_req if $self->any_error;

  my $cod_inep  = $self->param('cod_inep');
  my $indicador = $v->param('indicador');
  my $national  = $v->param('national') ? 1 : 0;
  my $rede      = $v->param('rede'); # undef se omitido

  my $model = $self->instantiate_model(model => 'Rank::School');

  my $result = eval {
    $model->rank($cod_inep, $indicador, { national => $national, network => $rede });
  };
  if ($@) {
    # croak da model = indicador não está no registry (id inválido, não ausência de dado)
    return $self->render(
      json => { error => "Indicador ou rede de ensino inválidos." },
      status => 400,
    );
  }

  unless ($result) {
    # Cenário 2 da user story: indicador existe no registry mas a escola
    # não tem dado para ele (ex: sem turmas de ensino médio)
    return $self->render(
      json => { error => "Indicador não disponível para esta escola." },
      status => 404,
    );
  }

  $self->render(json => $result);
}

1;
