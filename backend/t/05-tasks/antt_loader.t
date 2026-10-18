use lib qw(t/lib lib);
use strict;
use warnings;
no warnings qw(once redefine);
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path);
use Mojo::JSON;
use Text::CSV;
use Encode qw(encode);
use File::Temp qw(tempdir);
use File::Spec;

# =================================================================
# Regressão do loader ANTT (#168) — acidentes em rodovias federais
# concedidas, descobertos pela API CKAN real.
#
# Não toca a rede: verifica as DECISÕES do job, que é onde os defeitos
# aparecem —
#
#   1. o dataset certo (acidentes-rodovias) e a concessionária vinda do
#      nome do recurso;
#   2. o CSV é ';' + ISO-8859-1 (o job antigo lia com separador errado);
#   3. colunas sem fonte na planilha ficam NULL, nunca 0 (#154);
#   4. o recorte por concessionária é SUBSTITUÍDO.
# =================================================================

my $JOB = 'EduMaps::Ingestion::Job::ANTT';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

# ---------------------------------------------------------------- mocks
{
  package ADBH;
  sub new { my ($c, %o) = @_; bless { dos => [], copy => [], %o }, $c }
  sub do { my ($s, $sql, $attr, @p) = @_; push @{ $s->{dos} }, [ $sql, @p ]; return 1 }
  sub pg_putcopydata { my ($s, $d) = @_; push @{ $s->{copy} }, $d; return 1 }
  sub pg_putcopyend  { my $s = shift; $s->{copy_end}++; return 1 }
  package AStorage;
  sub new { my ($c, %a) = @_; bless {%a}, $c }
  sub dbh    { $_[0]{dbh} }
  sub txn_do { my ($s, $code) = @_; $s->{txn}++; return $code->() }
  package ASchema; sub new { my ($c, %a) = @_; bless {%a}, $c } sub storage { $_[0]{storage} }
  package AApp;    sub new { my ($c, %a) = @_; bless {%a}, $c } sub schema  { $_[0]{schema} }

  package AUA;
  sub new { bless { body => $_[1] }, $_[0] }
  sub get { return bless { body => $_[0]{body} }, 'ATx' }
  package ATx;
  sub error { undef }
  sub res   { $_[0] }
  sub body  { $_[0]{body} }
}
sub mock_app {
  my ($dbh) = @_;
  return AApp->new(schema => ASchema->new(storage => AStorage->new(dbh => $dbh)));
}

# ---------------------------------------------------------------- conversores
is(job()->concessionaria_de('Demonstrativos de Acidentes - RODOVIA DO AÇO'), 'RODOVIA DO AÇO',
  'concessionária sai do nome do recurso');
is(job()->concessionaria_de('Demonstrativo de Acidentes - CRO'), 'CRO', 'aceita o singular');
is(job()->concessionaria_de('qualquer coisa'), 'qualquer coisa', 'nome sem prefixo é preservado');

is($JOB->_data_iso('01/01/2010'), '2010-01-01', 'data DD/MM/AAAA -> ISO');
is($JOB->_data_iso('2010-01-01'), '2010-01-01', 'data ISO passa');
is($JOB->_data_iso('31/13/2010'), '2010-13-31', 'data só é formatada (validação é do banco)');
is($JOB->_data_iso(''), undef, 'data vazia -> undef');
is(job()->_hora('04:21:00'), '04:21:00', 'hora HH:MM:SS');
is(job()->_hora('4:21'), '04:21:00', 'hora H:MM normalizada');
is(job()->_hora(''), undef, 'hora vazia -> undef');
is($JOB->_num('285,5'), 285.5, 'km com vírgula');
is($JOB->_num('1.234,5'), 1234.5, 'km com milhar');
is($JOB->_num('167'), 167, 'km inteiro');
is($JOB->_num(''), undef, 'km vazio -> undef');
is($JOB->_int('3'), 3, 'inteiro');
is($JOB->_int(''), undef, 'inteiro vazio -> undef');
is($JOB->_txt('  x '), 'x', 'texto sem espaços');
is($JOB->_txt('   '), undef, 'texto em branco -> undef');

