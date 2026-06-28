package EduMaps::Controller::Base;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use JSON::PP qw();
use utf8;

has json_handle => sub {
  my $json = JSON::PP->new->canonical->utf8(1);
};

sub instantiate_model($self, %args) {
  my ($model, $params) = ($self->model($args{model}), $self->req->params->to_hash);
  $params->{$_} = $self->param($_) for $args{route_params}->@*;
  $model->ctx->params({ %$params });
  return $model;
}

sub sorted_json($self, $data) { $self->json_handle->encode($data); }

sub bad_req($self, $reason = undef) {
  my $text = "Bad request" . ( $reason ? " >>>\n $reason" : '' );
  $self->render(text => $text, status => 400);
}

sub any_error($self) {
  my $v = $self->validation;
  if ($v->has_error) {
    $self->app->log->debug(
      "Validation errors: " . join(', ', map { "$_: " . join(', ', @{$v->error($_)}) } $v->failed->@*)
    );
  }
  $v->has_error;
}

1;
