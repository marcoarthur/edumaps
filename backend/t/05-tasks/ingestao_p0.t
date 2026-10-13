use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;
use Mojo::File qw(path tempdir);
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;
use Mojolicious::Lite ();
use Digest::SHA qw(sha256_hex);
use Encode qw(decode);
use POSIX qw(strftime);

# =====================================================================
# #231 — pré-requisitos P0 da ingestão real (#156)
#
#   1. CLI: --arg chave=valor chega ao job; --list sem mojibake;
#      exit 0/1/3 (ok / falha / não carregada).
#   2. Estado da tentativa em import_metadata sem destruir a proveniência.
#   3. SICONFI: row_count = total da execução; FUNDEB na sua própria linha.
#   4. download_file: raw/<fonte>/<dia>/, sha256, reaproveitamento,
#      manifesto (servidor HTTP local, sem rede externa).
#   5. allowlist: NEGADO / fora da lista / INATIVA morrem alto.
#   7. dry-run honesto: BrazilCrime não falha; IBGE faz no máximo 1 GET.
# =====================================================================

use_ok('EduMaps::Ingestion::CLI');
use_ok('EduMaps::Ingestion::Runner');
use_ok('EduMaps::Data::Allowlist');

my $LOG = Mojo::Log->new(level => 'fatal');

