use lib qw(t/lib lib);
use strict;
use warnings;
no warnings 'once';
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path tempdir);

# =====================================================================
# Job CNES (#241): estabelecimentos ATIVOS, SANITIZADOS ->
# clean.cnes_estabelecimentos. Shape = o medido na API em 2026-10-13.
#  1. paginação de 20 por UF até a página curta/vazia; status=1;
#  2. NENHUM PII chega às linhas do banco NEM ao bruto em disco;
#  3. codigo_municipio de 6 dígitos -> 7 da malha; sem casa -> órfão;
#  4. coordenada ausente/zero/fora do Brasil -> NULL (o par);
#  5. uf=XX roda um subconjunto; jsonl=<bruto> recarrega sem API;
#  6. uma transação por UF: falha tardia não desfaz UFs anteriores;
#  7. dry-run: uma página, nada gravado.
# =====================================================================

my $JOB = 'EduMaps::Ingestion::Job::CNES';
require_ok($JOB);

{
  package MockRes;
  sub new { my ($c, $json, $code) = @_; bless { json => $json, code => $code // 200 }, $c }
  sub code { $_[0]{code} }
  sub json { $_[0]{json} }
  package MockTx;
  sub new { my ($c, $res) = @_; bless { res => $res }, $c }
  sub res { $_[0]{res} }
  package MockUA;
  sub new { my ($c, $h) = @_; bless { handler => $h, calls => [] }, $c }
  sub get {
    my ($self, $url, %a) = @_;
    my $form = $a{form} // {};
    push @{ $self->{calls} }, [ $url, { %$form } ];
    my @r = $self->{handler}->($url, $form);
    return MockTx->new(MockRes->new($r[0], $r[1]));
  }
  package MockSTH;
  sub execute {
    my ($s, @p) = @_;
    die "boom: falha na UF\n" if $s->{dbh}{falhar_cnes} && $s->{dbh}{falhar_cnes} == $p[0];
    push @{ $s->{dbh}{pendentes} }, \@p; 1
  }
  package MockDBH;
  sub new { my ($c, %o) = @_; bless { inserts => [], pendentes => [], dos => [], prepared => [], txns => 0, %o }, $c }
  sub prepare { my ($s, $sql) = @_; push @{ $s->{prepared} }, $sql; bless { dbh => $s }, 'MockSTH' }
  sub do { my ($s, $sql, @p) = @_; push @{ $s->{dos} }, [ $sql, @p ]; 1 }
  sub selectcol_arrayref { [ @{ $_[0]{malha} // [] } ] }
  sub selectrow_array { my $s = shift; return (scalar @{ $s->{inserts} }) }
  package MockStorage;
  sub new { my ($c, %a) = @_; bless { %a }, $c }
  sub dbh { $_[0]{dbh} }
  # transação de mentira: só "comita" (move para inserts) se o bloco não morrer
  sub txn_do {
    my ($s, $cb) = @_;
    my $d = $s->{dbh};
    $d->{pendentes} = [];
    $cb->();
    $d->{txns}++;
    push @{ $d->{inserts} }, @{ $d->{pendentes} };
    $d->{pendentes} = [];
    return 1;
  }
  package MockSchema; sub new { my ($c, %a) = @_; bless { %a }, $c } sub storage { $_[0]{storage} }
  package MockApp;    sub new { my ($c, %a) = @_; bless { %a }, $c } sub schema { $_[0]{schema} }
  package MockAllow;
  sub new { bless {}, shift } sub validate_url { 1 } sub last_error { '' }
  sub get_license_for_url { 'CC BY-ND 3.0 (dados abertos SUS)' }
}

# Registro como a API devolve: com TODO o PII.
my @PII_VALORES = ('CLINICA SECRETA LTDA', 'NOME FANTASIA X', '12345678000199', '98765432000155',
                   '(68) 99999-0000', 'fulano@exemplo.com', 'RUA DAS FLORES', 'BAIRRO CENTRO', '69900000');
sub est {
  my (%p) = @_;
  return {
    codigo_cnes => $p{cnes} // 1234567,
    codigo_municipio => exists $p{mun} ? $p{mun} : 120004,
    codigo_uf => $p{uf} // 12,
    codigo_tipo_unidade => exists $p{tipo} ? $p{tipo} : 2,
    latitude_estabelecimento_decimo_grau => exists $p{lat} ? $p{lat} : -9.97,
    longitude_estabelecimento_decimo_grau => exists $p{lon} ? $p{lon} : -67.81,
    data_atualizacao => '2025-09-03',
    nome_razao_social => $PII_VALORES[0], nome_fantasia => $PII_VALORES[1],
    numero_cnpj => $PII_VALORES[2], numero_cnpj_entidade => $PII_VALORES[3],
    numero_telefone_estabelecimento => $PII_VALORES[4], endereco_email_estabelecimento => $PII_VALORES[5],
    endereco_estabelecimento => $PII_VALORES[6], numero_estabelecimento => '123',
    bairro_estabelecimento => $PII_VALORES[7], codigo_cep_estabelecimento => $PII_VALORES[8],
  };
}

my @PII_CHAVES = qw(nome_razao_social nome_fantasia numero_cnpj numero_cnpj_entidade
                    numero_telefone_estabelecimento endereco_email_estabelecimento
                    endereco_estabelecimento numero_estabelecimento bairro_estabelecimento
                    codigo_cep_estabelecimento);

my $MALHA = [qw(1200013 1200040 1200054 3550308)];

# handler por UF: { uf => [registros] }, paginado em 20 (pagina=2 nos testes)
sub paginador {
  my ($dados) = @_;
  return sub {
    my ($url, $f) = @_;
    my $todos = $dados->{ $f->{codigo_uf} } // [];
    return ({ estabelecimentos => [ grep { defined } @$todos[ $f->{offset} .. $f->{offset} + $f->{limit} - 1 ] ] });
  };
}

sub mk_job {
  my ($handler, %extra) = @_;
  my $dbh = MockDBH->new(malha => $MALHA, %{ delete $extra{dbh_opts} // {} });
  my $tmp = tempdir;
  my $job = $JOB->new(
    log       => Mojo::Log->new(level => 'fatal'),
    ua        => MockUA->new($handler // sub { return ({ estabelecimentos => [] }) }),
    allowlist => MockAllow->new,
    app       => MockApp->new(schema => MockSchema->new(storage => MockStorage->new(dbh => $dbh))),
    throttle  => 0, max_retries => 0, pagina => 2,
    config    => { dir_trabalho => "$tmp/trab", raw_dir => "$tmp/raw" },
    %extra,
  );
  return ($job, $dbh, $tmp);
}

subtest 'paginação: 20 (aqui 2) por página até a vazia, status=1, por UF' => sub {
  my ($j) = mk_job(paginador({ 12 => [ est(cnes => 1), est(cnes => 2), est(cnes => 3), est(cnes => 4) ] }));
  my $r = $j->baixar_uf(12);
  is(scalar @$r, 4, 'quatro registros');
  is_deeply([ map { $_->[1]{offset} } @{ $j->ua->{calls} } ], [0, 2, 4], 'página cheia segue; a vazia encerra');
  is($j->ua->{calls}[0][1]{status}, 1, 'só ativos (status=1)');
  is($j->ua->{calls}[0][1]{codigo_uf}, 12, 'filtro por UF');
  like($j->ua->{calls}[0][0], qr{/cnes/estabelecimentos$}, 'recurso certo');
};

subtest 'sanitização: lista branca, PII nunca sobrevive' => sub {
  my $s = EduMaps::Ingestion::Job::CNES::sanitizar(est());
  ok(!exists $s->{$_}, "sem $_") for @PII_CHAVES;
  is_deeply([ sort keys %$s ], [ sort(@EduMaps::Ingestion::Job::CNES::CAMPOS_FONTE, 'status') ], 'só os campos da lista branca');
};

subtest 'mapeamento: 6->7 dígitos, órfão, coords inválidas -> NULL, sem tipo' => sub {
  my ($j) = mk_job();
  my $res = $j->mapear([ map { EduMaps::Ingestion::Job::CNES::sanitizar($_) }
    est(cnes => 1, mun => 120004),
    est(cnes => 2, mun => 120001, lat => 0, lon => 0),
    est(cnes => 3, mun => 120005, lat => -9.97, lon => undef),
    est(cnes => 4, mun => 120005, lat => 45.0, lon => -67.8),
    est(cnes => 5, mun => 999999),
    est(cnes => 6, mun => 120004, tipo => undef),
    est(cnes => 1, mun => 120004),
  ], $j->indice_prefixo6);
  my %l = map { $_->{codigo_cnes} => $_ } @{ $res->{linhas} };
  is(scalar keys %l, 4, 'quatro carregáveis');
  is($l{1}{codigo_municipio}, '1200040', '120004 -> 1200040');
  is($l{1}{latitude}, -9.97, 'coordenada válida preservada');
  is($l{1}{status}, 1, 'status = 1 (só ativos)');
  ok(!defined $l{2}{latitude} && !defined $l{2}{longitude}, 'zero -> NULL');
  ok(!defined $l{3}{latitude} && !defined $l{3}{longitude}, 'par incompleto -> os dois NULL');
  ok(!defined $l{4}{latitude}, 'fora do Brasil -> NULL');
  is($res->{estatisticas}{coords_descartadas}, 3, 'coordenadas descartadas contadas');
  my %m = map { $_->{motivo} => $_ } @{ $res->{orfaos} };
  is($m{municipio_sem_casa}{codigo_municipio}, 999999, 'município sem casa vira órfão nomeado');
  ok($m{sem_tipo_unidade}, 'sem tipo de unidade vira órfão (coluna NOT NULL)');
  is($res->{estatisticas}{duplicados}, 1, 'duplicado contado, não carregado de novo');
};

subtest 'run: nenhum PII no banco nem no bruto; metadata; jsonl relê sem API' => sub {
  my ($j, $dbh, $tmp) = mk_job(paginador({
    12 => [ est(cnes => 1, mun => 120004), est(cnes => 2, mun => 120001), est(cnes => 9, mun => 999999) ],
    35 => [ est(cnes => 7, mun => 355030, uf => 35, lat => -23.55, lon => -46.63) ],
  }));
  my $n = $j->run({ uf => 'AC,35', dt_snapshot => '2026-10-13' });
  is($n, 3, 'três carregados (o órfão fica fora)');
  is_deeply([ sort { $a <=> $b } map { $_->[1]{codigo_uf} } grep { $_->[1]{offset} == 0 } @{ $j->ua->{calls} } ],
    [12, 35], 'só as UFs pedidas (sigla ou código)');

  # banco: nenhum valor de PII em nenhum parâmetro
  my $tudo = join('|', map { defined $_ ? $_ : '' } map { @$_ } @{ $dbh->{inserts} }, @{ $dbh->{dos} });
  unlike($tudo, qr/\Q$_\E/, "PII '$_' fora do banco") for @PII_VALORES;
  is($dbh->{inserts}[0][-1], '2026-10-13', 'dt_snapshot no fim');
  like($dbh->{prepared}[0], qr/ON CONFLICT \(codigo_cnes, dt_snapshot\) DO UPDATE/, 'idempotente na PK');

  # bruto em disco (raw preservado): só o sanitizado
  my ($man) = @{ $j->raw_manifest };
  ok($man && -f $man->{caminho}, 'bruto preservado no raw');
  like($man->{sha256} // '', qr/^[0-9a-f]{64}$/, 'sha256');
  my $bruto = path($man->{caminho})->slurp;
  unlike($bruto, qr/\Q$_\E/, "PII '$_' fora do bruto") for @PII_VALORES;
  unlike($bruto, qr/\Q$_\E/, "chave $_ fora do bruto") for @PII_CHAVES;
  my $orf = path("$tmp/trab/cnes_orfaos.csv")->slurp;
  unlike($orf, qr/\Q$_\E/, "PII '$_' fora dos órfãos") for @PII_VALORES;

  my ($meta) = grep { $_->[0] =~ /import_metadata/ } @{ $dbh->{dos} };
  ok($meta, 'upsert_metadata');
  like($meta->[7], qr/SANITIZADOS/, 'nota declara a sanitização');
  like($meta->[7], qr/não é obra derivada/, 'nota registra a decisão da licença');
  like($meta->[7], qr/AC=2, SP=1/, 'resumo por UF');

  my ($j2, $dbh2) = mk_job(sub { die "a API não pode ser chamada\n" });
  is($j2->run({ jsonl => $man->{caminho}, dt_snapshot => '2026-10-13' }), 3, 'jsonl relê o bruto');
  is(scalar @{ $j2->ua->{calls} }, 0, 'nenhuma chamada à API');
  my ($j3) = mk_job(sub { die "nada de API\n" });
  is($j3->run({ jsonl => $man->{caminho}, uf => 'SP', dt_snapshot => '2026-10-13' }), 1, 'jsonl + uf: só a UF pedida');
};

subtest 'uma transação por UF: falha tardia não desfaz a anterior' => sub {
  my ($j, $dbh) = mk_job(paginador({
    12 => [ est(cnes => 1, mun => 120004) ],
    35 => [ est(cnes => 7, mun => 355030, uf => 35) ],
  }), dbh_opts => { falhar_cnes => 7 });
  ok(!eval { $j->run({ uf => '12,35' }); 1 }, 'SP falha');
  like($@, qr/UF SP falhou.*retomar com --arg uf=/s, 'mensagem orienta a retomada');
  is(scalar @{ $dbh->{inserts} }, 1, 'AC continua gravado');
  is($dbh->{inserts}[0][0], 1, 'é o registro do AC');
};

subtest 'ufs_alvo: todas por padrão, sigla ou código; desconhecida morre' => sub {
  my ($j) = mk_job();
  is(scalar(my @t = $j->ufs_alvo({})), 27, '27 UFs');
  is_deeply([ $j->ufs_alvo({ uf => 'sp,12' }) ], [35, 12], 'sigla e código');
  ok(!eval { $j->ufs_alvo({ uf => 'XX' }); 1 }, 'UF desconhecida morre');
};

subtest 'run: vazio não é sucesso' => sub {
  my ($j) = mk_job(paginador({ 12 => [ est(mun => 999999) ] }));
  ok(!eval { $j->run({ uf => 'AC' }); 1 }, 'morre');
  like($@, qr/nenhum estabelecimento carregado/, 'mensagem');
};

subtest 'dry-run: uma página, nada gravado' => sub {
  my ($j, $dbh) = mk_job(paginador({ 12 => [ est(), est(cnes => 2) ] }), dry_run => 1);
  is($j->run({}), 2, 'registros da página de sanidade');
  is(scalar @{ $j->ua->{calls} }, 1, 'uma requisição');
  is(scalar @{ $dbh->{inserts} } + scalar @{ $dbh->{dos} }, 0, 'nada gravado');
};

is_deeply([ $JOB->new->tabelas ], ['clean.cnes_estabelecimentos'], 'tabelas()');
is($JOB->new->stall_timeout, 1800, 'prazo de stall declarado');

done_testing();
