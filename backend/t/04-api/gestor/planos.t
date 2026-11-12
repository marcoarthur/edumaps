# t/04-api/gestor/planos.t
# Planos de gestão da escola (#369, épico #368): CRUD de plano, objetivos,
# metas e ações; autorização por escola; plano encerrado só leitura (e
# reabertura); arquivamento; ação atrasada derivada; auditoria.
# Só roda onde a change planos_gestao foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('clean.planos_gestao')");

my $INEP   = '77777770';
my $OUTRA  = '66666670';
my $SENHA  = 'senha123';
my $EMAIL  = sprintf 'planos.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'planos.b.%d@edumaps.test', $$;
my ($token, $out_token);

if ($has_tables) {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
    $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade)
              VALUES (2025, ?, ?)', {}, $inep, "Escola Planos $inep");
  }
}

END {
  return if !$has_tables;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $_) for $EMAIL, $OEMAIL;
}

my $auth  = sub { { Authorization => "Bearer $token" } };
my $outro = sub { { Authorization => "Bearer $out_token" } };
my $base  = "/api/gestor/$INEP/planos";

skip_all('clean.planos_gestao ausente (migration nao aplicada)') unless $has_tables;

subtest 'setup: gestor da escola + gestor de outra escola' => sub {
  for my $g ([ $INEP, $EMAIL, \$token ], [ $OUTRA, $OEMAIL, \$out_token ]) {
    my ($inep, $email, $ref) = @$g;
    $t->post_ok('/api/gestor/pesquisas/perfil', json => {
      cod_inep => $inep, nome => "Gestor $inep", email => $email, senha => $SENHA,
    })->status_is(200);
    $$ref = $t->post_ok('/api/gestor/login', json => { email => $email, senha => $SENHA })
      ->status_is(200)->tx->res->json->{token};
    ok $$ref, "login $inep";
  }
};

my ($plano_id, $obj1, $obj2, $meta_id, $acao_id);

subtest 'sem sessão: 401; outra escola: 403' => sub {
  $t->get_ok($base)->status_is(401);
  $t->get_ok($base, $outro->())->status_is(403);
  $t->post_ok($base, $outro->(), json => { tipo => 'acao', titulo => 'X' })->status_is(403);
};

subtest 'criar plano: validação e criação' => sub {
  $t->post_ok($base, $auth->(), json => { titulo => 'Sem tipo' })
    ->status_is(400)->json_is('/campos/tipo' => 'obrigatório');
  $t->post_ok($base, $auth->(), json => { tipo => 'pdde', titulo => 'Tipo errado' })
    ->status_is(400)->json_like('/campos/tipo' => qr/use: gestao/);
  $t->post_ok($base, $auth->(), json => { tipo => 'acao', titulo => 'X', inicio => '2026-02-30' })
    ->status_is(400)->json_is('/campos/inicio' => 'data inexistente');
  $t->post_ok($base, $auth->(), json => { tipo => 'acao', titulo => 'X', inicio => '2026-06-01', fim => '2026-01-01' })
    ->status_is(400)->json_like('/error' => qr/fim do plano/);
  $t->post_ok($base, $auth->(), json => { tipo => 'acao', titulo => 'X', foo => 1 })
    ->status_is(400)->json_is('/campos/foo' => 'campo desconhecido');

  my $j = $t->post_ok($base, $auth->(), json => {
    tipo => 'acao', titulo => 'Plano de ação 2026', inicio => '2026-02-01', fim => '2026-12-15',
  })->status_is(201)->json_is('/situacao' => 'rascunho')->json_is('/objetivos' => [])
    ->json_is('/alertas_ativos' => Mojo::JSON::true)->tx->res->json;
  $plano_id = $j->{id};
  ok $plano_id, 'plano criado';
};

