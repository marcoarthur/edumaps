# t/02-models/censo_labels.t
# Rótulos canônicos do Censo lidos do dicionário (issue #228).
#
# Garante que os rótulos (Federal/Estadual/Municipal/Privada, Urbana/Rural)
# vêm de clean.censo_data_dictionary — e não de mapas reescritos à mão — e que
# o vocabulário de slug da API traduz para eles.
use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use EduMaps::Model::Domain::CensoLabels;
use utf8;

my $sch = EduMaps::Schema->go;
my $dbh = $sch->storage->dbh;

skip_all('migration censo_data_dictionary_inep não aplicada')
  unless $dbh->selectrow_array(q{
    SELECT 1 FROM pg_attribute
    WHERE attrelid = to_regclass('clean.censo_data_dictionary')
      AND attname = 'origem' AND NOT attisdropped
  });

EduMaps::Model::Domain::CensoLabels->reset_cache;
my $labels = EduMaps::Model::Domain::CensoLabels->new(schema => $sch);

subtest 'rede: código -> rótulo (dicionário, não mapa local)' => sub {
  is($labels->rede_label(1),   'Federal',  'rede 1 = Federal');
  is($labels->rede_label(2),   'Estadual', 'rede 2 = Estadual');
  is($labels->rede_label(3),   'Municipal','rede 3 = Municipal');
  is($labels->rede_label(4),   'Privada',  'rede 4 = Privada');
  is($labels->rede_label('3'), 'Municipal','rede "3" (string) idem');
  is($labels->rede_label(99),  undef,      'código desconhecido = sem rótulo');
  is($labels->rede_label(undef), undef,    'código nulo = sem rótulo');
};

subtest 'localização: código -> rótulo' => sub {
  is($labels->localizacao_label(1), 'Urbana', 'localização 1 = Urbana');
  is($labels->localizacao_label(2), 'Rural',  'localização 2 = Rural');
  is($labels->localizacao_label(3), undef,    'localização 3 = desconhecida');
};

subtest 'slug da API -> código/rótulo' => sub {
  is($labels->rede_code('federal'),    1,       'slug federal -> 1');
  is($labels->rede_code('MUNICIPAL'),  3,       'slug case-insensitive');
  is($labels->rede_code('zzz'),        undef,   'slug inválido -> undef');
  is($labels->rede_code(undef),        undef,   'slug nulo -> undef');
  is($labels->rede_label_for_slug('municipal'), 'Municipal', 'slug -> rótulo');
  is($labels->rede_label_for_slug('zzz'),       undef,       'slug inválido -> undef');
};

subtest 'domínio cru (tabela.coluna)' => sub {
  is($labels->domain('clean.censo_escolas', 'tp_dependencia'),
     { 1 => 'Federal', 2 => 'Estadual', 3 => 'Municipal', 4 => 'Privada' },
     'tp_dependencia do dicionário');
  is($labels->domain('clean.censo_escolas', 'tp_localizacao'),
     { 1 => 'Urbana', 2 => 'Rural' }, 'tp_localizacao do dicionário');
  is($labels->domain('clean.censo_escolas', 'qt_equip_tv'), undef,
     'coluna numérica sem value_domain');
};

subtest 'sql_case: CASE montado do domínio' => sub {
  is($labels->sql_case('tp_dependencia', 'clean.censo_escolas', 'tp_dependencia',
       else => q{'Não informado'}),
     q{CASE tp_dependencia WHEN 1 THEN 'Federal' WHEN 2 THEN 'Estadual' WHEN 3 THEN 'Municipal' WHEN 4 THEN 'Privada' ELSE 'Não informado' END},
     'CASE com ELSE');
  is($labels->sql_case('ce.tp_localizacao', 'clean.censo_escolas', 'tp_localizacao'),
     q{CASE ce.tp_localizacao WHEN 1 THEN 'Urbana' WHEN 2 THEN 'Rural' END},
     'CASE sem ELSE');
  is($labels->sql_case('ce.tp_localizacao', 'clean.censo_escolas', 'qt_equip_tv',
       else => q{'x'}),
     q{'x'}, 'sem domínio -> o else');
  is($labels->sql_case('ce.x', 'clean.censo_escolas', 'qt_equip_tv'),
     'NULL::text', 'sem domínio e sem else -> NULL::text');
};

subtest 'cache de processo: o domínio é lido uma vez' => sub {
  my $a = $labels->domain('clean.censo_escolas', 'tp_dependencia');
  my $b = $labels->domain('clean.censo_escolas', 'tp_dependencia');
  is($a, $b, 'segunda chamada reusa o domínio cacheado');
};

done_testing;
