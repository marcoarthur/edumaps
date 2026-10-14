use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);
use IO::Compress::Zip qw(zip $ZipError);
use Text::CSV;
use Mojo::File;

# =================================================================
# Loader CGU — transferências de educação por município (#238)
#
# Não baixa nada. Verifica as decisões que o loader TOMA:
#   1. só função 12 (Educação) entra;
#   2. prefeitura: município pelo CNPJ (SICONFI /entes) e, se o CNPJ não
#      for o da prefeitura, pelo SIAFI;
#   3. PDDE às UEx: município pelo de-para SIAFI -> IBGE DERIVADO das
#      linhas de prefeitura (inclusive de outro mês) e, quando não há SIAFI,
#      pelo CNPJ da própria UEx (#240);
#   4. o que não resolve vai para órfãos com motivo — não some;
#   5. programa por ação, com fallback ACAO_<código>;
#   6. soma por município × programa × mês, datas do mês, vírgula decimal;
#   7. ZIP truncado é detectado e rebaixado, não carregado.
# =================================================================

my $JOB = 'EduMaps::Ingestion::Job::CGU';
require_ok($JOB);

# Dublê do provedor CNPJ -> município (sem rede). Por omissão devolve
# nao_encontrado para tudo; um mapa injetado resolve os CNPJs listados.
{
  package MockCnpjProvider;
  sub new { my ($c, %o) = @_; bless { mapa => $o{mapa} // {}, pedidos => [] }, $c }
  sub pedidos { $_[0]{pedidos} }
  sub municipio_por_cnpj {
    my ($self, $cnpjs) = @_;
    push @{ $self->{pedidos} }, @$cnpjs;
    my %r;
    for my $c (@$cnpjs) {
      my $m = $self->{mapa}{$c};
      $r{$c} = $m ? { %$m } : { nao_encontrado => 1 };
    }
    return \%r;
  }
}

my $LOG = Mojo::Log->new(level => 'fatal');

sub job {
  my %o = @_;
  my $tmp = tempdir(CLEANUP => 1);
  my $mapa = delete $o{cnpj_mapa} // {};
  return $JOB->new(
    log => $LOG,
    config => { dir_trabalho => $tmp, raw_dir => "$tmp/raw" },
    entes => \@ENTES::LISTA,
    cnpj_provider => MockCnpjProvider->new(mapa => $mapa),
    max_retries => 0, backoff_base => 0,
    %o,
  );
}

@ENTES::LISTA = (
  { cod_ibge => 1200013, ente => 'Acrelândia', cnpj => '84306737000127', esfera => 'M' },
  { cod_ibge => 3550308, ente => 'São Paulo',  cnpj => '46395000000139', esfera => 'M' },
  { cod_ibge => 5208707, ente => 'Goiânia',    cnpj => '01612092000123', esfera => 'M' },
);

my @HEADER = ('ANO / MÊS', 'TIPO TRANSFERÊNCIA', 'TIPO FAVORECIDO', 'UF',
  'CÓDIGO MUNICÍPIO SIAFI', 'NOME MUNICÍPIO', 'CÓDIGO FUNÇÃO', 'NOME FUNÇÃO',
  'AÇÃO', 'NOME AÇÃO', 'CÓDIGO FAVORECIDO', 'NOME FAVORECIDO', 'VALOR TRANSFERIDO');

my $MUN = 'Administração Pública Municipal';
my $UEX = 'Entidades Sem Fins Lucrativos';
my $EST = 'Administração Pública Estadual ou do Distrito Federal';

# [ano_mes, tipo, uf, siafi, funcao, acao, cnpj, favorecido, valor]
sub linha {
  my ($am, $tipo, $uf, $siafi, $funcao, $acao, $cnpj, $fav, $valor) = @_;
  return [$am, 'Legais', $tipo, $uf, $siafi, '', $funcao, '', $acao, "AÇÃO $acao", $cnpj, $fav, $valor];
}

# Escreve o CSV em latin1, ';' — como o arquivo oficial.
sub csv_fixture {
  my ($dir, $nome, @linhas) = @_;
  my $path = "$dir/$nome";
  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', eol => "\r\n", always_quote => 1 });
  open my $fh, '>:encoding(latin1)', $path or die $!;
  $csv->print($fh, \@HEADER);
  $csv->print($fh, $_) for @linhas;
  close $fh;
  return $path;
}

my $D = tempdir(CLEANUP => 1);

# Janeiro: FUNDEB (00SB) a Acrelândia em duas linhas (com estorno), PNATE a
# SP, ação desconhecida, linha de saúde (função 10) e PDDE a uma UEx de
# Goiânia cujo SIAFI só aparece numa linha de prefeitura de FEVEREIRO.
my $jan = csv_fixture($D, '202501.csv',
  linha('202501', $MUN, 'AC', '0643', '12', '00SB', '84306737000127', 'MUNICIPIO DE ACRELANDIA', '1000,50'),
  linha('202501', $MUN, 'AC', '0643', '12', '00SB', '84306737000127', 'MUNICIPIO DE ACRELANDIA', '-0,50'),
  linha('202501', $MUN, 'SP', '7107', '12', '0969', '46395000000139', 'MUNICIPIO DE SAO PAULO', '2500,00'),
  linha('202501', $MUN, 'SP', '7107', '12', '9ZZZ', '46395000000139', 'MUNICIPIO DE SAO PAULO', '10,00'),
  linha('202501', $MUN, 'SP', '7107', '10', '8585', '46395000000139', 'MUNICIPIO DE SAO PAULO', '99999,99'),
  linha('202501', $UEX, 'GO', '9373', '12', '0515', '11111111000111', 'APM ESCOLA X', '300,25'),
  # PDDE sem SIAFI (órfão) e PDDE com SIAFI que nenhuma prefeitura usa (órfão)
  linha('202501', $UEX, 'RS', '',     '12', '0515', '22222222000122', 'CPM ESCOLA Y', '50,00'),
  linha('202501', $UEX, 'RS', '8888', '12', '0515', '33333333000133', 'CPM ESCOLA Z', '70,00'),
  # Estado e entidade fora do PDDE: fora do escopo
  linha('202501', $EST, 'AC', '',     '12', '00SB', '63606479000124', 'ESTADO DO ACRE', '5000,00'),
  linha('202501', $UEX, 'SP', '7107', '12', '20RK', '44444444000144', 'ASSOCIACAO W', '900,00'),
  # Prefeitura com CNPJ desconhecido e SIAFI desconhecido: órfão
  linha('202501', $MUN, 'PA', '0999', '12', '0969', '55555555000155', 'MUNICIPIO DESCONHECIDO', '12,00'),
);

# Fevereiro: o SIAFI 9373 aparece numa linha de prefeitura (função 04) com o
# CNPJ de Goiânia — é daqui que o PDDE de janeiro tira o município. E um
# fundo municipal de SP (CNPJ próprio) resolve pelo SIAFI 7107.
my $fev = csv_fixture($D, '202502.csv',
  linha('202502', $MUN, 'GO', '9373', '04', '2000', '01612092000123', 'MUNICIPIO DE GOIANIA', '1,00'),
  linha('202502', $MUN, 'SP', '7107', '12', '00SB', '99999999000199', 'FUNDO MUNICIPAL DE EDUCACAO', '400,00'),
  linha('202502', $MUN, 'AC', '0643', '12', '0E53', '84306737000127', 'MUNICIPIO DE ACRELANDIA', '75,10'),
);

subtest 'ler_csv: função 12, vírgula decimal, de-para SIAFI de qualquer função' => sub {
  my $l = job()->ler_csv($jan);
  is($l->{linhas}, 11, 'todas as linhas lidas');
  is(scalar @{ $l->{educ} }, 10, 'a linha de saúde (função 10) não entra');
  ok(!(grep { $_->{acao} eq '8585' } @{ $l->{educ} }), 'ação de saúde fora');
  my ($estorno) = grep { $_->{valor} < 0 } @{ $l->{educ} };
  is($estorno->{valor}, -0.5, 'estorno negativo com vírgula decimal');
  my ($pnate) = grep { $_->{acao} eq '0969' && $_->{uf} eq 'SP' } @{ $l->{educ} };
  is($pnate->{valor}, 2500, '"2500,00" -> 2500');
  is($l->{siafi_cnpj}{7107}{'46395000000139'}, 3, 'prefeitura de SP vista 3x (inclusive função 10)');
  ok(!exists $l->{siafi_cnpj}{9373}, 'UEx não alimenta o de-para SIAFI');
  is(job()->ler_csv($fev)->{siafi_cnpj}{9373}{'01612092000123'}, 1, 'fevereiro: SIAFI de Goiânia pela prefeitura');
};

subtest 'ler_csv: coluna obrigatória ausente aborta' => sub {
  my $p = "$D/sem_coluna.csv";
  open my $fh, '>:encoding(latin1)', $p or die $!;
  print $fh qq{"ANO / MÊS";"UF"\r\n"202501";"AC"\r\n};
  close $fh;
  eval { job()->ler_csv($p) };
  like($@, qr/colunas obrigatórias ausentes.*CÓDIGO FUNÇÃO/s, 'nomeia a coluna que falta');
};

my $j = job();
my $res = $j->resolver([ $j->ler_csv($jan), $j->ler_csv($fev) ], \@ENTES::LISTA);
my %L = map { join('|', @{$_}{qw(codigo_ibge programa data_inicio)}) => $_ } @{ $res->{linhas} };

subtest 'resolver: CNPJ da prefeitura, SIAFI derivado e PDDE às UEx' => sub {
  ok($L{'1200013|FUNDEB|2025-01-01'}, 'FUNDEB de Acrelândia pelo CNPJ');
  is($L{'1200013|FUNDEB|2025-01-01'}{valor_transferido}, 1000, 'duas linhas no mês somam (1000,50 - 0,50)');
  is($L{'1200013|FUNDEB|2025-01-01'}{nome_municipio}, 'Acrelândia', 'nome do município do /entes');
  is($L{'3550308|FUNDEB|2025-02-01'}{valor_transferido}, 400,
     'fundo municipal (CNPJ próprio) resolve pelo SIAFI da prefeitura');
  is($L{'5208707|PDDE|2025-01-01'}{valor_transferido}, 300.25,
     'PDDE de janeiro à UEx -> Goiânia pelo SIAFI visto na prefeitura em fevereiro');
  is($res->{ibge_por_siafi}{9373}, '5208707', 'de-para derivado 9373 -> Goiânia');
  is($res->{estatisticas}{municipios}, 3, '3 municípios');
};

subtest 'resolver: programa por ação, fallback ACAO_<código>' => sub {
  ok($L{'3550308|PNATE|2025-01-01'}, '0969 -> PNATE');
  ok($L{'1200013|CAMINHO_DA_ESCOLA|2025-02-01'}, '0E53 -> CAMINHO_DA_ESCOLA');
  ok($L{'3550308|ACAO_9ZZZ|2025-01-01'}, 'ação desconhecida não é descartada');
  is(job()->programa_da_acao('12KU'), 'PROINFANCIA', '12KU -> PROINFANCIA');
  is(job()->programa_da_acao('20RP'), 'INFRAESTRUTURA_EDUC_BASICA', 'ação 20RP');
  is(job()->programa_da_acao('0509'), 'APOIO_EDUC_BASICA', 'ação 0509');
  # medidas na carga de 2025 (#238): caíam no fallback
  is(job()->programa_da_acao('00PI'), 'PNAE', '00PI -> PNAE (alimentação escolar)');
  is(job()->programa_da_acao('00OW'), 'MANUTENCAO_EDUC_INFANTIL', '00OW -> manutenção da ed. infantil');
  is(job()->programa_da_acao('00SU'), 'PROINFANCIA', '00SU -> PROINFANCIA');
};

subtest 'resolver: período do mês' => sub {
  my $f = $L{'3550308|FUNDEB|2025-02-01'};
  is($f->{data_inicio}, '2025-02-01', 'início do mês');
  is($f->{data_fim}, '2025-02-28', 'fim de fevereiro de 2025');
  is((EduMaps::Ingestion::Job::CGU::_periodo('202412'))[1], '2024-12-31', 'dezembro');
  is((EduMaps::Ingestion::Job::CGU::_periodo('202402'))[1], '2024-02-29', 'fevereiro bissexto');
};

subtest 'resolver: órfãos nomeados, fora do escopo contado' => sub {
  my %m;
  $m{ $_->{motivo} } += $_->{linhas} for @{ $res->{orfaos} };
  is($m{pdde_sem_siafi}, 1, 'PDDE sem SIAFI');
  is($m{pdde_siafi_sem_correspondencia}, 1, 'PDDE com SIAFI sem prefeitura');
  is($m{municipio_nao_resolvido}, 1, 'prefeitura com CNPJ e SIAFI desconhecidos');
  is($res->{estatisticas}{orfaos_linhas}, 3, '3 linhas órfãs');
  is(sprintf('%.2f', $res->{estatisticas}{orfaos_valor}), '132.00', 'valor órfão somado');
  is($res->{estatisticas}{fora_do_escopo}, 2, 'estado + entidade fora do PDDE');
  ok(!(grep { $_->{programa} eq 'ACAO_20RK' } @{ $res->{linhas} }), 'entidade fora do PDDE não entra');

  my $jj = job();
  is($jj->registrar_orfaos($res->{orfaos}), 3, 'relatório conta as linhas');
  my $arq = $jj->dir_trabalho . '/cgu_orfaos.csv';
  ok(-f $arq, 'cgu_orfaos.csv escrito');
  open my $fh, '<:encoding(utf8)', $arq or die $!;
  my @l = <$fh>;
  like($l[0], qr/^motivo,uf,siafi,cnpj,acao,favorecido,linhas,valor/, 'cabeçalho');
  is(scalar @l, 4, 'um grupo por órfão');
};

# --- ZIP íntegro x truncado ------------------------------------------
my $zip_ok = "$D/ok.zip";
zip $jan => $zip_ok, Name => '202501_Transferencias.csv' or die $ZipError;
my $zip_trunc = "$D/trunc.zip";
{
  open my $in, '<:raw', $zip_ok or die $!;
  local $/; my $b = <$in>; close $in;
  open my $out, '>:raw', $zip_trunc or die $!;
  print $out substr($b, 0, int(length($b) / 2));
  close $out;
}

subtest 'zip_integro: truncado é detectado' => sub {
  ok(job()->zip_integro($zip_ok), 'ZIP inteiro passa');
  ok(!job()->zip_integro($zip_trunc), 'ZIP cortado a meio falha');
  ok(!job()->zip_integro("$D/nao_existe.zip"), 'ausente falha');
};

subtest 'obter_csv: ZIP truncado é rebaixado, não carregado' => sub {
  my $jj = job();
  my @entregas = ($zip_trunc, $zip_ok);
  my $chamadas = 0;
  no warnings 'redefine';
  local *EduMaps::Ingestion::Job::CGU::download_file = sub {
    my ($self, $url) = @_;
    $chamadas++;
    my $src = shift @entregas;
    Mojo::File::path($self->dir_trabalho)->make_path;
    my $dst = $self->dir_trabalho . "/dl_$chamadas.zip";
    File::Copy::copy($src, $dst) or die $!;
    return $dst;
  };
  require File::Copy;
  my $csv = $jj->obter_csv('202501');
  is($chamadas, 2, 'baixou de novo depois do truncado');
  like($csv, qr/202501_Transferencias\.csv$/, 'extraiu o CSV do ZIP bom');
  is(scalar @{ $jj->ler_csv($csv)->{educ} }, 10, 'CSV extraído é legível');

  my $jjj = job(tentativas_zip => 2);
  @entregas = ($zip_trunc, $zip_trunc);
  $chamadas = 0;
  eval { $jjj->obter_csv('202501') };
  like($@, qr/corrompido após 2 tentativas/, 'desiste alto depois das tentativas');
};

# --- Carga ------------------------------------------------------------
{
  package MockDBH;
  sub new { my ($c, %o) = @_; bless { exec => [], dos => [], commits => 0, rolled => 0, %o }, $c }
  sub begin_work { 1 }
  sub commit { $_[0]{commits}++; 1 }
  sub rollback { $_[0]{rolled}++; 1 }
  sub prepare { my ($s, $sql) = @_; $s->{sql} = $sql; bless { dbh => $s }, 'MockSTH' }
  sub do { my ($s, $sql, undef, @p) = @_; push @{ $s->{dos} }, [$sql, @p]; 1 }
  package MockSTH;
  sub execute {
    my ($s, @p) = @_;
    die "boom: violação\n" if $s->{dbh}{falhar} && @{ $s->{dbh}{exec} } >= 1;
    push @{ $s->{dbh}{exec} }, \@p; 1
  }
  package MockStorage; sub new { bless { dbh => $_[1] }, $_[0] } sub dbh { $_[0]{dbh} }
  package MockSchema;  sub new { bless { st => $_[1] }, $_[0] } sub storage { $_[0]{st} }
  package MockApp;     sub new { bless { sc => $_[1] }, $_[0] } sub schema { $_[0]{sc} }
}
sub mock_app { my $dbh = shift; MockApp->new(MockSchema->new(MockStorage->new($dbh))) }

subtest 'carregar: upsert na PK, dt_snapshot, rollback preserva o erro' => sub {
  my $dbh = MockDBH->new;
  my $jj = job(app => mock_app($dbh));
  my $n = $jj->carregar($res->{linhas}, '2026-10-13');
  is($n, scalar @{ $res->{linhas} }, 'todas as linhas');
  like($dbh->{sql}, qr/ON CONFLICT \(codigo_ibge, programa, data_inicio, data_fim, dt_snapshot\)/, 'conflito na PK exata');
  is($dbh->{exec}[0][-1], '2026-10-13', 'dt_snapshot no último parâmetro');
  is($dbh->{commits}, 1, 'um commit');
  my ($del) = grep { $_->[0] =~ /DELETE FROM clean\.transferencia_educ/ } @{ $dbh->{dos} };
  ok($del, 'o snapshot do período é substituído (sem chave antiga em dobro)');
  is_deeply([ @{$del}[1 .. 3] ], ['2026-10-13', '2025-01-01', '2025-02-28'],
    'DELETE por dt_snapshot e pelo intervalo dos meses carregados');

  my $ruim = MockDBH->new(falhar => 1);
  eval { job(app => mock_app($ruim))->carregar($res->{linhas}, '2026-10-13') };
  like($@, qr/nada gravado: boom: violação/, 'erro original sobrevive ao rollback');
  is($ruim->{rolled}, 1, 'rollback');
};

subtest 'run: ponta a ponta com meses, metadata e órfãos' => sub {
  my $dbh = MockDBH->new;
  my $jj = job(app => mock_app($dbh));
  my %csv = ('202501' => $jan, '202502' => $fev);
  my @pedidos;
  no warnings qw(redefine once);
  local *EduMaps::Ingestion::Job::CGU::obter_csv = sub { push @pedidos, $_[1]; $csv{ $_[1] } };
  my $n = $jj->run({ ano => 2025, meses => '1,2' });
  is_deeply(\@pedidos, ['202501', '202502'], 'um ZIP por mês pedido');
  is($n, scalar @{ $res->{linhas} }, 'linhas carregadas');
  my ($meta) = grep { $_->[0] =~ /import_metadata/ } @{ $dbh->{dos} };
  ok($meta, 'upsert_metadata gravado');
  is($meta->[1], 'clean.transferencia_educ', 'na tabela certa');
  is($meta->[4], 'CC-BY-4.0 (CGU)', 'licença CGU');
  like($meta->[6], qr/3 municípios.*Órfãos: 3 linhas/s, 'nota com municípios e órfãos');
  ok(-f $jj->dir_trabalho . '/cgu_orfaos.csv', 'relatório de órfãos');
  is_deeply([ $jj->tabelas ], ['clean.transferencia_educ'], 'tabelas()');
};

subtest 'run: mês inválido e ano inválido abortam' => sub {
  eval { job()->run({ ano => 2025, meses => '13' }) };
  like($@, qr/mês inválido: 13/, 'mês 13');
  eval { job()->run({ ano => 'abc' }) };
  like($@, qr/ano inválido/, 'ano');
};

subtest 'dry-run: só HEAD do primeiro ZIP, nada baixado nem gravado' => sub {
  {
    package MockHeadRes; sub new { bless {}, shift } sub code { 200 }
    sub headers { bless {}, 'MockHeaders' }
    package MockHeaders; sub content_length { 2556931 }
    package MockHeadTx; sub new { bless {}, shift } sub error { undef } sub result { MockHeadRes->new }
    package MockHeadUA; sub new { bless { calls => [] }, shift }
    sub head { push @{ $_[0]{calls} }, $_[1]; MockHeadTx->new }
    sub get  { die "dry-run não pode fazer GET\n" }
  }
  my $ua = MockHeadUA->new;
  my $jj = job(dry_run => 1, ua => $ua, entes => sub { die "dry-run não busca /entes\n" });
  no warnings 'redefine';
  local *EduMaps::Ingestion::Job::CGU::download_file = sub { die "dry-run não baixa\n" };
  is($jj->run({ ano => 2025 }), 0, 'devolve 0');
  is(scalar @{ $ua->{calls} }, 1, 'uma requisição de sanidade');
  like($ua->{calls}[0], qr{/202501_Transferencias\.zip$}, 'HEAD do primeiro mês');
};

subtest 'resolver: UEx pelo CNPJ quando não há SIAFI (e o DF, fora do /entes)' => sub {
  my $jj = job();
  my $mapa = {
    '22222222000122' => { codigo_ibge => '4314902', municipio => 'PORTO ALEGRE',   uf => 'RS', fonte => 'brasilapi' },
    '33333333000133' => { codigo_ibge => '5300108', municipio => 'BRASILIA',      uf => 'DF', fonte => 'brasilapi' },
  };
  my $r = $jj->resolver([ $jj->ler_csv($jan), $jj->ler_csv($fev) ], \@ENTES::LISTA, $mapa);
  my %L = map { join('|', @{$_}{qw(codigo_ibge programa data_inicio)}) => $_ } @{ $r->{linhas} };

  is($L{'4314902|PDDE|2025-01-01'}{valor_transferido}, 50,
     'PDDE da UEx sem SIAFI resolve pelo CNPJ da própria UEx');
  is($L{'4314902|PDDE|2025-01-01'}{nome_municipio}, 'PORTO ALEGRE',
     'nome vem da fonte do CNPJ (não do /entes)');
  is($L{'5300108|PDDE|2025-01-01'}{valor_transferido}, 70,
     'SIAFI sem correspondência cai no CNPJ (DF ausente do /entes)');
  is($r->{estatisticas}{uex_cnpj_resolvidos}, 2, 'duas UEx resolvidas por CNPJ');

  my %m;
  $m{ $_->{motivo} } += $_->{linhas} for @{ $r->{orfaos} };
  is($m{pdde_sem_siafi} // 0, 0, 'sem órfão pdde_sem_siafi');
  is($m{pdde_siafi_sem_correspondencia} // 0, 0, 'sem órfão pdde_siafi_sem_correspondencia');
  is($m{municipio_nao_resolvido}, 1, 'só o município desconhecido segue órfão');
};

subtest 'resolver: CNPJ consultado e não encontrado é motivo próprio' => sub {
  my $jj = job();
  my $r = $jj->resolver([ $jj->ler_csv($jan) ], \@ENTES::LISTA,
    { '22222222000122' => { nao_encontrado => 1 } });
  my %m;
  $m{ $_->{motivo} } += $_->{linhas} for @{ $r->{orfaos} };
  is($m{pdde_cnpj_nao_resolvido}, 1, 'UEx sem SIAFI cujo CNPJ não resolve');
};

subtest 'run: UEx do PDDE resolvidas por CNPJ ponta a ponta' => sub {
  my $dbh = MockDBH->new;
  my $jj = job(app => mock_app($dbh), cnpj_mapa => {
    '22222222000122' => { codigo_ibge => '4314902', municipio => 'PORTO ALEGRE', uf => 'RS', fonte => 'brasilapi' },
    '33333333000133' => { codigo_ibge => '4302105', municipio => 'BENTO GONCALVES', uf => 'RS', fonte => 'brasilapi' },
  });
  my %csv = ('202501' => $jan, '202502' => $fev);
  no warnings qw(redefine once);
  local *EduMaps::Ingestion::Job::CGU::obter_csv = sub { $csv{ $_[1] } };
  my $n = $jj->run({ ano => 2025, meses => '1,2' });

  my @ibges = map { $_->[0] } @{ $dbh->{exec} };
  ok((grep { $_ eq '4314902' } @ibges), 'PDDE da UEx sem SIAFI carregado no município do CNPJ');
  ok((grep { $_ eq '4302105' } @ibges), 'PDDE com SIAFI desconhecido carregado no município do CNPJ');
  my ($meta) = grep { $_->[0] =~ /import_metadata/ } @{ $dbh->{dos} };
  like($meta->[6], qr/2\/2 CNPJs resolvidos/, 'nota declara as UEx resolvidas por CNPJ (só quem precisa)');
};

subtest 'otimização: UEx com SIAFI mapeado não consulta o CNPJ' => sub {
  my $prov = MockCnpjProvider->new;
  my $jj = job(cnpj_provider => $prov);
  my $leituras = [ $jj->ler_csv($jan), $jj->ler_csv($fev) ];
  my $siafi = $jj->_mapa_siafi($leituras, \@ENTES::LISTA);
  my $mapa  = $jj->_mapa_cnpj_uex($leituras, $siafi->{ibge_por_siafi});

  my %ped = map { $_ => 1 } @{ $prov->pedidos };
  ok($ped{'22222222000122'}, 'UEx sem SIAFI é consultada');
  ok($ped{'33333333000133'}, 'UEx com SIAFI sem correspondência é consultada');
  ok(!$ped{'11111111000111'}, 'UEx cujo SIAFI mapeia (9373, visto na prefeitura em fev) NÃO é consultada');
  is(scalar keys %$mapa, 2, 'candidatos ficam só com as UEx que precisam do CNPJ');
};

done_testing();