subtest 'objetivos, metas e ações' => sub {
  $obj1 = $t->post_ok("$base/$plano_id/objetivos", $auth->(), json => { titulo => 'Melhorar a aprendizagem' })
    ->status_is(201)->json_is('/ordem' => 1)->tx->res->json->{id};
  $obj2 = $t->post_ok("$base/$plano_id/objetivos", $auth->(), json => { titulo => 'Reduzir faltas' })
    ->status_is(201)->json_is('/ordem' => 2)->tx->res->json->{id};

  $meta_id = $t->post_ok("$base/$plano_id/metas", $auth->(), json => {
    objetivo_id => $obj1, descricao => 'IDEB anos iniciais', sentido => 'aumentar',
    linha_base => '5,2', alvo => 6, prazo => '2027-12-31',
  })->status_is(201)->json_is('/linha_base' => 5.2)->json_is('/alvo' => 6)->tx->res->json->{id};

  $t->post_ok("$base/$plano_id/metas", $auth->(), json => { objetivo_id => 999999999, descricao => 'X' })
    ->status_is(400, 'objetivo de outro plano/inexistente');

  $acao_id = $t->post_ok("$base/$plano_id/acoes", $auth->(), json => {
    objetivo_id => $obj1, meta_id => $meta_id, descricao => 'Reforço de leitura',
    responsavel => 'Coordenação', inicio => '2026-03-01', prazo => '2026-03-31',
    custo_previsto => '1.500,00', fonte_recurso => 'pdde',
  })->status_is(201)->json_is('/custo_previsto' => 1500)->json_is('/atrasada' => Mojo::JSON::true,
    'prazo vencido e não iniciada: atrasada (derivada)')->tx->res->json->{id};

  $t->post_ok("$base/$plano_id/acoes", $auth->(), json => {
    objetivo_id => $obj2, meta_id => $meta_id, descricao => 'Meta de outro objetivo',
  })->status_is(400)->json_like('/error' => qr/não pertence ao objetivo/);

  $t->post_ok("$base/$plano_id/acoes", $auth->(), json => {
    objetivo_id => $obj2, descricao => 'Busca ativa', prazo => '2099-01-01',
  })->status_is(201)->json_is('/atrasada' => Mojo::JSON::false);

  $t->post_ok("$base/$plano_id/acoes", $auth->(), json => {
    objetivo_id => $obj2, descricao => 'Custo negativo', custo_previsto => -1,
  })->status_is(400)->json_is('/campos/custo_previsto' => 'não pode ser negativo');
};

subtest 'detalhe: árvore e resumo' => sub {
  my $j = $t->get_ok("$base/$plano_id", $auth->())->status_is(200)->tx->res->json;
  is scalar @{ $j->{objetivos} }, 2, 'dois objetivos, em ordem';
  is $j->{objetivos}[0]{titulo}, 'Melhorar a aprendizagem';
  is scalar @{ $j->{objetivos}[0]{metas} }, 1, 'meta no objetivo 1';
  is scalar @{ $j->{objetivos}[1]{acoes} }, 1, 'ação no objetivo 2';
  is($j->{resumo}, { n_objetivos => 2, n_metas => 1, n_acoes => 2,
    n_acoes_concluidas => 0, n_acoes_atrasadas => 1,
    progresso => { valor => undef, n_medidas => 0, n_metas => 1 } }, 'resumo (meta sem medição: progresso vazio, não 0)');

  my $lista = $t->get_ok($base, $auth->())->status_is(200)->tx->res->json->{planos};
  is scalar @$lista, 1, 'lista com o plano';
  is $lista->[0]{resumo}{n_acoes_atrasadas}, 1, 'resumo na lista';

  $t->get_ok("/api/gestor/$OUTRA/planos/$plano_id", $outro->())->status_is(404,
    'o plano não aparece na escola do outro gestor');
};

