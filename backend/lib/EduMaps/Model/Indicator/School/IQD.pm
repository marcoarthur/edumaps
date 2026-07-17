package EduMaps::Model::Indicator::School::IQD;
use Mojo::Base 'EduMaps::Model::Indicator', -signatures;

has 'name'        => 'Qualificação Docente';
has 'code'        => 'iqd';
has 'description' => 'Mede o percentual de docentes com formação superior e pós-graduação em relação ao quadro total da escola.';

# Cada componente ja e uma razao em [0,1] (docentes qualificados / total de
  # docentes), calculada via closure - diferente dos indicadores binarios
# existentes (IFS, IOC, etc.), aqui nao ha necessidade de normalizacao
# populacional: a proporcao ja e comparavel entre escolas de qualquer
# tamanho por construcao.
has 'weights'     => sub {
  [
    # Peso maior: qualquer formacao superior completa e o piso minimo
    # legalmente exigido (LDB) para lecionar na educacao basica
    [ sub ($r) {
        my $total = $r->{qt_doc_bas} // 0;
        return 0 if $total <= 0;
        my $superior = $r->{qt_doc_bas_esco_sup_grad} // 0;
        return $superior / $total;
      }, 3
    ],
    # Peso menor, mas adicional: pos-graduacao (especializacao, mestrado,
      # doutorado) e um sinal mais forte ainda de qualificacao acima do piso
    [ sub ($r) {
        my $total = $r->{qt_doc_bas} // 0;
        return 0 if $total <= 0;
        my $pos = ($r->{qt_doc_bas_esco_sup_pos_espec} // 0)
        + ($r->{qt_doc_bas_esco_sup_pos_mestra} // 0)
        + ($r->{qt_doc_bas_esco_sup_pos_douto}  // 0);
        return $pos / $total;
      }, 2
    ],
  ];
};

has extra_cols => sub {
  [qw(
      qt_doc_bas
      qt_doc_bas_esco_sup_grad
      qt_doc_bas_esco_sup_pos_espec
      qt_doc_bas_esco_sup_pos_mestra
      qt_doc_bas_esco_sup_pos_douto
    )];
};

1;
