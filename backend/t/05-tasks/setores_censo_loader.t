use lib qw(t/lib lib);
use strict;
use warnings;
no warnings qw(once);
use utf8;
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);

# Loader da malha de setores + Censo 2022 por setor (#238, P2 da #156).
my $JOB = 'EduMaps::Ingestion::Job::SetoresCenso2022';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

# ---------------------------------------------------------------- mocks
{
  package MockStorage;
  sub new { my ($c, %a) = @_; bless {%a}, $c }
  sub connect_info { $_[0]{connect_info} }
  package MockSchema; sub new { my ($c, %a) = @_; bless {%a}, $c } sub storage { $_[0]{storage} }
  package MockApp;    sub new { my ($c, %a) = @_; bless {%a}, $c } sub schema  { $_[0]{schema} }
}
sub app_com_dsn {
  my @info = @_;
  return MockApp->new(schema => MockSchema->new(storage => MockStorage->new(connect_info => \@info)));
}

# CSV latin1 em memória como o do IBGE (`;`, aspas).
sub fh_de {
  my ($texto) = @_;
  open my $fh, '<:encoding(latin1)', \(my $bytes = Encode::encode('latin1', $texto)) or die $!;
  return $fh;
}
use Encode ();

# ---------------------------------------------------------------- tabelas
subtest 'tabelas: as duas, ou só a parte pedida' => sub {
  is_deeply([job()->tabelas({})], ['clean.malha_setor_censitario', 'clean.censo2022_setor'], 'malha antes do censo (FK)');
  is_deeply([job()->tabelas({ so => 'malha' })], ['clean.malha_setor_censitario'], 'so=malha');
  is_deeply([job()->tabelas({ so => 'censo' })], ['clean.censo2022_setor'], 'so=censo');
};

# ---------------------------------------------------------------- conversão
subtest 'converter_linha: demografia soma 20-24 + 25-29 e usa os totais por faixa' => sub {
  my %h = (CD_SETOR => '110001505000002', V01006 => '928', V01007 => '428', V01008 => '500',
           map { ("V010$_" => 10) } 31 .. 41);
  $h{V01035} = 36; $h{V01036} = 25;
  my $r = job()->converter_linha('demografia', \%h);
  is($r->{pop_total}, 928, 'pop_total = V01006');
  is($r->{pop_homens}, 428, 'homens = V01007');
  is($r->{idade_20_29}, 61, '20-29 = 20-24 + 25-29');
  is($r->{idade_70_mais}, 10, '70+ = V01041');
  is($r->{suprimido}, 0, 'sem supressão');
};

subtest 'converter_linha: "X" vira NULL e marca supressão; "." é NULL sem marca' => sub {
  my %h = (CD_SETOR => '110001505000002', V01317 => '312', V01318 => '87', V01319 => 'X',
           V01320 => '514', V01321 => '.');
  my $r = job()->converter_linha('cor_ou_raca', \%h);
  is($r->{cor_branca}, 312, 'valor real');
  ok(!defined $r->{cor_amarela}, 'X -> NULL, nunca 0');
  ok(!defined $r->{cor_indigena}, '"." -> NULL');
  is($r->{suprimido}, 1, 'supressão marcada');

  my %d = (CD_SETOR => '110001505000002', V01006 => 5, V01007 => 3, V01008 => 2,
           map { ("V010$_" => 1) } 31 .. 41);
  $d{V01036} = 'X';
  my $s = job()->converter_linha('demografia', \%d);
  ok(!defined $s->{idade_20_29}, 'uma parcela suprimida anula a soma');
  is($s->{idade_15_19}, 1, 'as demais faixas seguem');
  is($s->{suprimido}, 1, 'e o setor fica marcado');
};

subtest 'converter_linha: basico traz identificação, sigla e domicílios' => sub {
  my %h = (CD_SETOR => '110001505000002', SITUACAO => 'Urbana', CD_UF => '11', CD_MUN => '1100015',
           NM_MUN => "Alta Floresta D'Oeste", V0002 => '376', V0003 => '376', V0004 => '0');
  my $r = job()->converter_linha('basico', \%h);
  is($r->{sigla_uf}, 'RO', 'CD_UF 11 -> RO');
  is($r->{codigo_ibge}, '1100015', 'codigo_ibge = CD_MUN');
  is(substr($r->{codigo_setor}, 0, 7), $r->{codigo_ibge}, 'coerente com os 7 primeiros dígitos do setor');
  is($r->{situacao_setor}, 'Urbana', 'situação');
  is($r->{dom_coletivo}, 0, 'zero real fica zero');
  ok(!exists $r->{$_}, "$_ não é preenchida (sem fonte)") for @EduMaps::Ingestion::Job::SetoresCenso2022::SEM_FONTE;
};

