package EduMaps::Model::Indicator::School::IQD;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;
use utf8;

has 'name'        => 'Qualificação Docente';
has 'code'        => 'iqd';
has 'description' => 'Mede o percentual de docentes com formação superior e pós-graduação em relação ao quadro total da escola.';

# Dois componentes, cada um a fração do quadro de docentes da educação básica
# com uma formação, portanto em [0,1] por construção e comparável entre
# escolas de qualquer tamanho.
#
# Até 2026-11 havia um terceiro componente, a razão alunos/docentes (peso 3).
# Ela não fica em [0,1] (média 18) e dominava a nota: o IQD tinha correlação
# de 0,999 com ela e media tamanho de turma, não qualificação. Capacidade de
# atendimento já está no sistema B (`score_capacidade_atendimento`). Ver
# docs/analises/ivet.md §2.3.2 e a nota técnica 184.

# Fração do quadro com formação superior completa.
sub _frac_superior ($r) {
  my $total = $r->{qt_doc_bas} // 0;
  return 0 if $total <= 0;
  return _clamp(($r->{qt_doc_bas_esco_sup_grad} // 0) / $total);
}

# Fração do quadro com alguma pós-graduação. Conta DOCENTES (graduados menos
# os sem pós), não títulos: as colunas de especialização, mestrado e doutorado
# contam títulos, e um docente pode ter mais de um (a soma passava de 1).
sub _frac_pos ($r) {
  my $total = $r->{qt_doc_bas} // 0;
  return 0 if $total <= 0;
  return 0 unless defined $r->{qt_doc_bas_esco_sup_pos_nenhum};
  my $com_pos = ($r->{qt_doc_bas_esco_sup_grad} // 0) - $r->{qt_doc_bas_esco_sup_pos_nenhum};
  return _clamp($com_pos / $total);
}

sub _clamp ($x) { $x < 0 ? 0 : $x > 1 ? 1 : $x }

has 'weights' => sub {
  [
    # Peso maior: formação superior é o piso legal (LDB) para lecionar na
    # educação básica.
    [ \&_frac_superior, 3 ],
    # Peso menor, adicional: pós-graduação é sinal de qualificação acima do piso.
    [ \&_frac_pos, 2 ],
  ];
};

has extra_cols => sub {
  [qw(
      qt_doc_bas
      qt_doc_bas_esco_sup_grad
      qt_doc_bas_esco_sup_pos_nenhum
    )];
};

1;