# ---------------------------------------------------------------- descoberta CKAN
{
  my $json = Mojo::JSON::encode_json({
    success => Mojo::JSON::true,
    result  => { resources => [
      { format => 'PDF', name => 'Dicionário de Dados',
        url => 'https://dados.antt.gov.br/dataset/ef0171a8-f0df-4817-a4ed-b4ff94d87194/resource/aaa/download/dic.pdf' },
      { format => 'CSV', name => 'Demonstrativos de Acidentes - RODOVIA DO AÇO',
        url => 'https://dados.antt.gov.br/dataset/ef0171a8-f0df-4817-a4ed-b4ff94d87194/resource/bbb/download/demostrativo_acidentes_aco.csv' },
      { format => 'CSV', name => 'Demonstrativos de Acidentes - CRO',
        url => 'https://dados.antt.gov.br/dataset/ef0171a8-f0df-4817-a4ed-b4ff94d87194/resource/ccc/download/demostrativo_acidentes_cro.csv' },
    ] },
  });
  my $j = job(app => mock_app(ADBH->new), ua => AUA->new($json));
  my @r = $j->recursos_acidentes;
  is(scalar @r, 2, 'só os recursos CSV entram');
  is($r[0]{concessionaria}, 'RODOVIA DO AÇO', 'concessionária do 1º recurso');
  like($r[0]{url}, qr/demostrativo_acidentes_aco\.csv$/, 'URL do CSV preservada');
}

# ---------------------------------------------------------------- allowlist real
{
  use EduMaps::Data::Allowlist;
  my $al = EduMaps::Data::Allowlist->new;
  ok($al->validate_url('https://dados.antt.gov.br/api/3/action/package_show?id=acidentes-rodovias'),
    'API CKAN no allowlist') or diag $al->last_error;
  ok($al->validate_url('https://dados.antt.gov.br/dataset/ef0171a8-f0df-4817-a4ed-b4ff94d87194/resource/2d52007c-b838-4060-a94e-76cd4c51b457/download/demostrativo_acidentes_aco.csv'),
    'recurso CSV no allowlist') or diag $al->last_error;
  ok(!$al->validate_url('https://dados.antt.gov.br/dataset/outro/resource/x/download/y.csv'),
    'outro dataset da ANTT fica fora (allowlist estreita)');
}

# ---------------------------------------------------------------- processar_csv
my $CAB = join(';', qw(data horario n_da_ocorrencia tipo_de_ocorrencia km trecho sentido
  tipo_de_acidente automovel bicicleta caminhao moto onibus outros tracao_animal
  transporte_de_cargas_especiais trator_maquinas utilitarios ilesos levemente_feridos
  moderadamente_feridos gravemente_feridos mortos tipo_de_pista));

sub linha {
  my ($data, $ocor, $km, $trecho, $tipo, @v) = @_;
  my @c = ($data, '04:21:00', '18', $ocor, $km, $trecho, ' Norte', $tipo,
           @v,             # automovel..utilitarios (10)
           1, 0, 0, 0, 0,  # ilesos levemente moderadamente gravemente mortos
           'Dupla');       # tipo_de_pista
  return join(';', map { qq("$_") } @c);
}

