package EduMaps::Util::Mojibake;
use Mojo::Base -strict, -signatures;
use utf8;
use Encode qw(encode decode);
use Exporter 'import';

our @EXPORT_OK = qw(corrige_texto tem_mojibake);

# ============================================================================
# Texto codificado duas vezes (#536, QO-02 da P5)
# ============================================================================
#
# A planilha de remuneração do SIOPE traz nomes com o UTF-8 lido como
# Latin-1 e gravado de novo (entidades &#195;&#135; = "Ã" + U+0087 no lugar
# de "Ç"). Isso tem conserto: os caracteres de volta a bytes Latin-1 são o
# UTF-8 original.
#
# Em parte da folha (Cuiabá, 2025) a letra chegou já perdida: "Ã¿"
# (&#195;&#191;), que decodificado dá "ÿ", sem relação com a letra
# original. Nenhum nome brasileiro tem "ÿ"; ele vira "?" (decisão B1), para
# não parecer uma letra de verdade.
#
# O U+FFFD (caractere de substituição) codificado duas vezes ("ï¿½") também
# volta como U+FFFD: a letra não existe mais.

# "Ã" ou "Â" seguidos de um caractere da faixa de continuação do UTF-8
# (U+0080 a U+00BF): a marca do UTF-8 lido como Latin-1.
my $MARCA = qr/[\x{C2}\x{C3}][\x{80}-\x{BF}]|\x{EF}\x{BF}\x{BD}/;

sub tem_mojibake ($s) { return defined $s && $s =~ $MARCA ? 1 : 0 }

sub corrige_texto ($s) {
  return $s unless tem_mojibake($s);
  # Só decodifica se o texto inteiro couber em Latin-1 e os bytes formarem
  # UTF-8 válido; senão, fica como veio (não inventa).
  my $d = eval {
    my $bytes = encode('ISO-8859-1', $s, Encode::FB_CROAK | Encode::LEAVE_SRC);
    decode('UTF-8', $bytes, Encode::FB_CROAK);
  };
  return $s unless defined $d;
  $d =~ tr/\x{FF}/?/;
  return $d;
}

1;
