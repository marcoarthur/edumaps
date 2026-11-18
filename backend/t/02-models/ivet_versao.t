# t/02-models/ivet_versao.t
# #489 (RK-02): a versão citável do IVET publicada em /fontes. O registro em
# EduMaps::Model::Ivet::Versao, a fórmula do pacote R (`ivet_versao()`), o
# card do índice e o cabeçalho do documento de método têm de dizer a mesma
# versão; e os blocos territoriais mínimos da API são os do card.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::File qw(path);
use YAML::XS ();
use EduMaps::Model::Ivet::Versao;

my $versao = $EduMaps::Model::Ivet::Versao::VERSAO;
my @hist   = @EduMaps::Model::Ivet::Versao::HISTORICO;
my $raiz   = path('..');

subtest 'registro' => sub {
  like $versao, qr/^ivet-v1\.\d+$/, 'formato ivet-v1.N';
  is $hist[0]{versao}, $versao, 'a primeira linha do histórico é a versão atual';
  my @n = map { /\.(\d+)$/ ? $1 : -1 } map { $_->{versao} } @hist;
  is \@n, [reverse 0 .. $#hist], 'histórico do mais novo ao mais antigo, sem buraco';
  for my $h (@hist) {
    like $h->{data}, qr/^\d{4}-\d{2}-\d{2}$/, "$h->{versao}: data";
    ok length($h->{mudou}) > 10, "$h->{versao}: o que mudou";
  }
};

subtest 'mesma versão no R, no card e no documento de método' => sub {
  my $r = $raiz->child('analysis/edumapsr/R/ivet.R')->slurp('UTF-8');
  my ($no_r) = $r =~ /ivet_versao <- function\(\) "([^"]+)"/;
  is $no_r, $versao, 'ivet_versao() do pacote R (mudou a fórmula? suba os quatro)';

  my $card = YAML::XS::LoadFile($raiz->child('analysis/edumapsr/inst/ivet-card.yml')->to_string);
  is $card->{formula}, $versao, 'formula do inst/ivet-card.yml';

  my $doc = $raiz->child('docs/analises/ivet.md')->slurp('UTF-8');
  my ($no_doc) = $doc =~ /\*\*Versão da fórmula\*\*: `([^`]+)`/;
  is $no_doc, $versao, 'cabeçalho de docs/analises/ivet.md';

  my %letra = %{ $card->{blocos} };
  is [ sort map { $letra{$_} } @{ $card->{blocos_territoriais_minimos} } ],
     [ @EduMaps::Model::Ivet::Versao::BLOCOS_TERRITORIAIS ],
     'blocos territoriais mínimos da API = os do card';
};

done_testing;
