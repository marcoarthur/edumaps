use lib qw(t/lib lib);
use strict;
use warnings;
no warnings qw(once redefine);
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path);
use File::Temp qw(tempdir);

# Loader MapBiomas (#241, P3 da #156): estatística oficial da Coleção 10 por
# município × classe × ano, com os biomas somados.
my $JOB = 'EduMaps::Ingestion::Job::MapBiomas';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

# ---------------------------------------------------------------- mocks
{
  package MbDBH;
  sub new { my ($c, %o) = @_; bless { dos => [], malha => [], %o }, $c }
  sub do {
    my ($s, $sql, undef, @p) = @_;
    die "boom: violação\n" if $s->{falhar} && $sql =~ /^INSERT INTO clean\.mapbiomas/;
    push @{ $s->{dos} }, [$sql, @p];
    return 1;
  }
  sub selectall_arrayref { [ map { [$_] } @{ $_[0]{malha} } ] }
  package MbStorage;
  sub new { my ($c, %a) = @_; bless {%a}, $c }
  sub dbh { $_[0]{dbh} }
  sub txn_do { my ($s, $code) = @_; $s->{txn}++; return $code->() }
  package MbSchema; sub new { my ($c, %a) = @_; bless {%a}, $c } sub storage { $_[0]{storage} }
  package MbApp;    sub new { my ($c, %a) = @_; bless {%a}, $c } sub schema  { $_[0]{schema} }
}
sub mock_app {
  my ($dbh) = @_;
  return MbApp->new(schema => MbSchema->new(storage => MbStorage->new(dbh => $dbh)));
}

# CSV como o ogr2ogr devolve (HEADERS=FORCE, FIELD_TYPES=STRING): UTF-8,
# números entre aspas, nomes com acento e vírgula.
my $CAB = join(',', qw(ID country biome state municipality), '"municipality - state"',
  qw(geocode feature_id class class_level_0 class_level_1 class_level_2 class_level_3 class_level_4),
  2014 .. 2016);
sub linha {
  my ($id, $bioma, $mun, $geo, $cls, $nivel4, @areas) = @_;
  return join(',', qq("$id"), 'Brasil', $bioma, 'X', qq("$mun"), qq("$mun - XX"), qq("$geo"), '"1"',
    qq("$cls"), 'Natural', 'a', 'b', 'c', qq("$nivel4"), map { qq("$_") } @areas);
}
my $FIXTURE = join("\n", $CAB,
  linha(0, 'Amazônia', 'São João, do Sul', '1200013', 3, '1.1. Forest Formation', 10, 100, 200),
  linha(1, 'Cerrado',  'São João, do Sul', '1200013', 3, '1.1. Forest Formation', 5,  50.5, 1e2),
  linha(2, 'Cerrado',  'São João, do Sul', '1200013', 0, '6. Not Observed',       1,  2,   3),
  linha(3, 'Pampa',    'Lagoa dos Patos',  '4300002', 33, '5.1. River, Lake and Ocean', 7, 8, 9),
) . "\n";

my $tmp = tempdir(CLEANUP => 1);
my $csv = "$tmp/cov.csv";
path($csv)->spew($FIXTURE, 'UTF-8');

# ---------------------------------------------------------------- anos
subtest 'anos: padrão 2015-2024, lista, intervalo e limites da Coleção 10' => sub {
  is_deeply([ job()->anos({}) ], [2015 .. 2024], 'padrão = decisão do developer');
  is_deeply([ job()->anos({ anos => '2019,2021-2023' }) ], [2019, 2021, 2022, 2023], 'lista + intervalo');
  is_deeply([ job()->anos({ anos => '2016,2015,2016' }) ], [2015, 2016], 'ordenado e sem repetição');
  eval { job()->anos({ anos => '1984-1990' }) };
  like($@, qr/1985–2024/, 'fora da coleção morre com o intervalo válido');
  eval { job()->anos({ anos => '2020-2018' }) };
  like($@, qr/invertido/, 'intervalo invertido morre');
  eval { job()->anos({ anos => 'abc' }) };
  like($@, qr/AAAA/, 'formato inválido morre');
};

