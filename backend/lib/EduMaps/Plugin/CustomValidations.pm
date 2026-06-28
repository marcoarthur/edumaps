package EduMaps::Plugin::CustomValidations;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, @args) {
  $self->_add_custom_checks($app->validator);
}

sub _add_custom_checks($self, $v) {
  $v->add_check(
    is_ibge_code => sub($v, $name, $value) { ($value =~ /^\d{7}\z/) ? 0:1 }
  );

  $v->add_check(
    is_inep_code => sub($v, $name, $value) { ($value =~ /^\d{8}\z/) ? 0:1 }
  );

  $v->add_check(
    is_latitude => sub($v, $name, $value) {
      return 1 unless defined $value && $value =~ /^[+-]?\d+(\.\d+)?$/;
      my $num = $value + 0;   # força numérico
      return ($num >= -90 && $num <= 90) ? 0:1;
    }
  );

  $v->add_check(
    is_longitude => sub($v, $name, $value) {
      return 1 unless defined $value && $value =~ /^[+-]?\d+(\.\d+)?$/;
      my $num = $value + 0;
      return ($num >= -180 && $num <= 180) ? 0:1;
    }
  );
}

1;
