# t/04-api/gestor/planos_relatorio.t
# #374 (épico #368, RF-009): dados do relatório de acompanhamento do plano.
#
#   * cabeçalho: escola (nome, município, UF), plano, período, data de emissão;
#   * meta oficial com fonte e ano; meta sem medição sem progresso (não 0%);
#   * ações agrupadas por situação (atrasada tem precedência);
#   * evidências contadas e presentes na árvore;
#   * sem dado pessoal além do responsável (nenhum e-mail/nome de gestor);
#   * outra escola 403, sem sessão 401, arquivado 404, encerrado continua.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.planos_evidencias')");
skip_all('clean.planos_evidencias ausente (migration nao aplicada)') unless $has;

my $INEP  = '77777774';
my $EMAIL = sprintf 'planos.rel.%d@edumaps.test', $$;
my $SENHA = 'senha123';

my $limpar = sub {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_matriculas WHERE co_entidade = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
};
$limpar->();
END { return unless $has; $limpar->(); $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL) }

$dbh->do(q{INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, no_municipio, sg_uf)
           VALUES (2025, ?, 'Escola Relatório', 'Cuiabá', 'MT')}, {}, $INEP);
$dbh->do('INSERT INTO clean.censo_matriculas (nu_ano_censo, co_entidade, qt_mat_bas) VALUES (2025, ?, 320)', {}, $INEP);

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestora Relatório', email => $EMAIL, senha => $SENHA })->status_is(200);
my $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
my $auth = { Authorization => "Bearer $token" };
my $base = "/api/gestor/$INEP/planos";

my $plano = $t->post_ok($base, $auth, json => {
  tipo => 'acao', titulo => 'Plano de ação 2026', inicio => '2026-02-01', fim => '2026-12-15' })
  ->status_is(201)->tx->res->json->{id};
my $obj = $t->post_ok("$base/$plano/objetivos", $auth, json => { titulo => 'Ampliar o atendimento' })
  ->status_is(201)->tx->res->json->{id};
$t->post_ok("$base/$plano/metas", $auth, json => {
  objetivo_id => $obj, descricao => 'Matrículas', indicador_codigo => 'matriculas_total',
  sentido => 'aumentar', alvo => 350 })->status_is(201);
my $manual = $t->post_ok("$base/$plano/metas", $auth, json => {
  objetivo_id => $obj, descricao => 'Frequência nas reuniões', sentido => 'aumentar', linha_base => 30, alvo => 60 })
  ->status_is(201)->tx->res->json->{id};

my $acao = sub ($descricao, %o) {
  $t->post_ok("$base/$plano/acoes", $auth, json => { objetivo_id => $obj, descricao => $descricao, %o })
    ->status_is(201)->tx->res->json->{id};
};
my $a_atrasada  = $acao->('Busca ativa', prazo => '2020-01-10', situacao => 'em_andamento', responsavel => 'Coordenação',
                          custo_previsto => 1500, fonte_recurso => 'pdde');
my $a_andamento = $acao->('Reforço', situacao => 'em_andamento', custo_previsto => 300.5);
$acao->('Mutirão', situacao => 'concluida', custo_previsto => 200, fonte_recurso => 'fundeb');
$acao->('Feira', situacao => 'cancelada', custo_previsto => 999, fonte_recurso => 'pdde');
$acao->('Visitas');
$t->post_ok("$base/$plano/evidencias", $auth, json => { acao_id => $a_atrasada, tipo => 'nota', texto => 'Visitas feitas em 12 casas.' })
  ->status_is(201);

my $r = $t->get_ok("$base/$plano/relatorio", $auth)->status_is(200)->tx->res->json;

is $r->{escola}, { cod_inep => $INEP + 0, nome => 'Escola Relatório', municipio => 'Cuiabá', uf => 'MT' }, 'escola';
like $r->{emitido_em}, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/, 'data de emissão';
is $r->{plano}{titulo}, 'Plano de ação 2026', 'plano';
is [ @{ $r->{plano} }{qw(inicio fim)} ], [ '2026-02-01', '2026-12-15' ], 'período';

my %metas = map { $_->{descricao} => $_ } @{ $r->{plano}{objetivos}[0]{metas} };
is $metas{'Matrículas'}{indicador}{fonte}, 'INEP — Censo Escolar', 'meta oficial: fonte';
is $metas{'Matrículas'}{atual}{ano_ref}, 2025, 'meta oficial: ano';
is $metas{'Frequência nas reuniões'}{progresso}, undef, 'meta sem medição: sem progresso';
is $metas{'Frequência nas reuniões'}{estado}, 'sem_medicao', 'meta sem medição: estado';
is $r->{plano}{resumo}{progresso}{n_medidas}, 1, '1 de 2 metas medidas';

my $g = $r->{acoes_por_situacao};
is { map { $_ => [ map { $_->{descricao} } @{ $g->{$_} } ] } keys %$g }, {
  atrasadas     => ['Busca ativa'],
  em_andamento  => ['Reforço'],
  nao_iniciadas => ['Visitas'],
  concluidas    => ['Mutirão'],
  canceladas    => ['Feira'],
}, 'ações por situação (atrasada antes de em andamento)';
is $g->{atrasadas}[0]{objetivo}, 'Ampliar o atendimento', 'ação traz o objetivo';
is $g->{atrasadas}[0]{responsavel}, 'Coordenação', 'responsável em texto livre';
is $r->{n_evidencias}, 1, 'evidências contadas';
is $g->{atrasadas}[0]{evidencias}[0]{texto}, 'Visitas feitas em 12 casas.', 'evidência na ação';

# custo previsto por fonte (#384): canceladas fora; sem custo contado à parte
is $r->{custos}, {
  por_fonte => [
    { fonte => 'pdde',          total => 1500,  n_acoes => 1 },
    { fonte => 'fundeb',        total => 200,   n_acoes => 1 },
    { fonte => 'nao_informada', total => 300.5, n_acoes => 1 },
  ],
  total             => 2000.5,
  n_acoes_sem_custo => 1,
}, 'custos por fonte (ordem das fontes; cancelada fora; Visitas sem custo)';
is $g->{atrasadas}[0]{custo_previsto}, 1500, 'ação traz o custo';
is $g->{atrasadas}[0]{fonte_recurso}, 'pdde', 'ação traz a fonte';

my $json = Mojo::JSON::encode_json($r);
unlike $json, qr/\Q$EMAIL\E|Gestora Relatório/, 'sem e-mail nem nome do gestor';

# encerrado: o relatório continua
$t->put_ok("$base/$plano", $auth, json => { situacao => 'encerrado' })->status_is(200);
$t->get_ok("$base/$plano/relatorio", $auth)->status_is(200)->json_is('/plano/situacao' => 'encerrado');

# acesso
$t->get_ok("$base/$plano/relatorio")->status_is(401);
$t->get_ok("/api/gestor/77777775/planos/$plano/relatorio", $auth)->status_is(403);
$t->get_ok("$base/999999999/relatorio", $auth)->status_is(404);
$t->put_ok("$base/$plano", $auth, json => { situacao => 'vigente' })->status_is(200);
$t->delete_ok("$base/$plano", $auth)->status_is(200);
$t->get_ok("$base/$plano/relatorio", $auth)->status_is(404);

done_testing;
