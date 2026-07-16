package EduMaps::Model::Role::FindSimilar;
use Mojo::Base -role, -signatures;
use List::Util qw(sum0);
use Mojo::Collection qw(c);

# Exigido pela classe consumidora
requires qw(build_feature_vector id_column);

=head2 find_similar

Encontra os registros mais próximos comparando o vetor do objeto atual contra um ResultSet.
Métricas suportadas no parâmetro 'metric': 'euclidean', 'cosine', 'manhattan', 'chebyshev'.

=cut
sub find_similar ($self, $target, $candidate_rs, $attrs = {}) {
  my $limit  = $attrs->{limit}  // 10;
  my $metric = $attrs->{metric} // 'euclidean';

  # Mapeamento dinâmico para evitar estruturas condicionais complexas
  my %dispatch = (
    euclidean => \&_euclidean_distance,
    cosine    => \&_cosine_distance,
    manhattan => \&_manhattan_distance,
    chebyshev => \&_chebyshev_distance,
  );

  # Fallback seguro caso passem uma métrica inválida
  my $dist_func = $dispatch{$metric} // $dispatch{euclidean};

  my $target_vector = $self->build_feature_vector($target);
  my @similar_list;
  my $id = $self->id_column;

  $candidate_rs->reset; # coloca o cursor no inicio
  while (my $candidate = $candidate_rs->next) {
    next if $target->{$id} eq $candidate->{$id};

    my $candidate_vector = $self->build_feature_vector($candidate);

    # Calcula a distância usando a métrica selecionada
    my $distance = $dist_func->($target, $target_vector, $candidate_vector);

    push @similar_list, {
      record   => $candidate,
      distance => $distance,
    };
  }

  # Ordena de menor distância (mais similar) para maior
  my @sorted = sort { $a->{distance} <=> $b->{distance} } @similar_list;

  my $max_index = scalar(@sorted) < $limit ? $#sorted : $limit - 1;
  $candidate_rs->reset;
  return c(@sorted[0 .. $max_index]);
}

# --- Métodos Privados de Distância Matemática ---

sub _cosine_distance ($self, $v1, $v2) {
  my ($dot, $norm1, $norm2) = (0, 0, 0);
  for my $i (0 .. $#$v1) {
    my $a = $v1->[$i] // 0;
    my $b = $v2->[$i] // 0;
    $dot   += $a * $b;
    $norm1 += $a * $a;
    $norm2 += $b * $b;
  }
  return ($norm1 == 0 || $norm2 == 0) ? 1 : 1 - ($dot / (sqrt($norm1) * sqrt($norm2)));
}

sub _euclidean_distance ($self, $v1, $v2) {
  my $sum_sq = 0;
  for my $i (0 .. $#$v1) {
    my $diff = ($v1->[$i] // 0) - ($v2->[$i] // 0);
    $sum_sq += $diff * $diff;
  }
  return sqrt($sum_sq);
}

sub _manhattan_distance ($self, $v1, $v2) {
  my $sum_diff = 0;
  for my $i (0 .. $#$v1) {
    $sum_diff += abs(($v1->[$i] // 0) - ($v2->[$i] // 0));
  }
  return $sum_diff;
}

sub _chebyshev_distance ($self, $v1, $v2) {
  my $max_diff = 0;
  for my $i (0 .. $#$v1) {
    my $diff = abs(($v1->[$i] // 0) - ($v2->[$i] // 0));
    $max_diff = $diff if $diff > $max_diff;
  }
  return $max_diff;
}

1;