# --- mocks de banco: registram cada `do` --------------------------------
{
  package P0DBH;
  sub new { bless { dos => [], rows => $_[1] // [] }, $_[0] }
  sub do { my ($s, $sql, $attr, @p) = @_; push @{ $s->{dos} }, [ $sql, @p ]; return 1 }
  sub selectall_arrayref { $_[0]{rows} }
  sub begin_work {} sub commit { 1 } sub rollback { 1 }
  sub prepare { bless { dbh => $_[0] }, 'P0STH' }
  package P0STH; sub execute { 1 }
  package P0Storage; sub dbh { $_[0]{dbh} }
  package P0Schema;  sub storage { $_[0]{storage} }
  package P0App;     sub schema { $_[0]{schema} }
}
sub mock_app {
  my $dbh = P0DBH->new(@_);
  my $app = bless { schema => bless({ storage => bless({ dbh => $dbh }, 'P0Storage') }, 'P0Schema') }, 'P0App';
  return ($app, $dbh);
}
# status gravados nos `do` (INSERT ... ultimo_status / UPDATE de fechamento)
sub estados {
  my $dbh = shift;
  my @e;
  for my $d (@{ $dbh->{dos} }) {
    my ($sql, @p) = @$d;
    if ($sql =~ /INSERT INTO clean\.import_metadata AS im\s*\(table_name, source_file, ultimo_status/) {
      push @e, [ $p[0], $p[2], $p[3] ];
    }
    elsif ($sql =~ /SET ultimo_status = 'nao_carregada'/ && $sql =~ /^\s*UPDATE/) {
      push @e, [ $p[0], 'fechar' ];
    }
    elsif ($sql =~ /ultimo_status, ultimo_motivo,\s*ultima_tentativa_em, raw_manifest/) {
      push @e, [ $p[0], 'ok', $p[3] ];
    }
  }
  return \@e;
}
{ package P0Notifier; sub new { bless {}, shift } sub notify { 1 } }

# --- allowlist sintético para o servidor local --------------------------
my $tmp = tempdir;
my $AL_FILE = $tmp->child('allowlist.yaml');
$AL_FILE->spew(<<'YAML');
sources:
  - id: teste_local
    host: 127.0.0.1
    resources:
      - path: "/arquivos"
        license: "CC0-1.0"
  - id: teste_inativa
    host: localhost
    status: inativo
    status_note: "host morto no teste"
    resources:
      - path: "/arquivos"
denied:
  - id: teste_negado
    host: 127.0.0.1
    path: "/arquivos/secreto"
    reason: "dado pessoal no teste"
YAML
my $AL = EduMaps::Data::Allowlist->new(file_path => "$AL_FILE");

# --- servidor HTTP local (Mojolicious::Lite) ----------------------------
my %hits;
my $srv = Mojolicious->new;
$srv->log->level('fatal');
$srv->routes->get('/arquivos/*nome' => sub {
  my $c = shift;
  my $n = $c->stash('nome');
  $hits{$n}++;
  return $c->render(text => 'nao existe', status => 404) if $n eq 'sumiu.csv';
  $c->render(data => "conteudo de $n\n");
});
my $ua = Mojo::UserAgent->new;
$ua->server->app($srv);
my $BASE = $ua->server->url->path('/')->to_string;
$BASE =~ s{/\z}{};

# =====================================================================
subtest '1a. --arg: parse (string, repetida vira lista, sem = vale 1, inválido morre)' => sub {
  my $a = EduMaps::Ingestion::CLI->parse_args('uf=SP,RJ', 'exercicio=2025', 'dca', 'anos=last 10', 'x=a=b');
  is $a->{uf}, 'SP,RJ', 'vírgula NÃO vira lista na CLI (o job decide)';
  is $a->{exercicio}, '2025', 'valor string';
  is $a->{dca}, 1, 'sem "=" vale 1';
  is $a->{anos}, 'last 10', 'espaço preservado';
  is $a->{x}, 'a=b', 'só o primeiro "=" separa';
  is_deeply EduMaps::Ingestion::CLI->parse_args('uf=SP', 'uf=RJ')->{uf}, ['SP', 'RJ'], 'chave repetida vira arrayref';
  ok !eval { EduMaps::Ingestion::CLI->parse_args('=x'); 1 }, 'chave vazia morre';
  ok !eval { EduMaps::Ingestion::CLI->parse_args('a-b=1'); 1 }, 'chave não-identificador morre';

  require EduMaps::Ingestion::Job::Base;
  my $b = EduMaps::Ingestion::Job::Base->new;
  is_deeply [ $b->arg_lista({ uf => 'SP, RJ' }, 'uf') ], [qw(SP RJ)], 'arg_lista divide vírgula';
  is_deeply [ $b->arg_lista({ uf => ['SP,RJ', 'MG'] }, 'uf') ], [qw(SP RJ MG)], 'arg_lista achata lista';
  is_deeply [ $b->arg_lista({}, 'uf') ], [], 'ausente = vazio';
};

# Job temporário que grava os args que recebeu, e jobs que falham.
my $libtmp = tempdir;
my $jobdir = $libtmp->child('EduMaps', 'Ingestion', 'Job');
$jobdir->make_path;
my $saida_args = $libtmp->child('args.json');
$jobdir->child('ZZP0Args.pm')->spew(<<"PM");
package EduMaps::Ingestion::Job::ZZP0Args;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use Mojo::JSON qw(encode_json);
use Mojo::File qw(path);
has job_name => 'ZZP0Args';
has description => 'grava args';
sub run (\$self, \$args = {}) { path('$saida_args')->spew(encode_json(\$args)); 1 }
1;
PM
$jobdir->child('ZZP0Bloqueado.pm')->spew(Encode::encode('UTF-8', <<'PM'));
package EduMaps::Ingestion::Job::ZZP0Bloqueado;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;
has job_name => 'ZZP0Bloqueado';
has description => 'bloqueado';
sub run ($self, $args = {}) { $self->nao_carregada('e-SIC não protocolado (teste)') }
1;
PM
$jobdir->child('ZZP0Falha.pm')->spew(<<'PM');
package EduMaps::Ingestion::Job::ZZP0Falha;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
has job_name => 'ZZP0Falha';
has description => 'falha';
sub run ($self, $args = {}) { die "quebrou de verdade\n" }
1;
PM

sub runner_cli {
  my @argv = @_;
  my $out = `$^X -I$libtmp -Ilib ingestion_runner.pl @argv 2>&1`;
  return ($? >> 8, decode('UTF-8', $out));
}

subtest '1b. --arg chega ao job via ingestion_runner.pl' => sub {
  my ($rc, $out) = runner_cli('--job=ZZP0Args', '--arg', 'uf=SP,RJ', '--arg', 'exercicio=2025', '--arg', 'uf=MG', '--arg', 'dca');
  is $rc, 0, 'exit 0' or diag $out;
  my $args = decode_json($saida_args->slurp);
  is_deeply $args, { uf => ['SP,RJ', 'MG'], exercicio => '2025', dca => 1 }, 'hashref chegou ao run()';

  ($rc, $out) = runner_cli('--job=ZZP0Args', '--arg', 'a-b=1');
  is $rc, 2, '--arg inválido: exit 2 (uso)';
  like $out, qr/--arg inválido/, 'mensagem de uso';
};

subtest '1c. exit 3 = não carregada; exit 1 = falha (falha domina)' => sub {
  my ($rc, $out) = runner_cli('--job=ZZP0Bloqueado');
  is $rc, 3, 'não carregada: exit 3 (nem 0, nem 1)';
  like $out, qr/⊘ ZZP0Bloqueado/, 'símbolo próprio';
  like $out, qr/\[NAO_CARREGADA\] e-SIC não protocolado/, 'motivo, sem mojibake';
  like $out, qr/0 falha\(s\), 1 não carregado/, 'resumo separa as contagens';

  ($rc) = runner_cli('--job=ZZP0Falha');
  is $rc, 1, 'falha: exit 1';

  is(EduMaps::Ingestion::CLI->exit_code([{ success => 0, nao_carregada => 1 }, { success => 0 }]), 1, 'misto: falha domina');
  is(EduMaps::Ingestion::CLI->exit_code([{ success => 1 }, { success => 0, nao_carregada => 1 }]), 3, 'ok + não carregada: 3');
  is(EduMaps::Ingestion::CLI->exit_code([{ success => 1 }]), 0, 'tudo ok: 0');
};

subtest '1d. --list em UTF-8, sem mojibake nem "Wide character"' => sub {
  my ($rc, $out) = runner_cli('--list');
  is $rc, 0, 'exit 0';
  unlike $out, qr/Wide character/, 'sem warning de Wide character';
  unlike $out, qr/\x{FFFD}|Ã[£§©¡³ªº]/, 'sem mojibake';
  like $out, qr/Jobs disponíveis/, 'cabeçalho acentuado';
  like $out, qr/INMET\s+.*NÃO CONSTRUÍDA/, 'descrição de módulo antes sem use utf8';
  like $out, qr/SICONFI\s+Ingestão SICONFI/, 'descrição de módulo com use utf8';
};

# =====================================================================
subtest '2a. Runner: falha grava falhou+motivo nas tabelas do job, só estado' => sub {
  my ($app, $dbh) = mock_app();
  my $r = EduMaps::Ingestion::Runner->new(app => $app, log => $LOG, notifier => P0Notifier->new, stall_timeout => 0);
  {
    package ZZP0JobTab;
    use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
    has job_name => 'ZZP0JobTab';
    has modo => 'falha';
    sub tabelas ($self, $args = {}) { return $args->{dca} ? ('t.dca') : ('t.a', 't.b') }
    sub run ($self, $args = {}) {
      die "boom: API 500\n" if $self->modo eq 'falha';
      $self->nao_carregada('bloqueio X') if $self->modo eq 'bloqueio';
      $self->upsert_metadata('t.a', 'f', 'https://x/y', 'CC0', 10, 'nota') if $self->modo eq 'ok';
      return 1;
    }
  }
  $r->jobs->{F} = ZZP0JobTab->new(app => $app, log => $LOG, allowlist => $AL);
  my $res = $r->run_job('F', {});
  is $res->{success}, 0, 'falhou';
  is_deeply estados($dbh), [
    ['t.a', 'em_carga', undef], ['t.b', 'em_carga', undef],
    ['t.a', 'falhou', "boom: API 500\n"], ['t.b', 'falhou', "boom: API 500\n"],
  ], 'em_carga no início, falhou + mensagem do die no fim';
  for my $d (@{ $dbh->{dos} }) {
    my ($sql) = @$d;
    next unless $sql =~ /ultimo_status, ultimo_motivo, ultima_tentativa_em\)/;
    my ($set) = $sql =~ /DO UPDATE SET(.*)\z/s;
    unlike $set, qr/source_|retrieved_at|row_count_loaded|notes|raw_manifest/,
      'o ON CONFLICT do estado não toca na proveniência';
  }

  @{ $dbh->{dos} } = ();
  $res = $r->run_job('F', { dca => 1 });
  is_deeply [ map { $_->[0] } @{ estados($dbh) } ], ['t.dca', 't.dca'], 'tabelas dependem dos args';

  @{ $dbh->{dos} } = ();
  $r->jobs->{F}->modo('bloqueio');
  $res = $r->run_job('F', {});
  ok $res->{nao_carregada}, 'resultado marcado nao_carregada';
  like $res->{error}, qr/^\[NAO_CARREGADA\] bloqueio X/, 'erro stringifica com o marcador';
  is_deeply [ grep { $_->[1] ne 'em_carga' } @{ estados($dbh) } ],
    [['t.a', 'nao_carregada', 'bloqueio X'], ['t.b', 'nao_carregada', 'bloqueio X']], 'nao_carregada + motivo';

  @{ $dbh->{dos} } = ();
  $r->jobs->{F}->modo('ok');
  $res = $r->run_job('F', {});
  is $res->{success}, 1, 'ok';
  is_deeply [ grep { $_->[1] ne 'em_carga' } @{ estados($dbh) } ],
    [['t.a', 'ok', 'CC0'], ['t.a', 'fechar'], ['t.b', 'fechar']],
    'upsert de sucesso marca ok; o fechamento só converte o que ficou em_carga (t.b, sem carga)';
};

subtest '2b. dry-run não escreve estado; erro ao registrar não mascara o job' => sub {
  my ($app, $dbh) = mock_app();
  my $r = EduMaps::Ingestion::Runner->new(app => $app, log => $LOG, notifier => P0Notifier->new, stall_timeout => 0, dry_run => 1);
  $r->jobs->{F} = ZZP0JobTab->new(app => $app, log => $LOG, dry_run => 1);
  my $res = $r->run_job('F', {});
  is $res->{success}, 0, 'falha propagada';
  is scalar @{ $dbh->{dos} }, 0, 'nenhum write em dry-run';

  { package P0DBHQuebrado; our @ISA = ('P0DBH'); sub do { die "banco fora\n" } }
  my ($app2, $dbh2) = mock_app();
  bless $dbh2, 'P0DBHQuebrado';
  $r = EduMaps::Ingestion::Runner->new(app => $app2, log => $LOG, notifier => P0Notifier->new, stall_timeout => 0);
  $r->jobs->{F} = ZZP0JobTab->new(app => $app2, log => $LOG);
  $res = $r->run_job('F', {});
  like $res->{error}, qr/boom: API 500/, 'o erro do job (e não o do registro) é o reportado';
};

subtest '2c. upsert_metadata: licença undef preserva a do banco; manifesto vai junto' => sub {
  my ($app, $dbh) = mock_app();
  my $j = ZZP0JobTab->new(app => $app, log => $LOG, allowlist => $AL);
  push @{ $j->raw_manifest }, { url => 'u1', caminho => 'c1', sha256 => 'a', bytes => 1 },
                              { url => 'u2', caminho => 'c2', sha256 => 'b', bytes => 2, tabelas => ['t.outra'] };
  $j->upsert_metadata('t.a', 'f', "$BASE/arquivos/x.csv", undef, 5, 'n');
  my ($sql, @p) = @{ $dbh->{dos}[0] };
  like $sql, qr/THEN COALESCE\(im\.source_license, EXCLUDED\.source_license\)/, 'SQL preserva a licença existente';
  is $p[3], 'CC0-1.0', 'sem linha prévia: licença do allowlist';
  is $p[-1], 1, 'flag preservar = 1';
  my $m = decode_json($p[-2]);
  is_deeply [ map { $_->{url} } @$m ], ['u1'], 'manifesto filtrado pela tabela';

  @{ $dbh->{dos} } = ();
  $j->upsert_metadata('t.a', 'f', 'https://x', 'MIT', 5, 'n');
  is $dbh->{dos}[0][-1], 0, 'licença explícita: flag preservar = 0';
};

# =====================================================================
subtest '3. SICONFI: row_count da execução e FUNDEB na sua própria linha' => sub {
  require EduMaps::Ingestion::Job::SICONFI;
  my ($app, $dbh) = mock_app();
  my $calls = 0;
  {
    package P0SiconfiUA;
    sub new { bless { h => $_[1] }, $_[0] }
    sub get { my ($s, $url, %a) = @_; my $json = $s->{h}->($url, $a{form} // {});
      return bless { res => bless({ json => $json }, 'P0SRes') }, 'P0STx' }
    package P0STx; sub res { $_[0]{res} }
    package P0SRes; sub code { 200 } sub json { $_[0]{json} }
  }
  my $item = sub { my ($cod, $conta, $col, $v, %o) = @_;
    { anexo => $o{anexo} // 'RREO-Anexo 01', cod_conta => $conta, conta => $o{conta} // $conta,
      coluna => $col, valor => $v, cod_ibge => $cod } };
  my $handler = sub {
    my ($url, $f) = @_;
    $calls++;
    if ($url =~ /entes$/) {
      return { items => [ map { { cod_ibge => $_, esfera => 'M', uf => 'SP' } } 3500105, 3500204, 3500303 ], hasMore => 0 };
    }
    my $cod = $f->{id_ente};
    if ($url =~ /dca$/) {
      return { hasMore => 0, items => [
        $item->($cod, 'x', 'Despesas Pagas', 10, anexo => 'DCA-Anexo I-E', conta => '12 - Educação'),
        $item->($cod, 'RO1.7.5.1.00.0.0', 'Receitas Brutas Realizadas', 99, anexo => 'DCA-Anexo I-C', conta => '1.7.5.1.00.0.0 - FUNDEB'),
      ] };
    }
    # município 3500204 com 2 linhas, os outros com 1: o total é 4, não 1
    my @i = ($item->($cod, 'Impostos', 'Até o Bimestre (c)', 1));
    push @i, $item->($cod, 'Taxas', 'Até o Bimestre (c)', 2) if $cod eq '3500204';
    return { hasMore => 0, items => \@i };
  };
  my $mk = sub { EduMaps::Ingestion::Job::SICONFI->new(log => $LOG, app => $app, throttle => 0, max_retries => 0,
    allowlist => EduMaps::Data::Allowlist->new, ua => P0SiconfiUA->new($handler),
    entes_cache_file => $tmp->child('entes_' . rand() . '.json'), @_) };

  my $total = $mk->()->run({ uf => 'sp,rj' });
  is $total, 4, '4 linhas na execução';
  my @ups = grep { $_->[0] =~ /raw_manifest\)/ } @{ $dbh->{dos} };
  is scalar @ups, 1, 'UM upsert de metadata por tabela (não um por município)';
  is $ups[0][1], 'clean.siconfi_receita', 'linha da receita';
  is $ups[0][5], 4, 'row_count = total da execução (4), não o do último município (1)';
  like $ups[0][6], qr/3 município\(s\) com dado, de 3 alvo/, 'notes com a cobertura';

  @{ $dbh->{dos} } = ();
  $mk->()->run({ uf => 'SP', dca => 1, exercicio => 2024 });
  my %t = map { $_->[1] => $_->[5] } grep { $_->[0] =~ /raw_manifest\)/ } @{ $dbh->{dos} };
  is_deeply \%t, { 'clean.siconfi_despesa' => 3, 'clean.siconfi_receita#fundeb' => 3 },
    'DCA: despesa + FUNDEB na linha própria; a linha clean.siconfi_receita (RREO) não é tocada';
  is_deeply [ EduMaps::Ingestion::Job::SICONFI->new->tabelas({ dca => 1 }) ],
    ['clean.siconfi_despesa', 'clean.siconfi_receita#fundeb'], 'tabelas() do modo DCA';

  @{ $dbh->{dos} } = ();
  $calls = 0;
  my $n = $mk->(dry_run => 1)->run({ uf => 'SP' });
  is $calls, 2, 'dry-run: /entes + 1 /rreo de sanidade (não a malha)';
  is $n, 1, 'dry-run relata as linhas mapeadas da amostra';
  is scalar @{ $dbh->{dos} }, 0, 'dry-run não escreve';

  # malha: município sem RREO publicado é pulado; malha inteira vazia morre
  @{ $dbh->{dos} } = ();
  my $sem = sub { my ($url, $f) = @_;
    return $handler->($url, $f) if $url =~ /entes$/;
    return { hasMore => 0, items => [] } if ($f->{id_ente} // '') eq '3500105';
    return $handler->($url, $f) };
  is $mk->(ua => P0SiconfiUA->new($sem))->run({ uf => 'SP' }), 3, 'município sem RREO pulado, malha segue (3 linhas)';
  my $vazio = sub { my ($url, $f) = @_; return $url =~ /entes$/ ? $handler->($url, $f) : { hasMore => 0, items => [] } };
  ok !eval { $mk->(ua => P0SiconfiUA->new($vazio))->run({ uf => 'SP' }); 1 }, 'malha sem nenhum dado morre';
  like $@, qr/nenhum dos 3 município/, 'motivo: malha vazia não é sucesso';
  ok !eval { $mk->(ua => P0SiconfiUA->new($vazio))->run({ cod_ibge => '3500105' }); 1 }, 'município único com 0 itens continua morrendo';

  # dry-run: a amostra é o mais populoso da seleção
  my @ids;
  my $pop = sub { my ($url, $f) = @_;
    return { hasMore => 0, items => [ { cod_ibge => 3500105, esfera => 'M', uf => 'SP', populacao => 10 },
                                      { cod_ibge => 3550308, esfera => 'M', uf => 'SP', populacao => 12000000 } ] }
      if $url =~ /entes$/;
    push @ids, $f->{id_ente};
    return $handler->($url, $f) };
  $mk->(dry_run => 1, ua => P0SiconfiUA->new($pop))->run({ uf => 'SP' });
  is_deeply \@ids, ['3550308'], 'dry-run: sanidade com o município mais populoso';

  my $j = $mk->(base_url => 'https://tesouror.transparencia.gov.br/api/v1');
  ok !eval { $j->_fetch_entes; 1 }, 'host inativo no allowlist morre (antes da requisição)';
  like $@, qr/\[ALLOWLIST\].*INATIVA/, 'motivo INATIVA';
};

# =====================================================================
subtest '4. download_file: raw/<fonte>/<dia>/, sha256, reaproveitamento, cópia' => sub {
  my $raw = tempdir;
  my ($app, $dbh) = mock_app();
  my $j = ZZP0JobTab->new(app => $app, log => $LOG, ua => $ua, allowlist => $AL,
    config => { raw_dir => "$raw" }, max_retries => 0);
  my $hoje = strftime('%Y-%m-%d', localtime);

  my $p = $j->download_file("$BASE/arquivos/dados.csv");
  is $p, "$raw/zzp0jobtab/$hoje/dados.csv", 'caminho raw/<fonte>/<AAAA-MM-DD>/<arquivo>';
  is path($p)->slurp, "conteudo de dados.csv\n", 'conteúdo gravado';
  ok !-e "$p.part", 'sem .part residual';
  my $m = $j->raw_manifest->[0];
  is $m->{sha256}, sha256_hex("conteudo de dados.csv\n"), 'sha256';
  is $m->{bytes}, length("conteudo de dados.csv\n"), 'bytes';
  is $m->{url}, "$BASE/arquivos/dados.csv", 'url';
  ok !$m->{reaproveitado}, 'primeiro download não é reaproveitado';
  like $m->{baixado_em}, qr/^\d{4}-\d\d-\d\dT/, 'baixado_em ISO 8601';

  my $j2 = ZZP0JobTab->new(app => $app, log => $LOG, ua => $ua, allowlist => $AL,
    config => { raw_dir => "$raw" }, max_retries => 0);
  my $tdest = tempdir;
  my $dest = $tdest->child('trabalho', 'x.csv');
  my $p2 = $j2->download_file("$BASE/arquivos/dados.csv", "$dest");
  is $hits{'dados.csv'}, 1, 'mesmo nome no mesmo dia: NÃO rebaixa';
  ok $j2->raw_manifest->[0]{reaproveitado}, 'manifesto marca reaproveitado';
  is $p2, "$dest", 'devolve o destino pedido';
  is $j2->raw_manifest->[0]{caminho}, "$raw/zzp0jobtab/$hoje/dados.csv", 'raw guarda o nome da fonte (URL), não o do destino';
  ok -f $dest, 'cópia no destino de trabalho';

  $j->download_file("$BASE/arquivos/dados.csv");
  is scalar @{ $j->raw_manifest }, 1, 'mesma URL/caminho conta uma vez no manifesto';

  ok !eval { $j->download_file("$BASE/arquivos/sumiu.csv"); 1 }, 'HTTP 404 morre';
  like $@, qr/404/, 'motivo com o código';
  ok !-e "$raw/zzp0jobtab/$hoje/sumiu.csv", 'nada fica no raw';

  my $jd = ZZP0JobTab->new(app => $app, log => $LOG, ua => $ua, allowlist => $AL,
    config => { raw_dir => "$raw" }, dry_run => 1);
  $jd->download_file("$BASE/arquivos/seco.csv");
  ok !$hits{'seco.csv'}, 'dry-run não baixa';
  is scalar @{ $jd->raw_manifest }, 0, 'dry-run não acumula manifesto';

  my $torig = tempdir;
  my $orig = $torig->child('renaest.zip');
  $orig->spew('zipzip');
  my $pr = $j->preservar_raw("$orig", 'https://dados.transportes.gov.br/dataset/renaest', tabelas => ['t.b']);
  is path($pr)->slurp, 'zipzip', 'preservar_raw copia o arquivo local para o raw';
  is $j->manifesto_para('t.a')->[-1]{url}, "$BASE/arquivos/dados.csv", 'entrada restrita a t.b não vale para t.a';
  is $j->manifesto_para('t.b')->[-1]{sha256}, sha256_hex('zipzip'), 'e vale para t.b';
};

subtest '5. allowlist: NEGADO / fora da lista / INATIVA morrem alto (inclusive em dry-run)' => sub {
  my $raw = tempdir;
  for my $dry (0, 1) {
    my $j = ZZP0JobTab->new(log => $LOG, ua => $ua, allowlist => $AL, config => { raw_dir => "$raw" },
      dry_run => $dry, max_retries => 0);
    my %casos = (
      "$BASE/arquivos/secreto/a.csv" => qr/\[ALLOWLIST\].*explicitamente NEGADO.*dado pessoal/,
      "$BASE/outro/a.csv"            => qr/\[ALLOWLIST\].*fora da allowlist/,
      ($BASE =~ s/127\.0\.0\.1/localhost/r) . '/arquivos/a.csv' => qr/\[ALLOWLIST\].*INATIVA.*host morto/,
    );
    for my $url (sort keys %casos) {
      ok !eval { $j->download_file($url); 1 }, "recusado (dry=$dry): $url";
      like $@, $casos{$url}, 'motivo';
    }
    ok !eval { $j->fetch_with_retry("$BASE/outro/x"); 1 }, "fetch_with_retry também valida (dry=$dry)";
  }
  ok !$hits{'a.csv'}, 'nenhuma requisição saiu para URL recusada';
};

# =====================================================================
subtest '7a. BrazilCrime dry-run não falha e não escreve' => sub {
  require EduMaps::Ingestion::Job::BrazilCrime;
  my ($app, $dbh) = mock_app();
  my $j = EduMaps::Ingestion::Job::BrazilCrime->new(log => $LOG, app => $app, dry_run => 1,
    config => { dir_trabalho => "$tmp/bc" });
  my $rc;
  ok eval { $rc = $j->run({}); 1 }, 'dry-run conclui' or diag $@;
  is $rc, 0, 'nada extraído';
  is scalar @{ $dbh->{dos} }, 0, 'nada gravado';
  is_deeply [ $j->tabelas ], ['clean.brazilcrime_municipio'], 'tabelas()';
};

subtest '7b. IBGE dry-run: no máximo 1 GET de sanidade, sem extração' => sub {
  require EduMaps::Ingestion::Job::IBGE;
  my $gets = 0;
  {
    package P0IbgeUA;
    sub new { bless { n => $_[1] }, $_[0] }
    sub get { ${ $_[0]{n} }++; bless {}, 'P0ITx' }
    package P0ITx; sub res { bless {}, 'P0IRes' }
    package P0IRes; sub code { 200 } sub json { [ {}, { D3C => 2021, D2C => 37, V => '1' } ] }
  }
  my $dir = tempdir;
  my ($app, $dbh) = mock_app([ map { { codigo_ibge => $_ } } qw(3550308 3304557 3106200) ]);
  my $j = EduMaps::Ingestion::Job::IBGE->new(log => $LOG, app => $app, dry_run => 1,
    ua => P0IbgeUA->new(\$gets), config => { dir_trabalho => "$dir" });
  my $n = $j->run({ anos => '2021' });
  is $gets, 1, '1 requisição (e não 2 x 3 municípios)';
  is $n, 1, 'relata os valores da amostra';
  ok !-e "$dir/dados_ibge.csv", 'sem CSV de extração';
  is scalar @{ $dbh->{dos} }, 0, 'nada gravado';
};

# =====================================================================
subtest '2d. BD real: falha depois de carga boa preserva a proveniência' => sub {
  plan skip_all => 'sem EDUMAPS_DB_HOST (base intencional; nunca o default do edu_maps.conf)'
    unless $ENV{EDUMAPS_DB_HOST};
  require EduMaps::Ingestion::App;
  my $app = EduMaps::Ingestion::App->new;
  my $dbh = eval { $app->schema->storage->dbh };
  plan skip_all => "sem BD: $@" unless $dbh;
  my $tem = $dbh->selectrow_array(q{SELECT 1 FROM pg_attribute
    WHERE attrelid = 'clean.import_metadata'::regclass AND attname = 'ultimo_status'});
  plan skip_all => 'change import_metadata_estado não deployada' unless $tem;

  my $T = '__teste_p0_231__';
  $dbh->do('DELETE FROM clean.import_metadata WHERE table_name = ?', undef, $T);
  my $j = ZZP0JobTab->new(app => $app, log => $LOG, allowlist => $AL);
  push @{ $j->raw_manifest }, { url => 'u', caminho => 'c', sha256 => 's', bytes => 1 };
  $j->upsert_metadata($T, 'arquivo-bom', 'https://exemplo/bom', 'CC0', 42, 'carga boa');
  $j->registrar_tentativa($T);
  $j->registrar_falha("boom\n", $T);
  my $r = $dbh->selectrow_hashref('SELECT * FROM clean.import_metadata WHERE table_name = ?', undef, $T);
  is $r->{source_file}, 'arquivo-bom', 'source_file preservado';
  is $r->{row_count_loaded}, 42, 'row_count preservado';
  is $r->{notes}, 'carga boa', 'notes preservadas';
  is decode_json($r->{raw_manifest})->[0]{sha256}, 's', 'manifesto preservado';
  is $r->{ultimo_status}, 'falhou', 'estado falhou';
  is $r->{ultimo_motivo}, "boom\n", 'motivo';

  $j->upsert_metadata($T, 'arquivo-novo', 'https://exemplo/bom', undef, 7, 'nova');
  $r = $dbh->selectrow_hashref('SELECT * FROM clean.import_metadata WHERE table_name = ?', undef, $T);
  is $r->{source_license}, 'CC0', 'licença undef preserva a do banco';
  is $r->{ultimo_status}, 'ok', 'sucesso volta a ok';
  ok !defined $r->{ultimo_motivo}, 'motivo limpo';

  my $U = '__teste_p0_231_sem_linha__';
  $dbh->do('DELETE FROM clean.import_metadata WHERE table_name = ?', undef, $U);
  $j->registrar_nao_carregada('bloqueio', $U);
  $r = $dbh->selectrow_hashref('SELECT * FROM clean.import_metadata WHERE table_name = ?', undef, $U);
  is $r->{source_file}, '(nenhuma carga registrada)', 'sem carga anterior: linha só de estado';
  is $r->{ultimo_status}, 'nao_carregada', 'estado gravado';

  $dbh->do('DELETE FROM clean.import_metadata WHERE table_name IN (?, ?)', undef, $T, $U);
};

done_testing;
