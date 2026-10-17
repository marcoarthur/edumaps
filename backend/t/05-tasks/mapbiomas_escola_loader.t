use lib qw(t/lib lib);
use strict;
use warnings;
no warnings qw(once redefine);
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path);
use Text::CSV;
use File::Temp qw(tempdir);
use File::Spec;

# =================================================================
# Regressão do loader MapBiomasEscola (#255): cobertura do solo de 30 m
# (raster Coleção 11) arealizada sobre o buffer da escola.
#
# Não corre o raster (748 MB, minutos de terra): verifica as DECISÕES que o
# job e o extractor tomam, que é onde os defeitos aparecem —
#
#   1. a URL do COG é PINADA na coleção 11 e o ano é validado;
#   2. o contrato de colunas do CSV do R é conferido, não seguido;
#   3. o recorte (ano × raio) é SUBSTITUÍDO, e a PK usa ON CONFLICT;
#   4. um buffer sem interseção com o raster fica SEM LINHA (#154).
#
# O subteste final roda o extractor R no modo --dados (sem terra), que é
# justamente o caminho que testa a normalização: peso cru -> fração.
# =================================================================

my $JOB = 'EduMaps::Ingestion::Job::MapBiomasEscola';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

# ---------------------------------------------------------------- mocks
{
  package MbDBH;
  sub new { my ($c, %o) = @_; bless { dos => [], %o }, $c }
  sub prepare {
    my ($s, $sql) = @_;
    $s->{consulta} = $sql;
    return bless { sql => $sql, rows => $s->{rows} // [] }, 'MbSTH';
  }
  sub do {
    my ($s, $sql, $attr, @p) = @_;
    push @{ $s->{dos} }, [ $sql, @p ];
    return 1;
  }
  sub selectall_arrayref { return [] }

  package MbSTH;
  sub execute { my ($s, @p) = @_; $s->{params} = \@p; return 1 }
  sub fetchrow_arrayref { my $s = shift; return shift @{ $s->{rows} } }

  package MbStorage;
  sub new { my ($c, %a) = @_; bless {%a}, $c }
  sub dbh    { $_[0]{dbh} }
  sub txn_do { my ($s, $code) = @_; $s->{txn}++; return $code->() }

  package MbSchema; sub new { my ($c, %a) = @_; bless {%a}, $c } sub storage { $_[0]{storage} }
  package MbApp;    sub new { my ($c, %a) = @_; bless {%a}, $c } sub schema  { $_[0]{schema} }
}
sub mock_app {
  my ($dbh) = @_;
  return MbApp->new(schema => MbSchema->new(storage => MbStorage->new(dbh => $dbh)));
}

# ---------------------------------------------------------------- args
is_deeply([ job()->tabelas({}) ], ['clean.mapbiomas_escola'], 'tabela declarada');

is_deeply([ job()->anos({}) ], [2024], 'ano padrão = 2024');
is_deeply([ job()->anos({ ano => 2020 }) ], [2020], 'alias ano=');
is_deeply([ job()->anos({ anos => '2015-2017' }) ], [2015, 2016, 2017], 'intervalo de anos');
is_deeply([ job()->anos({ anos => '2019,2021' }) ], [2019, 2021], 'lista de anos');
eval { job()->anos({ anos => 2026 }) };
like($@, qr/1985/, 'recusa ano acima da Coleção 11 (2026)');
eval { job()->anos({ anos => 1984 }) };
like($@, qr/1985/, 'recusa ano abaixo da Coleção 11 (1984)');
eval { job()->anos({ anos => 'ontem' }) };
like($@, qr/AAAA/, 'recusa ano malformado');

is(job()->raio({}), 1000, 'raio padrão = 1000 m');
is(job()->raio({ raio => 500 }), 500, 'aceita raio 500 m');
is(job()->raio({ raio => 2000 }), 2000, 'aceita raio 2000 m');
eval { job()->raio({ raio => 1500 }) };
like($@, qr/raio/, 'recusa raio não materializado (1500 m)');

is(job()->uf({}), undef, 'sem UF = nacional');
is(job()->uf({ uf => 'sp' }), 'SP', 'normaliza a UF');
eval { job()->uf({ uf => 'SPX' }) };
like($@, qr/uf/, 'recusa UF inválida');

# ---------------------------------------------------------------- URL pinada
is(
  job()->url_cog(2024),
  'https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/collection11/'
    . 'lulc/coverage/brazil_coverage/brazil_coverage-col11_2024.tif',
  'URL do COG pinada na coleção 11'
);
like(job()->url_cog(1985), qr/collection11.*_1985\.tif$/, 'ano mínimo da série');
like(job()->url_cog(2025), qr/collection11.*_2025\.tif$/, 'ano máximo da série');
eval { job()->url_cog(2026) };
like($@, qr/ano inválido/, 'nunca monta o caminho com ano fora da série');
eval { job()->url_cog('../etc/passwd') };
like($@, qr/ano inválido/, 'nunca interpola texto livre no caminho');

# ---------------------------------------------------------------- contrato (herdado do Base)
{
  my $j = job();
  my @c = qw(co_entidade nu_ano_censo ano raio_m classe classe_desc fracao);
  is_deeply([ $j->_comparar_colunas([@c], [@c]) ], [], 'contrato igual não gera diferenças');
  my @mais = $j->_comparar_colunas([@c, 'extra'], [@c]);
  is(scalar @mais, 1, 'detecta coluna a mais');
  my @falta = $j->_comparar_colunas(['co_entidade'], [@c]);
  is(scalar @falta, scalar(@c) - 1, 'detecta colunas em falta');
  my @troca = $j->_comparar_colunas([qw(ano co_entidade)], [@c]);
  is(scalar(grep { defined $_->[1] && defined $_->[2] } @troca), 2, 'detecta colunas fora de ordem');
}

# ---------------------------------------------------------------- exportar_buffers
{
  my $dbh = MbDBH->new(rows => [
    [ 100, 2025, '{"type":"Point","coordinates":[0,0]}' ],
    [ 200, 2025, '{"type":"Point","coordinates":[1,1]}' ],
    [ 300, 2025, undef ],    # sem geometria: não entra
  ]);
  my $j = job(app => mock_app($dbh));
  my $dest = File::Spec->catfile(tempdir(CLEANUP => 1), 'buffers.geojson');
  my $n = $j->exportar_buffers($dest, 1000, 'ES', undef);
  is($n, 2, 'exporta só os buffers com geometria');
  like($dbh->{consulta}, qr/clean\.escola_influencia/, 'lê a camada de influência');
  like($dbh->{consulta}, qr/i\.tier = 'buffer'/, 'filtra tier=buffer');
  like($dbh->{consulta}, qr/i\.raio_m = \?/, 'filtra por raio');
  like($dbh->{consulta}, qr/e\.sg_uf = \?/, 'filtra por UF');
  like($dbh->{consulta}, qr/ST_AsGeoJSON/, 'geometria sai como GeoJSON');
  my $txt = path($dest)->slurp;
  is(() = $txt =~ /"type":"Feature"/g, 2, 'duas features no GeoJSON');
  like($txt, qr/"co_entidade":100/, 'propriedade co_entidade presente');
  like($txt, qr/^\{"type":"FeatureCollection","features":\[/, 'GeoJSON FeatureCollection');
}

# ---------------------------------------------------------------- carregar
{
  my $dbh = MbDBH->new;
  my $j = job(app => mock_app($dbh));
  my @rows = (
    { co_entidade => 100, nu_ano_censo => 2025, ano => 2024, raio_m => 1000,
      classe => '3', classe_desc => '1.1. Forest Formation', fracao => 0.75 },
    { co_entidade => 100, nu_ano_censo => 2025, ano => 2024, raio_m => 1000,
      classe => '15', classe_desc => '3.2. Pasture', fracao => 0.25 },
  );
  my $n = $j->carregar(\@rows, [2024], 1000);
  is($n, 2, 'carrega as duas linhas');

  my ($del) = grep { $_->[0] =~ /^DELETE FROM clean\.mapbiomas_escola/ } @{ $dbh->{dos} };
  ok($del, 'faz DELETE do recorte antes de inserir');
  like($del->[0], qr/ano = ANY/, 'DELETE limitado ao ano do recorte');
  like($del->[0], qr/raio_m = \?/, 'DELETE limitado ao raio do recorte');

  my ($ins) = grep { $_->[0] =~ /^INSERT INTO clean\.mapbiomas_escola/ } @{ $dbh->{dos} };
  ok($ins, 'insere em lote');
  like($ins->[0], qr/ON CONFLICT \(co_entidade, nu_ano_censo, ano, raio_m, classe\)/,
    'ON CONFLICT pela PK completa');
  is(scalar(grep { $_ eq 'collection11' } @$ins), 2, 'grava a coleção em cada linha');
}

# ---------------------------------------------------------------- process_csv
{
  my $j = job(app => mock_app(MbDBH->new));
  my $dir = tempdir(CLEANUP => 1);
  my $csv = File::Spec->catfile($dir, 'out.csv');
  path($csv)->spew(join("\n",
    'co_entidade,nu_ano_censo,ano,raio_m,classe,classe_desc,fracao',
    '100,2025,2024,1000,3,1.1. Forest Formation,0.75',
    '100,2025,2024,1000,15,3.2. Pasture,0.25',
  ) . "\n");
  my $rows = $j->process_csv($csv, 2024, 1000);
  is(scalar @$rows, 2, 'lê as duas linhas do CSV');
  is($rows->[0]{classe}, '3', 'preserva a classe');
  is($rows->[1]{fracao}, '0.25', 'preserva a fração');

  # Contrato diferente aborta ANTES de aceitar qualquer linha.
  path($csv)->spew("co_entidade,ano\n100,2024\n");
  eval { $j->process_csv($csv, 2024, 1000) };
  like($@, qr/contrato/, 'recusa CSV fora do contrato');

  # Fração fora de [0,1] é recusada (#154: nunca inventar 0).
  path($csv)->spew(join("\n",
    'co_entidade,nu_ano_censo,ano,raio_m,classe,classe_desc,fracao',
    '100,2025,2024,1000,3,1.1. Forest Formation,1.5',
  ) . "\n");
  eval { $j->process_csv($csv, 2024, 1000) };
  like($@, qr/\[0,1\]/, 'recusa fração fora de [0,1]');
}

# ---------------------------------------------------------------- dry-run valida antes da rede
{
  my $j = job(app => mock_app(MbDBH->new), dry_run => 1);
  eval { $j->run({ anos => 2026 }) };
  like($@, qr/1985/, 'dry-run recusa o ano antes de qualquer requisição');
}

# ---------------------------------------------------------------- R: normalização (--dados)
subtest 'R: normalização peso -> fração (modo --dados)' => sub {
  my $rscript = `command -v Rscript 2>/dev/null`;
  chomp $rscript;
  plan skip_all => 'Rscript ausente neste host' unless $rscript && -x $rscript;

  my $dir   = tempdir(CLEANUP => 1);
  my $dados = File::Spec->catfile($dir, 'dados.csv');
  path($dados)->spew(join("\n",
    'co_entidade,nu_ano_censo,classe,peso',
    '100,2025,3,3',
    '100,2025,15,1',
    '100,2025,999,0',    # peso 0: descartado, nunca conta como 0
    '200,2025,24,2',
    '200,2025,999,2',    # classe fora da legenda: desc de fallback
  ) . "\n");
  my $saida  = File::Spec->catfile($dir, 'saida.csv');
  my $script = File::Spec->rel2abs(
    File::Spec->catfile('templates', 'rscripts', 'ingestion', 'extract_mapbiomas_escola.R'));

  my $out = `Rscript --vanilla "$script" --dados="$dados" --ano=2024 --raio=1000 --saida="$saida" 2>&1`;
  is($? >> 8, 0, 'o extractor R termina com sucesso') or diag $out;

  # Parsear em vez de casar por regex: o write.csv do R cita as colunas de
  # texto, e a legenda tem vírgulas ("4.1. Beach, Dune and Sand Spot").
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
  open my $fh, '<:encoding(UTF-8)', $saida or die "Não abriu $saida: $!";
  my $cab = $csv->getline($fh);
  is_deeply($cab, [qw(co_entidade nu_ano_censo ano raio_m classe classe_desc fracao)],
    'cabeçalho do contrato');
  my %l;
  while (my $r = $csv->getline($fh)) {
    $l{ $r->[0] . '|' . $r->[4] } = $r;
  }
  close $fh;

  is(scalar keys %l, 4, '4 linhas de saída (o peso 0 foi descartado)');
  is($l{'100|3'}[6], '0.75', 'classe 3 = 3/4 = 0.75');
  is($l{'100|15'}[6], '0.25', 'classe 15 = 1/4 = 0.25');
  is($l{'200|24'}[6], '0.5', 'classe 24 = 2/4 = 0.5');
  is($l{'200|999'}[6], '0.5', 'classe fora da legenda = 2/4 = 0.5');
  like($l{'200|999'}[5], qr/ausente da legenda/, 'classe fora da legenda ganha desc de fallback');
  ok(!exists $l{'100|999'}, 'peso 0 é descartado (nunca 0 na saída)');
  is($l{'100|3'}[2], '2024', 'ano propagado pelo script');
  is($l{'100|3'}[3], '1000', 'raio propagado pelo script');
};

done_testing;