subtest 'colunas sem fonte nunca aparecem no mapa de variáveis' => sub {
  my %mapa = map { %$_ } values %EduMaps::Ingestion::Job::SetoresCenso2022::MAPA;
  ok(!exists $mapa{$_}, "$_ sem variável do IBGE") for @EduMaps::Ingestion::Job::SetoresCenso2022::SEM_FONTE;
};

# ---------------------------------------------------------------- leitura
subtest 'ler_fluxo: cabeçalho em qualquer caixa, latin1, filtro de UF e lotes' => sub {
  my $csv = join "\n",
    '"CD_setor";"V01006";"V01007";"V01008";' . join(';', map { "\"V010$_\"" } 31 .. 41),
    '"110001505000002";"928";"428";"500";' . join(';', ('"1"') x 11),
    '"350001505000002";"10";"5";"5";' . join(';', ('"1"') x 11),
    '';
  my @lotes;
  my $n = job()->ler_fluxo(fh_de($csv), 'demografia', '11', sub { push @lotes, $_[0] });
  is($n, 1, 'só a UF pedida');
  is($lotes[0][0]{codigo_setor}, '110001505000002', 'CD_setor reconhecido como CD_SETOR');

  my $basico = join "\n",
    '"CD_SETOR";"SITUACAO";"CD_UF";"NM_UF";"CD_MUN";"NM_MUN";"v0001";"v0002";"v0003";"v0004"',
    '"110001505000002";"Urbana";"11";"Rondônia";"1100015";"Alta Floresta D\'Oeste";"928";"376";"376";"0"',
    '';
  my @b;
  job()->ler_fluxo(fh_de($basico), 'basico', undef, sub { push @b, @{ $_[0] } });
  is($b[0]{dom_total}, 376, 'v0002 minúsculo lido como V0002');
  is($b[0]{codigo_ibge}, '1100015', 'identificação');
};

subtest 'ler_fluxo: variável ausente morre com a lista' => sub {
  my $csv = qq{"CD_SETOR";"V01317"\n"110001505000002";"1"\n};
  my $ok = eval { job()->ler_fluxo(fh_de($csv), 'cor_ou_raca', undef, sub {}); 1 };
  ok(!$ok, 'morre');
  like($@, qr/faltam variáveis: V01318/, 'nomeia o que falta');
};

# ---------------------------------------------------------------- ogr2ogr
subtest 'comando_ogr2ogr: senha só no ambiente, nunca na linha de comando' => sub {
  my $j = job(app => app_com_dsn('dbi:Pg:dbname=edumaps_dev;host=172.19.198.3;port=5432', 'devel', 's3gr3d0'));
  my ($argv, $env) = $j->comando_ogr2ogr('/srv/edumaps/raw/x/BR_setores_CD2022.gpkg', '35');
  ok(!(grep { /s3gr3d0/ } @$argv), 'senha fora do argv');
  is($env->{PGPASSWORD}, 's3gr3d0', 'senha em PGPASSWORD');
  is($env->{PGDATABASE}, 'edumaps_dev', 'dbname');
  is($env->{PGHOST}, '172.19.198.3', 'host');
  is($argv->[0], 'ogr2ogr', 'binário');
  my $s = join ' ', @$argv;
  like($s, qr/-nln raw\.stage_setores_cd2022/, 'staging em raw');
  like($s, qr/-select CD_SETOR,SITUACAO,CD_UF,CD_MUN,NM_MUN/, 'só as colunas usadas');
  like($s, qr/-nlt PROMOTE_TO_MULTI/, 'multipolígono');
  like($s, qr/-t_srs EPSG:4674/, 'SIRGAS 2000');
  like($s, qr/-where CD_UF = '35'/, 'recorte de UF');
  ok(!(grep { /^PG:.+/ } @$argv), 'string PG: vazia (conexão pelo ambiente)');

  my $h = job(app => app_com_dsn({ dsn => 'dbi:Pg:dbname=x', user => 'u', password => 'p' }));
  is($h->credenciais_pg->{PGPASSWORD}, 'p', 'connect_info em hashref também');
};

