use lib qw(t/lib lib);
use strict;
use warnings;
no warnings qw(once redefine);
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path);
use Mojo::JSON qw(decode_json);
use Text::CSV;
use File::Temp qw(tempdir);
use File::Spec;

# =================================================================
# Regressão do loader MapBiomasRisco (#278): exposição a risco (Fogo + Solo)
# na área de influência da escola.
# =================================================================

my $JOB = 'EduMaps::Ingestion::Job::MapBiomasRisco';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

{
  package RbDBH;
  sub new { my ($c, %o) = @_; bless { dos => [], copy => [], %o }, $c }
  sub prepare { my ($s, $sql) = @_; $s->{consulta} = $sql; return bless { rows => $s->{rows} // [] }, 'RbSTH' }
  sub do { my ($s, $sql, $attr, @p) = @_; push @{ $s->{dos} }, [ $sql, @p ]; return 1 }
  sub pg_putcopydata { my ($s, $d) = @_; push @{ $s->{copy} }, $d; return 1 }
  sub pg_putcopyend  { my ($s) = @_; $s->{copy_end}++; return 1 }
  package RbSTH; sub execute { 1 } sub fetchrow_arrayref { my $s = shift; return shift @{ $s->{rows} } }
  package RbStorage; sub new { my ($c, %a) = @_; bless {%a}, $c } sub dbh { $_[0]{dbh} }
    sub txn_do { my ($s, $code) = @_; $s->{txn}++; return $code->() }
  package RbSchema; sub new { my ($c, %a) = @_; bless {%a}, $c } sub storage { $_[0]{storage} }
  package RbApp; sub new { my ($c, %a) = @_; bless {%a}, $c } sub schema { $_[0]{schema} }
}
sub mock_app { my ($dbh) = @_; return RbApp->new(schema => RbSchema->new(storage => RbStorage->new(dbh => $dbh))) }

# ---------------------------------------------------------------- args
is_deeply([ job()->tabelas({}) ], ['clean.mapbiomas_escola_risco'], 'tabela declarada');
is_deeply([ job()->anos({}) ], [2020], 'ano padrão = 2020');
eval { job()->anos({ ano => 2021 }) };
like($@, qr/1985/, 'recusa 2021 (série do fogo vai até 2020)');
eval { job()->anos({ ano => 1984 }) };
like($@, qr/1985/, 'recusa 1984');
is(job()->raio({}), 1000, 'raio padrão');
eval { job()->raio({ raio => 1500 }) };
like($@, qr/raio/, 'recusa raio não materializado');
is(job()->uf({ uf => 'sp' }), 'SP', 'normaliza UF');
is_deeply(job()->municipios({ municipios => '3554102,3554003' }), ['3554102', '3554003'],
  'lista de municípios (recorte fino por região)');
is(job()->municipios({}), undef, 'sem municípios = sem filtro');
eval { job()->municipios({ municipios => 'abc' }) };
like($@, qr/inválido/, 'recusa código IBGE inválido');

# ---------------------------------------------------------------- URLs pinadas
is(job()->url_fogo(2020),
  'https://storage.googleapis.com/mapbiomas-public/brasil/fire/coverage-frequency-1/brasil_fire_frequency_1985_2020.tif',
  'URL do fogo pinada (coverage-frequency-1, 1985_<ANO>)');
is(job()->url_solo(2020),
  'https://storage.googleapis.com/mapbiomas-public/brasil/soil/soil_total_carbon_2020.tif',
  'URL do solo pinada');
eval { job()->url_fogo(2021) };
like($@, qr/ano inválido/, 'fogo: nunca monta o caminho com ano fora da série');
eval { job()->url_solo('x') };
like($@, qr/ano inválido/, 'solo: nunca interpola texto livre');

# ---------------------------------------------------------------- allowlist real
{
  use EduMaps::Data::Allowlist;
  my $al = EduMaps::Data::Allowlist->new;
  ok($al->validate_url(job()->url_fogo(2020)), 'fogo no allowlist') or diag $al->last_error;
  ok($al->validate_url(job()->url_solo(2020)), 'solo no allowlist') or diag $al->last_error;
}

# ---------------------------------------------------------------- contrato
{
  my $j = job();
  my @c = qw(co_entidade nu_ano_censo ano raio_m fogo_frequencia_media
             fogo_frequencia_max fogo_fracao_queimada solo_carbono_medio);
  is_deeply([ $j->_comparar_colunas([@c], [@c]) ], [], 'contrato igual não gera diferenças');
  is(scalar($j->_comparar_colunas([@c, 'x'], [@c])), 1, 'detecta coluna a mais');
}

# ---------------------------------------------------------------- carregar (COPY)
{
  my $dbh = RbDBH->new;
  my $j = job(app => mock_app($dbh));
  my @rows = (
    { co_entidade => 100, nu_ano_censo => 2025, ano => 2020, raio_m => 1000,
      fogo_frequencia_media => '1.5', fogo_frequencia_max => 3,
      fogo_fracao_queimada => '0.5', solo_carbono_medio => '50.0' },
  );
  my $n = $j->carregar(\@rows, [2020], 1000);
  is($n, 1, 'carrega 1 linha');
  my ($del) = grep { $_->[0] =~ /^DELETE FROM clean\.mapbiomas_escola_risco/ } @{ $dbh->{dos} };
  ok($del, 'DELETE escopado às escolas da carga (blocos por região)');
  like($del->[0], qr/co_entidade = ANY/, 'DELETE por co_entidade');
  my ($copy) = grep { $_->[0] =~ /^COPY clean\.mapbiomas_escola_risco/ } @{ $dbh->{dos} };
  ok($copy, 'usa COPY');
  like($copy->[0], qr/FROM STDIN WITH \(FORMAT csv\)/, 'COPY ... FORMAT csv');
  is(scalar @{ $dbh->{copy} }, 1, 'uma linha enviada');
  ok($dbh->{copy_end}, 'fecha o COPY');
}

# ---------------------------------------------------------------- process_csv
{
  my $j = job(app => mock_app(RbDBH->new));
  my $dir = tempdir(CLEANUP => 1);
  my $csv = File::Spec->catfile($dir, 'out.csv');
  path($csv)->spew(join("\n",
    'co_entidade,nu_ano_censo,ano,raio_m,fogo_frequencia_media,fogo_frequencia_max,fogo_fracao_queimada,solo_carbono_medio',
    '100,2025,2020,1000,1.5,3,0.5,50.0',
    '200,2025,2020,1000,,,,' # sem indicador -> colunas vazias -> NULL (mas com linha)
  ) . "\n");
  my $rows = $j->process_csv($csv);
  is(scalar @$rows, 2, 'lê 2 linhas');
  is($rows->[0]{fogo_frequencia_max}, 3, 'inteiro preservado');
  ok(!defined $rows->[1]{solo_carbono_medio}, 'vazio -> undef (NULL, #154)');

  # nodata do MapBiomas (-3.4e38) repassado cru pelo R como carbono negativo
  path($csv)->spew(join("\n",
    'co_entidade,nu_ano_censo,ano,raio_m,fogo_frequencia_media,fogo_frequencia_max,fogo_fracao_queimada,solo_carbono_medio',
    '300,2025,2020,1000,1.0,2,0.2,-211.05',
    '400,2025,2020,1000,1.0,2,0.2,-3.4e38'
  ) . "\n");
  $rows = $j->process_csv($csv);
  ok(!defined $rows->[0]{solo_carbono_medio}, 'carbono negativo -> NULL, nunca 0 (#154)');
  ok(!defined $rows->[1]{solo_carbono_medio}, 'nodata -3.4e38 também vira NULL');
  is($rows->[0]{fogo_fracao_queimada}, '0.2', 'os outros indicadores ficam intactos');

  path($csv)->spew(join("\n",
    'co_entidade,nu_ano_censo,ano,raio_m,fogo_frequencia_media,fogo_frequencia_max,fogo_fracao_queimada,solo_carbono_medio',
    '100,2025,2020,1000,1.5,3,1.5,50' # fração > 1
  ) . "\n");
  eval { $j->process_csv($csv) };
  like($@, qr/\[0,1\]/, 'recusa fração fora de [0,1]');
}

# ------------------------------------------------- exportação em lotes (OOM)
# 404 buffers com geometria (1 sem) e TAMANHO_LOTE=400 -> lotes de 400 e 4.
{
  my @linhas = map { [ 1000 + $_, 2025, '{"type":"Point","coordinates":[-46,-23]}'] } 1 .. 405;
  $linhas[2][2] = undef;    # sem geometria: não exporta, não conta
  my $dbh = RbDBH->new(rows => \@linhas);
  my $j = job(app => mock_app($dbh));
  my $dir = tempdir(CLEANUP => 1);
  my $lotes = $j->exportar_buffers_lotes(File::Spec->catfile($dir, 'buf'), 1000, 'SP', undef, undef);

  is(scalar @$lotes, 2, '404 buffers -> 2 lotes (teto de 400, OOM)');
  is_deeply([ map { $_->[2] } @$lotes ], [400, 4], 'tamanhos dos lotes');
  is($lotes->[0][1], File::Spec->catfile($dir, 'buf.geojson'), 'lote 1 no caminho base');
  is($lotes->[1][1], File::Spec->catfile($dir, 'buf_l2.geojson'), 'lote 2 em <base>_l2.geojson');

  my $l1 = decode_json(path($lotes->[0][1])->slurp);
  is($l1->{type}, 'FeatureCollection', 'lote 1 é uma FeatureCollection fechada');
  is(scalar @{ $l1->{features} }, 400, 'lote 1 com 400 features');
  is($l1->{features}[0]{properties}{co_entidade}, 1001, 'co_entidade preservado');
  is($l1->{features}[0]{properties}{nu_ano_censo}, 2025, 'nu_ano_censo preservado');
  is(scalar @{ decode_json(path($lotes->[1][1])->slurp)->{features} }, 4, 'lote 2 com as 4 restantes');
  like($dbh->{consulta}, qr/tier = 'buffer'/, 'mesmo recorte de buffers de sempre');
  like($dbh->{consulta}, qr/sg_uf/, 'recorte por UF aplicado');

  my $vazio = job(app => mock_app(RbDBH->new(rows => [])));
  is_deeply($vazio->exportar_buffers_lotes(File::Spec->catfile($dir, 'nada'), 1000, 'SP', undef, undef),
    [], 'sem buffers -> sem lotes');
}

# ---------------------------------------------------------------- guarda do lote
# csv + órfãos = buffers exportados (506/506 blocos saudáveis); o CSV do bloco
# anterior era lido como sucesso em 2026-10-19 (SP/RJ/PE).
{
  my $j = job(app => mock_app(RbDBH->new));
  eval { $j->conferir_lote('ano 2020, lote 3/28', 400, 399, 1) };
  ok(!$@, 'a soma fecha (399 + 1 órfão = 400 buffers)');
  eval { $j->conferir_lote('ano 2020, lote 3/28', 400, 0, 400) };
  ok(!$@, 'lote inteiramente órfão também fecha (0 + 400)');
  eval { $j->conferir_lote('ano 2020, lote 1/1', 11147, 154, 0) };
  like($@, qr/linhas \(154\) \+ órfãos \(0\) ≠ buffers exportados \(11147\)/,
    'CSV de outro bloco é recusado com o número na mensagem');
  like($@, qr/nada carregado/, 'nada é carregado quando a soma não fecha');
}

# ---------------------------------------------------------------- R: agregação (--dados)
subtest 'R: agregação fogo/solo (modo --dados)' => sub {
  my $rscript = `command -v Rscript 2>/dev/null`; chomp $rscript;
  plan skip_all => 'Rscript ausente' unless $rscript && -x $rscript;

  my $dir = tempdir(CLEANUP => 1);
  my $dados = File::Spec->catfile($dir, 'dados.csv');
  path($dados)->spew(join("\n",
    'co_entidade,nu_ano_censo,indicador,valor,peso',
    '100,2025,fogo,3,0.5',
    '100,2025,fogo,0,0.5',      # meio buffer sem fogo
    '100,2025,solo,50,1.0',
    '200,2025,fogo,0,1.0',      # sem fogo, sem solo
  ) . "\n");
  my $saida = File::Spec->catfile($dir, 'saida.csv');
  my $script = File::Spec->rel2abs(
    File::Spec->catfile('templates', 'rscripts', 'ingestion', 'extract_mapbiomas_risco.R'));
  my $out = `Rscript --vanilla "$script" --dados="$dados" --ano=2020 --raio=1000 --saida="$saida" 2>&1`;
  is($? >> 8, 0, 'o extractor R termina com sucesso') or diag $out;

  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
  open my $fh, '<:encoding(UTF-8)', $saida or die "Não abriu $saida: $!";
  my $cab = $csv->getline($fh);
  is_deeply($cab, [qw(co_entidade nu_ano_censo ano raio_m fogo_frequencia_media
                      fogo_frequencia_max fogo_fracao_queimada solo_carbono_medio)],
    'cabeçalho do contrato');
  my %l;
  while (my $r = $csv->getline($fh)) { $l{ $r->[0] } = $r }
  close $fh;

  is(scalar keys %l, 2, '2 escolas');
  is($l{100}[4], '1.500', 'fogo: média ponderada = (3×0,5 + 0×0,5)/1 = 1,5');
  is($l{100}[5], '3', 'fogo: máximo = 3');
  is($l{100}[6], '0.500000', 'fogo: fração queimada = 0,5 (6 casas fixas)');
  is($l{100}[7], '50.000', 'solo: média = 50');
  is($l{200}[4], '0.000', 'fogo zero real (não NA)');
  is($l{200}[7], '', 'solo ausente -> vazio (NULL, #154)');
};

done_testing;
