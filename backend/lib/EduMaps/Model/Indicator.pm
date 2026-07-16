package EduMaps::Model::Indicator;
use Mojo::Base -base, -signatures;

has name        => 'Indicador Base';
has code        => 'BASE';
has description => 'Classe base para todos os indicadores.';
has weights     => sub { [] }; # Arrayref de [coluna_ou_coderef, peso]
has extra_cols  => sub { [] }; # Colunas extras para Sanitização
has scale       => 1; # Escala (0-1) default
has decimals    => 4; # Dígitos decimais

# Limpeza e sanitização robusta por campo (reutilizável)
sub clean_value ($self, $field, $val) {
  return 0 unless defined $val;
  # Se for indicador binário do Censo (in_*), garante valores no intervalo [0, 1]
  if ($field =~ /^in_/) {
    return $val >= 1 ? 1 : 0;
  }
  return $val;
}

# Método unificado de cálculo do score linear (0..1)
sub calculate ($self, $record) {
  my $sum    = 0;
  my $sum_w  = 0;

  for my $pair ($self->weights->@*) {
    my ($col, $weight) = @$pair;
    my $val;

    if (ref $col eq 'CODE') {
      # Closures recebem o registro limpo
      $val = $col->($record) // 0;
    } else {
      # Campos simples são higienizados
      my $raw = $record->{$col};
      $val = $self->clean_value($col, $raw);
    }

    $sum    += $val * $weight;
    $sum_w  += $weight;
  }

  return 0 if $sum_w == 0;

  my $score = $sum / $sum_w;
  my $format = "%." . $self->decimals . "f";
  return sprintf($format, $score * $self->scale);
}

1;
