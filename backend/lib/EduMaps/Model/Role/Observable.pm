package EduMaps::Model::Role::Observable;
use Mojo::Base -role, -signatures;
use RxPerl::Mojo qw(rx_observable);

requires qw(next reset);

sub to_observable($self) {
  rx_observable->new(
    sub ($subscriber) {
      eval {
        while( my $row = $self->next ) {
          $subscriber->next($row);
        }
        $self->reset;
        $subscriber->complete();
      };
      if ($@) {
        $subscriber->error($@);
      }
    }
  );
}

1;