# ---------------------------------------------------------------- agregar
subtest 'agregar: soma os biomas por (município, classe, ano) e filtra anos' => sub {
  my $ag = job()->agregar($csv, [2015, 2016]);
  is($ag->{lidas}, 4, '4 linhas município × bioma × classe');
  is($ag->{soma}{'1200013|3|2015'}, 150.5, 'Amazônia + Cerrado somados (100 + 50.5)');
  is($ag->{soma}{'1200013|3|2016'}, 300, 'notação 1e2 lida como 100');
  is($ag->{soma}{'1200013|0|2016'}, 3, 'classe 0 (Not Observed) entra');
  ok(!exists $ag->{soma}{'1200013|3|2014'}, '2014 fora do filtro de anos');
  is($ag->{desc}{3}, '1.1. Forest Formation', 'classe_desc = class_level_4');
  is($ag->{nome}{1200013}, 'São João, do Sul', 'nome com acento e vírgula (CSV com aspas)');
};

subtest 'agregar: ano pedido ausente na planilha morre com a lista recebida' => sub {
  eval { job()->agregar($csv, [2017]) };
  like($@, qr/faltam colunas.*2017/s, 'cita o ano ausente');
};

subtest 'agregar: geocode inválido morre (não vira linha silenciosa)' => sub {
  my $ruim = "$tmp/ruim.csv";
  path($ruim)->spew(join("\n", $CAB, linha(0, 'Pampa', 'X', '12345', 3, 'f', 1, 1, 1)) . "\n", 'UTF-8');
  eval { job()->agregar($ruim, [2015]) };
  like($@, qr/geocode\/classe válidos/, 'mensagem cita geocode/classe');
};

# ---------------------------------------------------------------- órfãos
subtest 'separar_orfaos: fora da malha vai para o relatório; km2 = ha/100' => sub {
  my $ag = job()->agregar($csv, [2015, 2016]);
  my ($linhas, $orf) = job()->separar_orfaos($ag, { 1200013 => 1 });
  is(scalar @$linhas, 4, '2 classes × 2 anos do município da malha');
  my ($l) = grep { $_->{classe} eq '3' && $_->{ano} == 2015 } @$linhas;
  is($l->{area_ha}, 150.5, 'hectares');
  is($l->{area_km2}, 1.505, 'km² = ha/100');
  is(scalar @$orf, 1, 'a lagoa é órfã');
  is($orf->[0]{geocode}, '4300002', 'geocode da lagoa');
  is($orf->[0]{area_ha}, 17, 'área somada dos anos pedidos (8 + 9)');

  my $rel = "$tmp/orfaos.csv";
  is(job()->registrar_orfaos($orf, $rel), 1, 'um órfão registrado');
  like(path($rel)->slurp('UTF-8'), qr/^geocode,nome,linhas,area_ha\n4300002,"?Lagoa dos Patos"?,2,17\.0000\n/,
    'relatório com geocode, nome, linhas e área');
};

# ---------------------------------------------------------------- carga
subtest 'carregar: substitui o recorte (colecao, anos) e insere em lote' => sub {
  my $dbh = MbDBH->new;
  my $j = job(app => mock_app($dbh));
  my $ag = $j->agregar($csv, [2015, 2016]);
  my ($linhas) = $j->separar_orfaos($ag, { 1200013 => 1 });
  is($j->carregar($linhas, [2015, 2016]), 4, '4 linhas');
  my ($del, @ins) = @{ $dbh->{dos} };
  like($del->[0], qr/^DELETE FROM clean\.mapbiomas_cobertura WHERE colecao = \? AND ano = ANY/, 'DELETE do recorte primeiro');
  is($del->[1], 'collection10', 'colecao fixa');
  is_deeply($del->[2], [2015, 2016], 'anos do recorte');
  is(scalar @ins, 1, 'um INSERT (lote)');
  like($ins[0][0], qr/ON CONFLICT \(codigo_ibge, ano, colecao, classe\) DO UPDATE/, 'idempotente na PK');
  is(scalar(@{ $ins[0] }) - 1, 4 * 7, '7 parâmetros por linha');
  is($j->app->schema->storage->{txn}, 1, 'numa transação');

  my $ruim = MbDBH->new(falhar => 1);
  eval { job(app => mock_app($ruim))->carregar($linhas, [2015]) };
  like($@, qr/nada gravado: boom: violação/, 'erro original preservado');
};

