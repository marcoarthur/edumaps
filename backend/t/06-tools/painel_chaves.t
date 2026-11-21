# t/06-tools/painel_chaves.t
# #510 (RA-01): as chaves de etapas e de infraestrutura que o backend manda
# no painel da escola (/api/school/:inep/panel/info) são as mesmas que a tela
# desenha (ETAPAS_ORDER e INFRA_ORDER do icon-data.js). Uma chave que só um
# lado conhece deixava o ícone apagado em toda escola: a pré-escola
# (pre_infantil × pre_escola) e a quadra (quadra_esporte × quadra_esportes).
use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use EduMaps::Roles::Business::School::Profile;

my $js = "$FindBin::Bin/../../../frontend/edumaps/src/features/schools/components/icons/icon-data.js";
plan skip_all => "icon-data.js ausente ($js)" unless -f $js;

open my $fh, '<:encoding(UTF-8)', $js or die "$js: $!";
my $src = do { local $/; <$fh> };

sub ordem {
  my ($nome) = @_;
  my ($corpo) = $src =~ /export const \Q$nome\E\s*=\s*\[(.*?)\]/s
    or BAIL_OUT("$nome não encontrado em icon-data.js");
  return [ $corpo =~ /"([a-z_]+)"/g ];
}

my $censo = {};   # tudo sem dado: as chaves vêm mesmo assim
my %etapas = %{ EduMaps::Roles::Business::School::Profile::panel_etapas($censo) };
my %infra  = %{ EduMaps::Roles::Business::School::Profile::panel_infraestrutura($censo) };
delete $infra{detalhe};

is_deeply [ sort keys %etapas ], [ sort @{ ordem('ETAPAS_ORDER') } ],
  'etapas: mesmas chaves no backend e na tela';
is_deeply [ sort keys %infra ], [ sort @{ ordem('INFRA_ORDER') } ],
  'infraestrutura: mesmas chaves no backend e na tela';

done_testing;
