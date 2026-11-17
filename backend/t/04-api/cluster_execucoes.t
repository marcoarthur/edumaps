# t/04-api/cluster_execucoes.t
# #427 (AN-05, AN-09): cada agrupamento é uma execução guardada, com recorte,
# parâmetros, universo, mapa e exportação CSV; vale 90 dias.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::Util qw(decode);

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $tem = $dbh->selectrow_array(q{SELECT to_regclass('analytics.cluster_execucoes') IS NOT NULL});
plan skip_all => 'analytics.cluster_execucoes ausente' unless $tem;

my $INEP_A   = '60002801';   # com coordenada, grupo 1
my $INEP_B   = '60002802';   # com coordenada, grupo 2
my $INEP_SEM = '60002803';   # sem coordenada, grupo 2 (fora do mapa)
my $RUN      = 'run_1731700000_a1b2c3d4';
my $VENCIDA  = 'run_1700000000_deadbeef';
my $ANTIGA   = 'run_1731600000_0badc0de';   # sem parametros.dados (antes da #428)
my $ANO = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas') // 2025;

my $limpa = sub {
  $dbh->do('DELETE FROM analytics.cluster_execucoes WHERE run_id IN (?, ?, ?)', {}, $RUN, $VENCIDA, $ANTIGA);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?, ?)', {}, $INEP_A, $INEP_B, $INEP_SEM);
};
$limpa->();
END { $limpa->() if $tem }

