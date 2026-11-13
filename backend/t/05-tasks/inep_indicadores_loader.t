use lib qw(t/lib lib);
use strict;
use warnings;
no warnings qw(once redefine);
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path tempdir);
use open qw(:std :encoding(UTF-8));

# Loader INEP (#376): taxas de rendimento e distorção idade-série por escola.
# As amostras em t/fixtures/inep/ são linhas REAIS das planilhas de 2025
# (convertidas pelo ogr2ogr como o job faz): as 10 linhas de título e
# cabeçalho, 4 escolas e o rodapé "Fonte: …".
my $JOB = 'EduMaps::Ingestion::Job::INEPIndicadores';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

{
  package InDBH;
  sub new { my ($c, %o) = @_; bless { dos => [], %o }, $c }
  sub do {
    my ($s, $sql, undef, @p) = @_;
    die "boom\n" if $s->{falhar} && $sql =~ /^INSERT/;
    push @{ $s->{dos} }, [$sql, @p];
    return 1;
  }
  package InStorage;
  sub new { my ($c, %a) = @_; bless {%a}, $c }
  sub dbh { $_[0]{dbh} }
  sub txn_do { my ($s, $code) = @_; $s->{txn}++; return $code->() }
  package InSchema; sub new { my ($c, %a) = @_; bless {%a}, $c } sub storage { $_[0]{storage} }
  package InApp;    sub new { my ($c, %a) = @_; bless {%a}, $c } sub schema  { $_[0]{schema} }
}
sub mock_app { InApp->new(schema => InSchema->new(storage => InStorage->new(dbh => $_[0]))) }

my $REND = 't/fixtures/inep/tx_rend_escolas_2025_amostra.csv';
my $TDI  = 't/fixtures/inep/tdi_escolas_2025_amostra.csv';

subtest 'anos' => sub {
  my $j = job();
  is_deeply [ $j->anos({}) ], [ 2023, 2024, 2025 ], 'padrão 2023–2025';
  is_deeply [ $j->anos({ anos => '2019,2021-2022' }) ], [ 2019, 2021, 2022 ], 'lista e intervalo';
  eval { $j->anos({ anos => '2018' }) };
  like $@, qr/cobre 2019–2025/, 'fora do que a fonte publica';
};

subtest 'URLs na allowlist real' => sub {
  my $j = job();
  is $j->url_rend(2025),
    'https://download.inep.gov.br/informacoes_estatisticas/indicadores_educacionais/2025/tx_rend_escolas_2025.zip', 'rendimento';
  is $j->url_tdi(2025),
    'https://download.inep.gov.br/informacoes_estatisticas/indicadores_educacionais/2025/TDI_2025_ESCOLAS.zip', 'distorção';
  ok eval { $j->exigir_allowlist($j->url_rend(2023)) }, 'rendimento permitido' or diag $@;
  ok eval { $j->exigir_allowlist($j->url_tdi(2023)) },  'distorção permitida' or diag $@;
  ok !eval { $j->exigir_allowlist('https://download.inep.gov.br/informacoes_estatisticas/indicadores_educacionais/2025/outro.zip') },
    'outro arquivo do mesmo diretório recusado';
};

subtest 'TLS: raízes do sistema + intermediário do INEP, sem desligar a verificação' => sub {
  my $j = job();
  ok -f $j->intermediario, 'intermediário versionado';
  my $pem = path($j->ca_bundle)->slurp;
  like $pem, qr/BEGIN CERTIFICATE/, 'bundle gerado';
  ok index($pem, $j->intermediario->slurp) >= 0, 'bundle contém o intermediário';
  ok length($pem) > length($j->intermediario->slurp) * 5, 'e as raízes do sistema';
};

subtest 'rendimento: amostra real de 2025' => sub {
  my $r = job()->ler_rendimento($REND, 2025);
  is $r->{escolas}, 4, '4 escolas lidas (rodapé e linha vazia ignorados)';
  is scalar @{ $r->{linhas} }, 8, '8 linhas escola × etapa (etapa só com "--" não vira linha)';
  my %l = map { ("$_->{cod_inep}|$_->{etapa}" => $_) } @{ $r->{linhas} };
  is scalar keys %l, 8, 'sem multiplicação: chave (escola, etapa) única';
  is_deeply [ @{ $l{'11024372|af'} }{qw(aprovacao reprovacao abandono)} ], [ 96.9, 3.1, 0 ], 'valores da planilha';
  is_deeply [ @{ $l{'11024372|fun'} }{qw(aprovacao reprovacao abandono)} ], [ 98.6, 1.4, 0 ], 'fundamental total';
  ok !exists $l{'11022558|af'}, 'anos finais "--": sem linha (nunca 0)';
  ok exists $l{'53086007|em'} && !exists $l{'53086007|fun'}, 'escola só de ensino médio';
};

