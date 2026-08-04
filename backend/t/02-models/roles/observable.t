# t/02-models/role/observable.t
use strict;
use warnings;
use lib qw(t/lib lib);
use Imports;

# Classe de teste que consome o role Observable
package TestResultSet {
  use Mojo::Base -base;
  use Role::Tiny::With;

  has data => sub { [] };
  has index => 0;

  sub next {
    my $self = shift;
    return $self->data->[ $self->{index}++ ];
  }

  sub reset {
    my $self = shift;
    $self->index(0);
  }

  with 'EduMaps::Model::Role::Observable';
}

# Teste principal
my $rs = TestResultSet->new( data => [ 'a', 'b', 'c' ] );

subtest 'fluxo normal de dados' => sub {
  my @received;
  my $subscription = $rs->to_observable->subscribe(
    sub { push @received, $_[0] },
    sub { fail("Erro inesperado: $_[0]") },
    sub { pass("Observable completou com sucesso") }
  );

  is( \@received, [ 'a', 'b', 'c' ], 'todos os itens foram emitidos' );
};

subtest 'reset é chamado após a iteração' => sub {
  my @received;
  $rs->to_observable->subscribe(
    sub { push @received, $_[0] },
    sub { fail("Erro") },
    sub { pass("Segundo subscribe completou") }
  );
  is( \@received, [ 'a', 'b', 'c' ], 'reset permitiu nova iteração' );
};

subtest 'propagação de erro' => sub {
  # Classe de teste que lança exceção no next
  package TestResultSetError {
    use Mojo::Base -base;
    use Role::Tiny::With;

    has data => sub { [] };
    has index => 0;
    has throw_on => undef;   # em qual chamada lançar erro (1-based)

    sub next {
      my $self = shift;
      my $idx = $self->{index}++;
      if (defined $self->throw_on && $idx == $self->throw_on - 1) {
        die "Erro simulado na iteração " . ($idx+1);
      }
      return $self->data->[$idx];
    }

    sub reset {
      my $self = shift;
      $self->index(0);
    }

    with 'EduMaps::Model::Role::Observable';
  }

  # Caso 1: erro na primeira iteração
  my $rs_err = TestResultSetError->new(
    data     => [ 'x', 'y', 'z' ],
    throw_on => 1,
  );

  my $error_received;
  my $completed_called = 0;
  my $next_called     = 0;

  $rs_err->to_observable->subscribe(
    sub { $next_called++; fail("Nenhum item deveria ser emitido, mas recebeu: $_[0]") },
    sub { $error_received = $_[0] },
    sub { $completed_called = 1 },
  );

  like( $error_received,    qr/Erro simulado na iteração 1/, 'erro foi propagado corretamente' );
  is( $completed_called, 0, 'observable não completou em caso de erro' );
  is( $next_called,      0, 'nenhum item foi emitido' );

  # Caso 2: erro no meio da iteração
  $rs_err = TestResultSetError->new(
    data     => [ 'a', 'b', 'c' ],
    throw_on => 2,
  );

  $error_received = undef;
  $completed_called = 0;
  $next_called     = 0;
  my @emitted;

  $rs_err->to_observable->subscribe(
    sub { push @emitted, $_[0]; $next_called++ },
    sub { $error_received = $_[0] },
    sub { $completed_called = 1 },
  );

  like( $error_received,    qr/Erro simulado na iteração 2/, 'erro no meio é propagado' );
  is( $completed_called, 0, 'não completou' );
  is( $next_called,      1, 'apenas um item foi emitido antes do erro' );
  is( \@emitted, [ 'a' ], 'itens anteriores ao erro foram emitidos' );
};

done_testing;