my $esc = $dbh->prepare('INSERT INTO clean.censo_escolas
   (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf,
    latitude, longitude, tp_situacao_funcionamento) VALUES (?, ?, ?, ?, 6000281, ?, ?, ?, ?, 1)');
$esc->execute($ANO, $INEP_A,   'Escola Alfa; Teste', 3, 'Cidade Teste', 'XX', -20.3, -40.3);
$esc->execute($ANO, $INEP_B,   'Escola Beta',        2, 'Cidade Teste', 'XX', -20.4, -40.4);
$esc->execute($ANO, $INEP_SEM, 'Escola Sem Ponto',   3, 'Cidade Teste', 'XX', undef, undef);

$dbh->do(q{INSERT INTO analytics.cluster_execucoes (run_id, estado, recorte, parametros, universo)
           VALUES (?, 'concluida', '{"codigo_ibge":"6000281"}',
                   '{"algorithm":"kmeans","clusters":2,"features":["in_agua_potavel","qt_salas"],"dados":{"censo":{"ano":"2025","carga":"2026-10-01"},"ideb":{"ano":"2023","carga":null}}}',
                   '{"n_total":5,"n_inativas":1,"n_recorte":4,"n_incompletas":1,"n_agrupadas":3,"sem_dado":{"qt_salas":1}}')},
  {}, $RUN);
my $atr = $dbh->prepare('INSERT INTO analytics.cluster_atribuicoes
   (run_id, co_entidade, cluster_id, cluster_label, valores) VALUES (?, ?, ?, ?, ?::jsonb)');
$atr->execute($RUN, $INEP_A,   1, 'Alta infraestrutura',  '{"in_agua_potavel":1,"qt_salas":12.5}');
$atr->execute($RUN, $INEP_B,   2, 'Baixa infraestrutura', '{"in_agua_potavel":0,"qt_salas":3}');
$atr->execute($RUN, $INEP_SEM, 2, 'Baixa infraestrutura', '{"in_agua_potavel":0}');
$dbh->do(q{INSERT INTO analytics.cluster_execucoes (run_id, estado, parametros)
           VALUES (?, 'concluida', '{"algorithm":"kmeans","clusters":2,"features":["qt_salas"]}')}, {}, $ANTIGA);
$atr->execute($ANTIGA, $INEP_A, 1, 'Grupo 1', '{"qt_salas":12}');
$dbh->do(q{INSERT INTO analytics.cluster_execucoes (run_id, estado, expira_em)
           VALUES (?, 'concluida', now() - interval '1 day')}, {}, $VENCIDA);

subtest 'execução: parâmetros, universo e contagens' => sub {
  my $r = $t->get_ok("/api/cluster/execucoes/$RUN")->status_is(200)->tx->res->json;
  is $r->{run_id}, $RUN, 'run_id';
  is $r->{recorte}{codigo_ibge}, '6000281', 'recorte';
  is $r->{parametros}{clusters}, 2, 'parâmetros';
  is $r->{universo}{n_inativas}, 1, 'inativas (do backend)';
  is $r->{universo}{n_agrupadas}, 3, 'agrupadas (do R)';
  is $r->{n_atribuicoes}, 3, 'três escolas gravadas';
  is $r->{n_no_mapa}, 2, 'duas com coordenada';
  like $r->{expira_em}, qr/^\d{4}-\d{2}-\d{2}$/, 'validade';
};

subtest 'mapa da execução: só quem tem coordenada' => sub {
  my $g = $t->get_ok("/api/cluster/execucoes/$RUN/escolas")->status_is(200)->tx->res->json;
  my %grupo = map { $_->{properties}{co_entidade} => $_->{properties}{cluster_id} } @{ $g->{features} };
  is \%grupo, { $INEP_A => 1, $INEP_B => 2 }, 'A no 1, B no 2, sem ponto fora';
};

subtest 'CSV: uma linha por escola, indicadores na ordem dos parâmetros' => sub {
  my $tx = $t->get_ok("/api/cluster/execucoes/$RUN/csv")->status_is(200)
    ->header_like('Content-Type' => qr{text/csv})
    ->header_like('Content-Disposition' => qr/"agrupamento-censo2025-ideb2023-\Q$RUN\E\.csv"/)->tx;
  my $txt = decode('UTF-8', $tx->res->body);
  $txt =~ s/^\x{FEFF}//;
  my @l = split /\r\n/, $txt;
  is $l[0], 'inep;escola;municipio;uf;rede;grupo;rotulo;in_agua_potavel;qt_salas;ano_censo;ano_ideb;etapa_ideb',
    'cabeçalho com a versão dos dados no fim';
  is scalar @l, 4, 'cabeçalho + 3 escolas';
  is $l[1], qq{$INEP_A;"Escola Alfa; Teste";Cidade Teste;XX;Municipal;1;Alta infraestrutura;1;12,5;2025;2023;},
    'grupo 1 primeiro, ";" entre aspas, decimal com vírgula';
  like $l[3], qr/^\Q$INEP_SEM\E;.*;0;;2025;2023;$/, 'indicador sem valor fica vazio; versão em toda linha';
};

subtest 'CSV de execução antiga, sem a versão dos dados' => sub {
  my $tx = $t->get_ok("/api/cluster/execucoes/$ANTIGA/csv")->status_is(200)
    ->header_like('Content-Disposition' => qr/"agrupamento-\Q$ANTIGA\E\.csv"/)->tx;
  my $txt = decode('UTF-8', $tx->res->body);
  $txt =~ s/^\x{FEFF}//;
  my @l = split /\r\n/, $txt;
  is $l[0], 'inep;escola;municipio;uf;rede;grupo;rotulo;qt_salas;ano_censo;ano_ideb;etapa_ideb', 'mesmas colunas';
  is $l[1], qq{$INEP_A;"Escola Alfa; Teste";Cidade Teste;XX;Municipal;1;Grupo 1;12;;;}, 'anos vazios';
};

subtest 'inexistente, inválida e vencida dão 404' => sub {
  $t->get_ok('/api/cluster/execucoes/run_1_ffff')->status_is(404);
  $t->get_ok('/api/cluster/execucoes/qualquer')->status_is(404);
  $t->get_ok("/api/cluster/execucoes/$VENCIDA")->status_is(404)->json_like('/error' => qr/90 dias/);
  $t->get_ok("/api/cluster/execucoes/$VENCIDA/csv")->status_is(404);
};

subtest 'limpeza apaga só as vencidas, com as atribuições' => sub {
  my $n = $t->app->model('Cluster')->limpar_execucoes_vencidas;
  ok $n >= 1, 'apagou a vencida';
  ok !$dbh->selectrow_array('SELECT 1 FROM analytics.cluster_execucoes WHERE run_id = ?', {}, $VENCIDA), 'vencida saiu';
  is $dbh->selectrow_array('SELECT count(*) FROM analytics.cluster_atribuicoes WHERE run_id = ?', {}, $RUN), 3,
    'a válida ficou';
};

done_testing;
