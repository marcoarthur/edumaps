# t/02-models/mojibake.t
# #536 (QO-02 da P5): texto do SIOPE codificado duas vezes na fonte.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::Util::Mojibake qw(corrige_texto tem_mojibake);

# O que chega do arquivo (UTF-8 lido como Latin-1): "Ã" + U+0087 = "Ç".
my %CASOS = (
  "GON\x{C3}\x{87}ALVES"            => 'GONÇALVES',
  "CONCEI\x{C3}\x{87}\x{C3}\x{83}O" => 'CONCEIÇÃO',
  "F\x{C3}\x{81}TIMA"               => 'FÁTIMA',
  "PATR\x{C3}\x{8D}CIA"             => 'PATRÍCIA',
  # 2025: a letra chegou perdida ("Ã¿" = "ÿ"), vira "?" (B1)
  "PE\x{C3}\x{BF}ANHA"              => 'PE?ANHA',
  # nome certo não muda
  'JOÃO DA CONCEIÇÃO'               => 'JOÃO DA CONCEIÇÃO',
  'MARIA'                           => 'MARIA',
);
for my $in (sort keys %CASOS) {
  is corrige_texto($in), $CASOS{$in}, "$CASOS{$in}";
}

ok !defined corrige_texto(undef), 'vazio fica vazio';
ok tem_mojibake("GON\x{C3}\x{87}ALVES"), 'acusa a dupla';
ok !tem_mojibake('GONÇALVES'), 'não acusa o certo';
is corrige_texto("magist\x{EF}\x{BF}\x{BD}rio"), "magist\x{FFFD}rio", 'U+FFFD duplo volta como U+FFFD';
# fora do Latin-1: não inventa, fica como veio
my $misto = "GON\x{C3}\x{87}ALVES \x{2014} ok";
is corrige_texto($misto), $misto, 'texto fora do Latin-1 fica como está';
my $orig = "GON\x{C3}\x{87}ALVES";
corrige_texto($orig);
is $orig, "GON\x{C3}\x{87}ALVES", 'não altera a variável de entrada';

done_testing;