subtest 'comando_xlsx_csv: HEADERS=FORCE e a aba COVERAGE_10' => sub {
  my $c = join ' ', @{ job()->comando_xlsx_csv('/x/col10.xlsx', '/y/out.csv') };
  like($c, qr/^ogr2ogr -f CSV /, 'ogr2ogr para CSV');
  like($c, qr/-oo HEADERS=FORCE/, 'cabeçalho forçado (anos numéricos)');
  like($c, qr/-oo FIELD_TYPES=STRING/, 'sem adivinhar tipos');
  like($c, qr{/y/out\.csv /x/col10\.xlsx COVERAGE_10$}, 'destino, origem e aba');
};

# ---------------------------------------------------------------- run
subtest 'run: ponta a ponta com xlsx local, órfão, metadata e bruto' => sub {
  my $dbh = MbDBH->new(malha => ['1200013']);
  my $j = job(app => mock_app($dbh),
              config => { raw_dir => "$tmp/raw", dir_trabalho => "$tmp/trab" });
  my $xlsx = "$tmp/MAPBIOMAS_BRAZIL-COL.10-BIOME_STATE_MUNICIPALITY.xlsx";
  path($xlsx)->spew('xlsx de mentira');
  my @cmds;
  local *EduMaps::Ingestion::Job::MapBiomas::executar = sub {
    my ($self, $argv) = @_;
    push @cmds, $argv;
    path($argv->[-3])->spew($FIXTURE, 'UTF-8');    # o "ogr2ogr" gera o CSV
    return 1;
  };
  my $n = $j->run({ xlsx => $xlsx, anos => '2015-2016' });
  is($n, 4, '4 linhas carregadas');
  is(scalar @cmds, 1, 'um ogr2ogr');
  ok(-f "$tmp/trab/mapbiomas_orfaos.csv", 'relatório de órfãos escrito');
  my ($meta) = grep { $_->[0] =~ /INSERT INTO clean\.import_metadata/ } @{ $dbh->{dos} };
  ok($meta, 'import_metadata gravado');
  is($meta->[1], 'clean.mapbiomas_cobertura', 'tabela');
  is($meta->[4], 'CC-BY-4.0 (MapBiomas)', 'licença');
  like($meta->[6], qr/Coleção 10.*2015–2016.*hectares.*Órfãos.*: 1/s, 'nota com coleção, anos, unidade e órfãos');
  like($meta->[7] // '', qr/sha256/, 'bruto no manifesto');
};

subtest 'run: nada casa com a malha morre (não é sucesso vazio)' => sub {
  my $j = job(app => mock_app(MbDBH->new(malha => [])),
              config => { raw_dir => "$tmp/raw2", dir_trabalho => "$tmp/trab2" });
  my $xlsx = "$tmp/col10b.xlsx";
  path($xlsx)->spew('x');
  local *EduMaps::Ingestion::Job::MapBiomas::executar = sub {
    path($_[1][-3])->spew($FIXTURE, 'UTF-8'); 1 };
  eval { $j->run({ xlsx => $xlsx, anos => '2015' }) };
  like($@, qr/nenhuma linha casou/, 'falha alta');
};

subtest 'dry-run: sanidade sem baixar nem gravar' => sub {
  my $dbh = MbDBH->new;
  my $j = job(app => mock_app($dbh), dry_run => 1);
  local *EduMaps::Ingestion::Job::MapBiomas::_ogr2ogr_versao = sub { 'GDAL 3.6.2' };
  local *EduMaps::Ingestion::Job::MapBiomas::executar = sub { die "não pode executar no dry-run\n" };
  is($j->run({ xlsx => "$tmp/col10b.xlsx" }), 0, 'devolve 0');
  is(scalar @{ $dbh->{dos} }, 0, 'nada gravado');

  local *EduMaps::Ingestion::Job::MapBiomas::_ogr2ogr_versao = sub { '' };
  eval { $j->run({ xlsx => "$tmp/col10b.xlsx" }) };
  like($@, qr/ogr2ogr ausente/, 'sem GDAL o dry-run acusa');
};

subtest 'tabelas e descrição' => sub {
  is_deeply([ job()->tabelas ], ['clean.mapbiomas_cobertura'], 'tabela declarada');
  unlike(job()->description, qr/aguardando/, 'descrição não diz mais "aguardando loader"');
};

# ---------------------------------------------------------------- integração
# Banco intencional (EDUMAPS_DB_*, o do CI) + ogr2ogr: xlsx sintético gerado
# pelo próprio GDAL a partir do CSV, lido de volta pelo job. Apaga tudo no fim.
subtest 'integração: xlsx real (GDAL) no banco do CI' => sub {
  plan skip_all => 'sem EDUMAPS_DB_HOST (base intencional)' unless $ENV{EDUMAPS_DB_HOST};
  plan skip_all => 'sem ogr2ogr' unless `ogr2ogr --version 2>/dev/null`;
  require EduMaps::Ingestion::App;
  my $app = eval { EduMaps::Ingestion::App->new };
  my $dbh = $app && eval { $app->schema->storage->dbh };
  plan skip_all => 'sem BD' unless $dbh && $dbh->selectrow_array("SELECT to_regclass('clean.mapbiomas_cobertura')");
  my ($mun) = $dbh->selectrow_array('SELECT codigo_ibge FROM clean.malha_municipio ORDER BY 1 LIMIT 1');
  plan skip_all => 'malha_municipio vazia' unless $mun;

  my $dir = tempdir(CLEANUP => 1);
  my $fx = $FIXTURE;
  $fx =~ s/1200013/$mun/g;
  path("$dir/COVERAGE_10.csv")->spew($fx, 'UTF-8');
  my $xlsx = "$dir/col10.xlsx";
  system('ogr2ogr', '-f', 'XLSX', $xlsx, "$dir/COVERAGE_10.csv", '-nln', 'COVERAGE_10',
         '-oo', 'HEADERS=YES', '-oo', 'AUTODETECT_TYPE=NO') == 0 or BAIL_OUT('ogr2ogr não gerou o xlsx de teste');

  my $meta_antes = $dbh->selectall_arrayref(
    q{SELECT * FROM clean.import_metadata WHERE table_name = 'clean.mapbiomas_cobertura'}, { Slice => {} });
  my $limpar = sub {
    $dbh->do(q{DELETE FROM clean.mapbiomas_cobertura WHERE colecao = 'collection10' AND codigo_ibge IN (?, '4300002')},
      undef, $mun);
  };
  $limpar->();

  my $j = $JOB->new(log => Mojo::Log->new(level => 'fatal'), app => $app,
                    config => { raw_dir => "$dir/raw", dir_trabalho => "$dir/trab" });
  my $ok = eval {
    is($j->run({ xlsx => $xlsx, anos => '2015-2016' }), 4, 'run: 4 linhas');
    my $r = $dbh->selectall_hashref(
      q{SELECT classe || '|' || ano AS k, area_ha, area_km2, classe_desc FROM clean.mapbiomas_cobertura
         WHERE colecao = 'collection10' AND codigo_ibge = ?}, 'k', undef, $mun);
    is(0 + $r->{'3|2015'}{area_ha}, 150.5, 'biomas somados no banco');
    is(0 + $r->{'3|2015'}{area_km2}, 1.505, 'km²');
    is($r->{'0|2016'}{classe_desc}, '6. Not Observed', 'classe_desc');
    ok(!$dbh->selectrow_array(
      q{SELECT 1 FROM clean.mapbiomas_cobertura WHERE codigo_ibge = '4300002' AND colecao = 'collection10'}),
      'órfão fora da tabela');
    is($j->run({ xlsx => $xlsx, anos => '2015-2016' }), 4, 'recarga idempotente');
    is($dbh->selectrow_array(
      q{SELECT count(*) FROM clean.mapbiomas_cobertura WHERE colecao = 'collection10' AND codigo_ibge = ?},
      undef, $mun), 4, 'sem duplicata');
    1;
  };
  my $err = $@;
  $limpar->();
  $dbh->do(q{DELETE FROM clean.import_metadata WHERE table_name = 'clean.mapbiomas_cobertura'});
  for my $m (@$meta_antes) {
    my @c = grep { $_ ne 'id_import' } sort keys %$m;
    $dbh->do(sprintf('INSERT INTO clean.import_metadata (%s) VALUES (%s)', join(',', @c), join(',', ('?') x @c)),
      undef, @{$m}{@c});
  }
  ok($ok, 'integração sem exceção') or diag $err;
};

done_testing();