{
  my $dir = tempdir(CLEANUP => 1);
  my $csv = File::Spec->catfile($dir, 'aco.csv');
  my $conteudo = join("\n",
    $CAB,
    linha('01/01/2010', 'sem vítima', '167', 'BR-393/RJ', 'Derrapagem', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    linha('02/01/2010', 'com vítima', '266,4', 'BR-393/RJ', 'Derrapagem', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    linha('03/01/2010', 'com vítima', '999', '', 'Atropelamento', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0),  # sem trecho: descarta
    linha('10/10/2010', 'sem vítima', '100', 'BR-101/ES', 'Colisão', ('') x 10),  # veículos vazios
  ) . "\n";
  # ISO-8859-1: "vítima" -> bytes latin1
  path($csv)->spew(encode('iso-8859-1', $conteudo));

  my $j = job(app => mock_app(ADBH->new));
  my $rows = $j->processar_csv($csv, 'RODOVIA DO AÇO');
  is(scalar @$rows, 3, 'lê 3 linhas (a sem trecho é descartada)');
  is($rows->[0]{data_acidente}, '2010-01-01', 'data convertida');
  is($rows->[0]{horario}, '04:21:00', 'hora convertida');
  is($rows->[0]{n_ocorrencia}, '18', 'número da ocorrência preservado');
  is($rows->[0]{km}, 167, 'km inteiro');
  is($rows->[1]{km}, 266.4, 'km decimal com vírgula');
  is($rows->[0]{trecho}, 'BR-393/RJ', 'trecho preservado');
  is($rows->[0]{classificacao}, 'sem vítima', 'classificação preservada (UTF-8 após ISO-8859-1)');
  is($rows->[0]{causa_provavel}, undef, '#154: causa_provavel ausente na fonte -> undef');
  is($rows->[0]{condicao_tempo}, undef, '#154: condicao_tempo ausente na fonte -> undef');
  is($rows->[0]{veiculos_envolvidos}, 1, 'soma dos veículos');
  is($rows->[1]{veiculos_envolvidos}, 0, 'zero veículos é zero real, não NULL');
  is($rows->[2]{veiculos_envolvidos}, undef, '#154: sem veículos informados -> undef (nunca 0)');

  # cabeçalho fora do contrato -> arquivo pulado, sem morrer
  my $ruim = File::Spec->catfile($dir, 'ruim.csv');
  path($ruim)->spew("coluna_errada;outra\n1;2\n");
  my $r = $j->processar_csv($ruim, 'X');
  is(scalar @$r, 0, 'CSV fora do contrato é pulado (não derruba a carga)');
}

# ---------------------------------------------------------------- carregar
{
  my $dbh = ADBH->new;
  my $j = job(app => mock_app($dbh));
  my @rows = (
    { concessionaria => 'RODOVIA DO AÇO', data_acidente => '2010-01-01', horario => '04:21:00',
      n_ocorrencia => '18', km => 167,
      trecho => 'BR-393/RJ', tipo_acidente => 'Derrapagem', classificacao => 'sem vítima',
      causa_provavel => undef, condicao_tempo => undef, pista => 'Dupla',
      mortos => 0, feridos_graves => 0, feridos_leves => 0, ilesos => 1, veiculos_envolvidos => 1 },
  );
  my $n = $j->carregar(\@rows, ['RODOVIA DO AÇO']);
  is($n, 1, 'carrega 1 linha');
  my ($del) = grep { $_->[0] =~ /^DELETE FROM clean\.antt_acidente_trecho/ } @{ $dbh->{dos} };
  ok($del, 'faz DELETE do recorte');
  like($del->[0], qr/concessionaria = ANY/, 'DELETE por concessionária');
  is_deeply($del->[1], ['RODOVIA DO AÇO'], 'concessionária passada como parâmetro');
  my ($copy) = grep { $_->[0] =~ /^COPY clean\.antt_acidente_trecho/ } @{ $dbh->{dos} };
  ok($copy, 'usa COPY, não INSERT em lotes (1 M linhas não cabem no watchdog)');
  like($copy->[0], qr/FROM STDIN WITH \(FORMAT csv\)/, 'COPY ... FORMAT csv');
  is(scalar @{ $dbh->{copy} }, 1, 'uma linha enviada ao COPY');
  like($dbh->{copy}[0], qr/^"RODOVIA DO AÇO","2010-01-01","04:21:00","18","167","BR-393\/RJ"/,
    'campos citados na ordem do COPY');
  ok($dbh->{copy_end}, 'fecha o COPY (pg_putcopyend)');
}

# ---------------------------------------------------------------- campo CSV do COPY
is(EduMaps::Ingestion::Job::ANTT::_csv_campo(undef), '', 'undef -> campo vazio (NULL no COPY csv)');
is(EduMaps::Ingestion::Job::ANTT::_csv_campo('a,b'), '"a,b"', 'vírgula protegida');
is(EduMaps::Ingestion::Job::ANTT::_csv_campo('a"b'), '"a""b"', 'aspas escapadas');
is(EduMaps::Ingestion::Job::ANTT::_csv_campo("a\x00b"), '"ab"', 'NUL removido (Postgres recusa 0x00)');

# ---------------------------------------------------------------- dedupe
{
  my $j = job();
  my @r = (
    { concessionaria => 'X', data_acidente => '2024-01-01', horario => '03:01:06', n_ocorrencia => '6', km => 1 },
    { concessionaria => 'X', data_acidente => '2024-01-01', horario => '03:01:06', n_ocorrencia => '6', km => 1 },
    { concessionaria => 'X', data_acidente => '2024-01-01', horario => '03:01:06', n_ocorrencia => '7', km => 2 },
  );
  my ($unicas, $dups) = $j->_dedupe(\@r);
  is(scalar @$unicas, 2, 'desduplica pela chave do evento (a fonte repete por sentido)');
  is($dups, 1, 'conta o duplicado descartado');
}

# ---------------------------------------------------------------- aspas soltas (regressão)
{
  my $dir = tempdir(CLEANUP => 1);
  my $csv = File::Spec->catfile($dir, 'loose.csv');
  path($csv)->spew(join("\n",
    $CAB,
    '01/01/2010;"04:21:00";"18";"sem vítima";"167";"BR-393/RJ";" Norte";"Derrapagem";1;0;0;0;0;0;0;0;0;0;1;0;0;0;0;"Dupla"',
    '02/01/2010;"05:00:00";"19";"sem vítima";3"4;"BR-393/RJ";" Norte";"Derrapagem";0;0;0;0;0;0;0;0;0;0;1;0;0;0;0;"Dupla"',
    '03/01/2010;"06:00:00";"20";"sem vítima";"169";"BR-393/RJ";" Norte";"Choque";0;0;0;0;0;0;0;0;0;0;1;0;0;0;0;"Dupla"',
  ) . "\n");
  my $rows = job(app => mock_app(ADBH->new))->processar_csv($csv, 'X');
  is(scalar @$rows, 3,
    'aspas soltas não truncam o arquivo (allow_loose_quotes; sem isso 3 linhas viravam 1)');
}

done_testing;