subtest 'distorção: amostra real de 2025' => sub {
  my $r = job()->ler_distorcao($TDI, 2025);
  is $r->{escolas}, 4, '4 escolas';
  my %l = map { ("$_->{cod_inep}|$_->{etapa}" => $_->{distorcao}) } @{ $r->{linhas} };
  is scalar @{ $r->{linhas} }, 8, '8 linhas';
  is_deeply [ @l{qw(11024372|fun 11024372|ai 11024372|af)} ], [ 17.7, 13.6, 22.9 ], 'valores';
  is $l{'53086007|em'}, 1.7, 'ensino médio';
  ok !exists $l{'11022558|af'}, '"--" não vira linha';
};

subtest 'taxa: uma casa, "--" é NULL, fora de 0–100 morre' => sub {
  my $t = \&EduMaps::Ingestion::Job::INEPIndicadores::_taxa;
  is $t->('33.299999999999997', 'x'), 33.3, 'ruído de ponto flutuante da planilha';
  is $t->('--', 'x'), undef, '"--"';
  is $t->('', 'x'), undef, 'vazio';
  ok !eval { $t->('101', 'x'); 1 }, 'acima de 100';
  ok !eval { $t->('abc', 'x'); 1 }, 'não numérico';
};

subtest 'arquivo de outro ano, coluna faltando ou escola repetida: morre alto' => sub {
  my $dir = tempdir;
  ok !eval { job()->ler_rendimento($REND, 2024); 1 }, 'ano trocado';
  like $@, qr/linha do ano 2025 no arquivo de 2024/, 'mensagem';

  my @l = split /\n/, path($TDI)->slurp;
  my $semcol = $dir->child('semcol.csv');
  $semcol->spew(join "\n", map { s/FUN_AF_CAT_0/XYZ/r } @l);
  ok !eval { job()->ler_distorcao("$semcol", 2025); 1 }, 'coluna faltando';
  like $@, qr/faltam colunas: FUN_AF_CAT_0/, 'diz qual';

  my $dup = $dir->child('dup.csv');
  $dup->spew(join("\n", @l[0 .. 11], $l[11], @l[12 .. $#l]));
  ok !eval { job()->ler_distorcao("$dup", 2025); 1 }, 'escola repetida';
  like $@, qr/repetida/, 'diz qual';
};

subtest 'carga: substitui os anos numa transação' => sub {
  my $dbh = InDBH->new;
  my $j = job(app => mock_app($dbh));
  my $r = $j->ler_rendimento($REND, 2025);
  my $n = $j->carregar('clean.inep_rendimento_escola', [qw(aprovacao reprovacao abandono)], $r->{linhas}, [2025]);
  is $n, 8, '8 linhas';
  like $dbh->{dos}[0][0], qr/^DELETE FROM clean\.inep_rendimento_escola WHERE ano = ANY/, 'apaga o ano antes';
  is_deeply $dbh->{dos}[0][1], [2025], 'só o ano pedido';
  like $dbh->{dos}[1][0], qr/INSERT INTO clean\.inep_rendimento_escola \(cod_inep, ano, etapa, aprovacao, reprovacao, abandono\)/, 'insere';
  is scalar(@{ $dbh->{dos}[1] }) - 1, 8 * 6, 'binds de 8 linhas × 6 colunas';

  my $falha = InDBH->new(falhar => 1);
  ok !eval { job(app => mock_app($falha))->carregar('clean.inep_distorcao_escola', ['distorcao'], [ { cod_inep => 1, ano => 2025, etapa => 'fun', distorcao => 1 } ], [2025]); 1 },
    'falha na inserção';
  like $@, qr/nada gravado/, 'propaga';
};

subtest 'a planilha é extraída do zip (o GDAL 3.6 não lê zip dentro de zip)' => sub {
  my $dir = tempdir;
  require IO::Compress::Zip;
  my $zip = $dir->child('t.zip');
  IO::Compress::Zip::zip(\'conteudo' => "$zip", Name => 'pasta/planilha.xlsx') or die;
  is job()->xlsx_no_zip("$zip"), 'pasta/planilha.xlsx', 'acha a planilha';
  my $out = job()->extrair_xlsx("$zip", $dir->child('trab')->make_path);
  is $out, $dir->child('trab', 'planilha.xlsx')->to_string, 'extraída no diretório de trabalho';
  is path($out)->slurp, 'conteudo', 'conteúdo íntegro';
};

done_testing;
