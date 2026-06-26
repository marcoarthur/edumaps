package EduMaps::Controller::Base;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use JSON::PP qw();

has json_handle => sub {
  my $json = JSON::PP->new->canonical->utf8(1);
};

sub instantiate_model($self, %args) {
  my ($model, $params) = ($self->model($args{model}), $self->req->params->to_hash);
  $params->{$_} = $self->param($_) for $args{route_params}->@*;
  $model->ctx->params({ %$params });
  return $model;
}

sub sorted_json($self, $data) {
  $self->json_handle->encode($data);
}

1;