subtest 'atualização parcial e conclusão de ação' => sub {
  $t->put_ok("$base/$plano_id/acoes/$acao_id", $auth->(), json => { situacao => 'concluida' })
    ->status_is(200)->json_is('/situacao' => 'concluida')->json_is('/atrasada' => Mojo::JSON::false)
    ->json_is('/descricao' => 'Reforço de leitura', 'campos não enviados ficam');
  ok $t->tx->res->json->{concluida_em}, 'concluir grava a data';

  $t->put_ok("$base/$plano_id/acoes/$acao_id", $auth->(), json => { responsavel => undef })
    ->status_is(200)->json_is('/responsavel' => undef, 'null limpa');
  $t->put_ok("$base/$plano_id/acoes/$acao_id", $auth->(), json => { situacao => 'em_andamento' })
    ->status_is(200)->json_is('/concluida_em' => undef, 'reabrir a ação limpa a conclusão');
  $t->put_ok("$base/$plano_id/acoes/$acao_id", $auth->(), json => {})->status_is(400);

  $t->put_ok("$base/$plano_id/metas/$meta_id", $auth->(), json => { alvo => 6.5 })
    ->status_is(200)->json_is('/alvo' => 6.5)->json_is('/linha_base' => 5.2);

  # Meta muda de objetivo: a ação do objetivo antigo se solta da meta.
  $t->put_ok("$base/$plano_id/metas/$meta_id", $auth->(), json => { objetivo_id => $obj2 })->status_is(200);
  my $j = $t->get_ok("$base/$plano_id", $auth->())->tx->res->json;
  my ($acao) = grep { $_->{id} == $acao_id } map { @{ $_->{acoes} } } @{ $j->{objetivos} };
  is $acao->{meta_id}, undef, 'ação perdeu a meta que mudou de objetivo';
};

subtest 'encerrado é só leitura; reabrir; arquivar' => sub {
  $t->put_ok("$base/$plano_id", $auth->(), json => { situacao => 'encerrado' })
    ->status_is(200)->json_is('/situacao' => 'encerrado');
  $t->put_ok("$base/$plano_id", $auth->(), json => { titulo => 'Outro' })->status_is(409);
  $t->put_ok("$base/$plano_id", $auth->(), json => { situacao => 'vigente', titulo => 'Outro' })
    ->status_is(409, 'reabrir não vem com outra mudança');
  $t->post_ok("$base/$plano_id/objetivos", $auth->(), json => { titulo => 'Novo' })->status_is(409);
  $t->delete_ok("$base/$plano_id/acoes/$acao_id", $auth->())->status_is(409);

  $t->put_ok("$base/$plano_id", $auth->(), json => { situacao => 'vigente' })
    ->status_is(200)->json_is('/situacao' => 'vigente');

  my $aud = $t->get_ok("$base/$plano_id/auditoria", $auth->())->status_is(200)->tx->res->json->{auditoria};
  my %acoes = map { $_->{acao} => 1 } @$aud;
  ok $acoes{$_}, "auditoria registra '$_'" for qw(criado alterado encerrado reaberto);
  is $aud->[0]{acao}, 'reaberto', 'mais recente primeiro';
  ok $aud->[0]{gestor}, 'com o nome do gestor';

  $t->delete_ok("$base/$plano_id/objetivos/$obj1", $auth->())->status_is(200);
  my $j = $t->get_ok("$base/$plano_id", $auth->())->tx->res->json;
  is $j->{resumo}{n_objetivos}, 1, 'objetivo excluído (com as metas e ações dele)';

  $t->delete_ok("$base/$plano_id", $auth->())->status_is(200)->json_is('/arquivado' => Mojo::JSON::true);
  $t->get_ok("$base/$plano_id", $auth->())->status_is(404, 'arquivado some das rotas');
  is scalar @{ $t->get_ok($base, $auth->())->tx->res->json->{planos} }, 0, 'e da lista';
  my $arq = $t->get_ok("$base?arquivados=1", $auth->())->tx->res->json->{planos};
  is $arq->[0]{arquivado}, Mojo::JSON::true, '?arquivados=1 mostra';
  ok $dbh->selectrow_array('SELECT 1 FROM clean.planos_gestao WHERE id = ?', {}, $plano_id),
    'arquivar não apaga';
};

subtest 'documento do plano: só da própria escola' => sub {
  $t->post_ok($base, $auth->(), json => { tipo => 'ppp', titulo => 'PPP', documento_id => 999999999 })
    ->status_is(400)->json_like('/error' => qr/Documento não encontrado/);
};

done_testing;
