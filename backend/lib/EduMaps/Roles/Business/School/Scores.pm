package EduMaps::Roles::Business::School::Scores;
use Mojo::Base -role, -signatures;
use DateTime;
use Carp qw(croak);

sub scores($self, $params = {}) {

  unless ($params->{ co_entidade }) {
    croak "missing shool id";
  }

  my $results = $self->schema->resultset('MvEscolasScores')->search_rs($params)->as_hash->get_all;
  unless($results->size == 0) {
    return $self->json->encode(
      {
        error => sprintf('Escola de código %s não encontrada', $params->{co_entidade})
      }
    );
  }
  return $results;
}

1;