subtest 'run: so inválido e uf desconhecida morrem cedo' => sub {
  ok(!eval { job()->run({ so => 'tudo' }); 1 }, 'so inválido');
  like($@, qr/so=tudo inválido/, 'mensagem');
  ok(!eval { job()->run({ uf => 'XX' }); 1 }, 'uf desconhecida');
};

# ---------------------------------------------------------------- integração
# Banco intencional (EDUMAPS_DB_*, o do CI) + ogr2ogr: GPKG sintético com um
# setor válido, um com geometria inválida (laço) e um de município fora da
# malha_municipio; ZIPs sintéticos em latin1. Tudo é apagado no fim.
subtest 'integração: malha + censo no banco do CI' => sub {
  plan skip_all => 'sem EDUMAPS_DB_HOST (base intencional)' unless $ENV{EDUMAPS_DB_HOST};
  plan skip_all => 'sem ogr2ogr' unless `ogr2ogr --version 2>/dev/null`;
  require EduMaps::Ingestion::App;
  require IO::Compress::Zip;
  my $app = eval { EduMaps::Ingestion::App->new };
  my $dbh = $app && eval { $app->schema->storage->dbh };
  plan skip_all => 'sem BD' unless $dbh && $dbh->selectrow_array("SELECT to_regclass('clean.censo2022_setor')");
  my ($mun, $nome, $cd_uf) = $dbh->selectrow_array(
    q{SELECT codigo_ibge, nome_municipio, substr(codigo_ibge, 1, 2) FROM clean.malha_municipio ORDER BY 1 LIMIT 1});
  plan skip_all => 'malha_municipio vazia' unless $mun;

  my $tmp = tempdir(CLEANUP => 1);
  my @setores = ("${mun}00000001", "${mun}00000002", "990000100000001");
  my $meta_antes = $dbh->selectall_arrayref(
    q{SELECT * FROM clean.import_metadata WHERE table_name IN ('clean.malha_setor_censitario','clean.censo2022_setor')},
    { Slice => {} });

  my $limpar = sub {
    $dbh->do('DELETE FROM clean.censo2022_setor WHERE codigo_setor = ANY(?)', undef, \@setores);
    $dbh->do('DELETE FROM clean.malha_setor_censitario WHERE codigo_setor = ANY(?)', undef, \@setores);
    $dbh->do('DROP TABLE IF EXISTS raw.stage_setores_cd2022');
  };
  $limpar->();

  # GPKG sintético
  my $feat = sub {
    my ($cd, $cdmun, $coords) = @_;
    return qq({"type":"Feature","properties":{"CD_SETOR":"$cd","SITUACAO":"Urbana","CD_SIT":"1","CD_UF":"$cd_uf","NM_UF":"X","CD_MUN":"$cdmun","NM_MUN":"$nome"},"geometry":{"type":"Polygon","coordinates":[$coords]}});
  };
  my $quadrado = '[[-47,-15],[-47,-14.9],[-46.9,-14.9],[-46.9,-15],[-47,-15]]';
  my $laco     = '[[-47,-15],[-46.9,-14.9],[-46.9,-15],[-47,-14.9],[-47,-15]]';   # auto-interseção
  open my $gj, '>', "$tmp/s.geojson" or die $!;
  print $gj '{"type":"FeatureCollection","features":[',
    join(',', $feat->($setores[0], $mun, $quadrado), $feat->($setores[1], $mun, $laco),
              $feat->($setores[2], '9900001', $quadrado)), ']}';
  close $gj;
  my $gpkg = "$tmp/BR_setores_CD2022.gpkg";
  system('ogr2ogr', '-f', 'GPKG', $gpkg, "$tmp/s.geojson", '-nln', 'BR_setores_CD2022', '-a_srs', 'EPSG:4674') == 0
    or BAIL_OUT('ogr2ogr não gerou o GPKG de teste');

  # ZIPs sintéticos (latin1)
  my %csv = (
    basico => qq{"CD_SETOR";"SITUACAO";"CD_UF";"NM_UF";"CD_MUN";"NM_MUN";"v0001";"v0002";"v0003";"v0004"\n}
      . join('', map { qq{"$_";"Urbana";"$cd_uf";"Rondônia";"} . substr($_, 0, 7) . qq{";"$nome";"10";"4";"4";"0"\n} } @setores),
    demografia => qq{"CD_setor";"V01006";"V01007";"V01008";} . join(';', map { "\"V010$_\"" } 31 .. 41) . "\n"
      . qq{"$setores[0]";"10";"6";"4";} . join(';', ('"1"') x 4, '"1"', '"2"', '"X"', ('"1"') x 4) . "\n",
    cor_ou_raca => qq{"CD_SETOR";"V01317";"V01318";"V01319";"V01320";"V01321"\n"$setores[0]";"5";"X";"0";"5";"0"\n},
  );
  for my $tema (keys %csv) {
    my $zip = "$tmp/$EduMaps::Ingestion::Job::SetoresCenso2022::ZIP{$tema}";
    my $bytes = Encode::encode('latin1', $csv{$tema});
    IO::Compress::Zip::zip(\$bytes => $zip, Name => "Agregados_por_setores_${tema}_BR.csv")
      or die $IO::Compress::Zip::ZipError;
  }

  my $j = $JOB->new(log => Mojo::Log->new(level => 'fatal'), app => $app,
                    config => { raw_dir => "$tmp/raw" });
  my $ok = eval {
    is($j->carregar_malha({ gpkg => $gpkg }), 2, 'malha: 2 setores (válido + reparado), órfão fora');
    my ($valida, $srid, $tipo) = $dbh->selectrow_array(
      q{SELECT bool_and(ST_IsValid(geometry)), min(ST_SRID(geometry)), min(GeometryType(geometry))
          FROM clean.malha_setor_censitario WHERE codigo_setor = ANY(?)}, undef, \@setores);
    ok($valida, 'todas as geometrias válidas (laço reparado)');
    is($srid, 4674, 'SRID 4674');
    is($tipo, 'MULTIPOLYGON', 'multipolígono');
    ok(!$dbh->selectrow_array(q{SELECT to_regclass('raw.stage_setores_cd2022')}), 'staging apagada');
    my ($notas, $manif) = $dbh->selectrow_array(
      q{SELECT notes, raw_manifest::text FROM clean.import_metadata WHERE table_name = 'clean.malha_setor_censitario'});
    like($notas, qr/1 geometrias inválidas reparadas/, 'reparo contado nas notas');
    like($notas, qr/1 setores fora por município ausente/, 'órfão contado nas notas');
    like($manif // '', qr/sha256/, 'GPKG no manifesto');

    is($j->carregar_censo({ dir_zips => $tmp }), 2, 'censo: 2 setores da malha (o órfão fica fora pela FK)');
    my $r = $dbh->selectrow_hashref(
      q{SELECT * FROM clean.censo2022_setor WHERE codigo_setor = ?}, undef, $setores[0]);
    is($r->{dom_total}, 4, 'basico');
    is($r->{pop_total}, 10, 'demografia');
    is($r->{idade_20_29}, 3, '20-29 = 1 + 2');
    ok(!defined $r->{idade_30_39}, 'X -> NULL');
    ok(!defined $r->{cor_preta}, 'X -> NULL na cor');
    is($r->{cor_amarela}, 0, 'zero real fica zero');
    ok($r->{supressao_celula_pequena}, 'supressão marcada');
    ok(!defined $r->{$_}, "$_ NULL (sem fonte)") for qw(esc_sup_comp rend_media cor_sem_decl);
    my $r2 = $dbh->selectrow_hashref(q{SELECT * FROM clean.censo2022_setor WHERE codigo_setor = ?}, undef, $setores[1]);
    ok(!$r2->{supressao_celula_pequena}, 'setor sem X não é marcado');
    ok(!defined $r2->{pop_total}, 'setor sem linha na demografia: NULL, não 0');

    # Idempotência: recarregar não duplica nem herda valores antigos
    is($j->carregar_censo({ dir_zips => $tmp }), 2, 'recarga idempotente');
    1;
  };
  my $err = $@;
  $limpar->();
  $dbh->do(q{DELETE FROM clean.import_metadata WHERE table_name IN ('clean.malha_setor_censitario','clean.censo2022_setor')});
  for my $m (@$meta_antes) {
    my @c = sort keys %$m;
    $dbh->do(sprintf('INSERT INTO clean.import_metadata (%s) VALUES (%s)', join(',', @c), join(',', ('?') x @c)),
      undef, @{$m}{@c});
  }
  fail("integração: $err") unless $ok;
};

done_testing();
