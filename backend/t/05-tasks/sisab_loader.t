use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path tempdir);
use Mojo::JSON qw(encode_json);

# =====================================================================
# Job SISAB (#238): consolidado atual do PMMB (Mais Médicos) ->
# clean.sisab_aps. Shape dos itens = o medido na API em 2026-10-13.
#  1. paginação por offset de linha, até a página curta;
#  2. só nivel MUNICIPAL entra (DSEI/ESTADUAL contados e descartados);
#  3. co_ibge de 6 dígitos vira o de 7 da malha; sem casa -> órfão nomeado;
#  4. 'NA' -> NULL; categoria_ivs '3 - Media...' -> 3; total_ocupadas ->
#     ocupadas; dt_referencia -> 1º dia do mês;
#  5. --arg json relê o bruto sem API; o bruto vai para o raw (sha256);
#  6. dry-run: uma página, nada gravado.
# =====================================================================

my $JOB = 'EduMaps::Ingestion::Job::SISAB';
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
  sub execute { my ($s, @p) = @_; push @{ $s->{dbh}{inserts} }, \@p; 1 }
  package MockDBH;
  sub new { my ($c, %o) = @_; bless { inserts => [], dos => [], prepared => [], %o }, $c }
  sub prepare { my ($s, $sql) = @_; push @{ $s->{prepared} }, $sql; bless { dbh => $s }, 'MockSTH' }
  sub do { my ($s, $sql, @p) = @_; push @{ $s->{dos} }, [ $sql, @p ]; 1 }
  sub selectcol_arrayref { [ @{ $_[0]{malha} // [] } ] }
  package MockStorage;
  sub new { my ($c, %a) = @_; bless { %a }, $c }
  sub dbh { $_[0]{dbh} }
  sub txn_do { my ($s, $cb) = @_; $cb->() }
  package MockSchema; sub new { my ($c, %a) = @_; bless { %a }, $c } sub storage { $_[0]{storage} }
  package MockApp;    sub new { my ($c, %a) = @_; bless { %a }, $c } sub schema { $_[0]{schema} }
  package MockAllow;
  sub new { bless {}, shift } sub validate_url { 1 } sub last_error { '' }
  sub get_license_for_url { 'CC BY 3.0 (dados abertos SUS)' }
}

sub item {
  my (%p) = @_;
  return {
    nivel => $p{nivel} // 'MUNICIPAL', regiao => 'NORTE', uf => $p{uf} // 'RO',
    co_ibge => $p{co_ibge} // 110001, municipio_dsei => $p{nome} // "ALTA FLORESTA D'OESTE",
    categoria_ivs => exists $p{ivs} ? $p{ivs} : '3 - Media vulnerabilidade',
    cobertura => exists $p{cobertura} ? $p{cobertura} : 15000.0,
    ativas_ff => 6.0, equipe_esf => 6.0, equipe_emsi => 0.0, total_vagas_ativas => 6.0,
    total_ocupadas => $p{ocupadas} // 5.0, dt_referencia => $p{dt} // '2026-10-09',
  };
}

my $MALHA = [qw(1100015 1100023 1100031)];

sub mk_job {
  my ($handler, %extra) = @_;
  my $dbh = MockDBH->new(malha => $MALHA);
  my $tmp = tempdir;
  my $job = $JOB->new(
    log       => Mojo::Log->new(level => 'fatal'),
    ua        => MockUA->new($handler // sub { return ({ pmmb => [] }) }),
    allowlist => MockAllow->new,
    app       => MockApp->new(schema => MockSchema->new(storage => MockStorage->new(dbh => $dbh))),
    throttle  => 0, max_retries => 0, pagina => 2,
    config    => { dir_trabalho => "$tmp/trab", raw_dir => "$tmp/raw" },
    %extra,
  );
  return ($job, $dbh, $tmp);
}

subtest 'paginação: offset por linha até a página curta' => sub {
  my @todas = (item(co_ibge => 110001), item(co_ibge => 110002), item(co_ibge => 110003));
  my ($j) = mk_job(sub {
    my ($url, $f) = @_;
    return ({ pmmb => [ grep { defined } @todas[ $f->{offset} .. $f->{offset} + $f->{limit} - 1 ] ] });
  });
  my $itens = $j->baixar_tudo;
  is(scalar @$itens, 3, 'três itens em duas páginas');
  is_deeply([ map { $_->[1]{offset} } @{ $j->ua->{calls} } ], [0, 2], 'offset 0 e 2; página curta encerra');
  like($j->ua->{calls}[0][0], qr{/atencao-primaria/pmmb-consolidado$}, 'recurso certo');
};

subtest 'mapeamento: nível, código, NA, IVS, ocupadas, mês' => sub {
  my ($j) = mk_job();
  my $res = $j->mapear([
    item(co_ibge => 110001),
    item(co_ibge => 110002, ivs => 'NA', cobertura => 'NA', ocupadas => 4.0),
    item(nivel => 'DSEI', co_ibge => 1, nome => 'ALAGOAS E SERGIPE'),
    item(nivel => 'ESTADUAL', co_ibge => 170, nome => 'ESTADO DE TOCANTINS'),
    item(co_ibge => 999999, nome => 'MUNICIPIO NOVO', uf => 'MT'),
  ], $j->indice_prefixo6);
  my %l = map { $_->{codigo_municipio} => $_ } @{ $res->{linhas} };
  is(scalar keys %l, 2, 'dois municípios carregados');
  ok($l{1100015}, '110001 -> 1100015 (prefixo de 6)');
  is($l{1100015}{categoria_ivs}, 3, "IVS '3 - Media vulnerabilidade' -> 3");
  is($l{1100015}{cobertura_aps}, 15000, 'cobertura como vem (pessoas)');
  is($l{1100015}{dt_referencia}, '2026-10-01', 'dt_referencia -> 1º dia do mês');
  is($l{1100015}{ocupadas}, 5, 'total_ocupadas -> ocupadas');
  ok(!defined $l{1100023}{categoria_ivs}, "IVS 'NA' -> NULL");
  ok(!defined $l{1100023}{cobertura_aps}, "cobertura 'NA' -> NULL (vazio, não zero)");
  my $e = $res->{estatisticas};
  is($e->{dsei}, 1, 'DSEI contado'); is($e->{estadual}, 1, 'ESTADUAL contado');
  is(scalar @{ $res->{orfaos} }, 1, 'município sem casa vira órfão');
  is($res->{orfaos}[0]{co_ibge}, 999999, 'órfão nomeado pelo código da fonte');
};

subtest 'run: carga, bruto preservado, metadata; json relê sem API' => sub {
  my @todas = (item(co_ibge => 110001), item(co_ibge => 110003), item(nivel => 'DSEI', co_ibge => 2));
  my ($j, $dbh, $tmp) = mk_job(sub {
    my ($url, $f) = @_;
    return ({ pmmb => [ grep { defined } @todas[ $f->{offset} .. $f->{offset} + $f->{limit} - 1 ] ] });
  });
  my $n = $j->run({ dt_snapshot => '2026-10-13' });
  is($n, 2, 'duas linhas municipais');
  is(scalar @{ $dbh->{inserts} }, 2, 'dois execute');
  is($dbh->{inserts}[0][-1], '2026-10-13', 'dt_snapshot no fim dos parâmetros');
  like($dbh->{prepared}[0], qr/ON CONFLICT \(codigo_municipio, dt_referencia, dt_snapshot\) DO UPDATE/, 'idempotente na PK');
  my ($man) = @{ $j->raw_manifest };
  ok($man && -f $man->{caminho}, 'bruto JSON preservado no raw');
  like($man->{sha256} // '', qr/^[0-9a-f]{64}$/, 'sha256 no manifesto');
  my ($meta) = grep { $_->[0] =~ /import_metadata/ } @{ $dbh->{dos} };
  ok($meta, 'upsert_metadata gravado');
  like($meta->[7], qr/não é a cobertura APS total/, 'nota diz que é PMMB, não APS total');
  like($meta->[7], qr/DSEI 1/, 'nota conta os DSEI descartados');

  my ($j2, $dbh2) = mk_job(sub { die "a API não pode ser chamada\n" });
  is($j2->run({ json => $man->{caminho}, dt_snapshot => '2026-10-13' }), 2, 'json relê o bruto');
  is(scalar @{ $j2->ua->{calls} }, 0, 'nenhuma chamada à API');
};

subtest 'run: nenhuma linha municipal casada morre (vazio não é sucesso)' => sub {
  my ($j) = mk_job(sub { return ({ pmmb => [ item(co_ibge => 999999) ] }) });
  ok(!eval { $j->run({}); 1 }, 'morre');
  like($@, qr/nenhuma linha municipal/, 'mensagem explica');
};

subtest 'dry-run: uma página, nada gravado' => sub {
  my ($j, $dbh) = mk_job(sub { return ({ pmmb => [ item(), item(nivel => 'DSEI', co_ibge => 1) ] }) }, dry_run => 1);
  is($j->run({}), 2, 'itens da página de sanidade');
  is(scalar @{ $j->ua->{calls} }, 1, 'uma única requisição');
  is(scalar @{ $dbh->{inserts} } + scalar @{ $dbh->{dos} }, 0, 'nada gravado');
};

is_deeply([ $JOB->new->tabelas ], ['clean.sisab_aps'], 'tabelas()');

done_testing();
