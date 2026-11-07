# t/02-models/indicators/ige.t
# IGE (Qualidade da Gestão) fica em 0..1: o item da proposta pedagógica é
# graduado no valor (própria 1, adaptada 0,5), não acima de 1.
use lib qw(t/lib lib);
use Imports;
use EduMaps::Model::Indicator::School::IGE;

my $ige = EduMaps::Model::Indicator::School::IGE->new;

my %tudo = (
  in_orgao_conselho_escolar  => 1,
  in_orgao_ass_pais_mestres  => 1,
  in_orgao_gremio_estudantil => 1,
  in_internet_administrativo => 1,
  qt_prof_gestao             => 1,
);

is $ige->calculate({ %tudo, tp_proposta_pedagogica => 1 }) + 0, 1,
  'proposta própria e todos os itens: score máximo = 1';
ok $ige->calculate({ %tudo, tp_proposta_pedagogica => 3 }) < 1,
  'proposta adaptada fica abaixo da própria';
ok $ige->calculate({ %tudo, tp_proposta_pedagogica => 3 })
   > $ige->calculate({ %tudo, tp_proposta_pedagogica => 2 }),
  'adaptada fica acima da proposta da rede';
is $ige->calculate({ tp_proposta_pedagogica => 0 }) + 0, 0,
  'sem nenhum item: score 0';

done_testing;
