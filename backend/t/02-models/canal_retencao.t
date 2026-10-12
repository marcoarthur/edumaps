# t/02-models/canal_retencao.t
# Retenção (issue #214 — Fase 2, RF-207), Canal::Exclusao::retencao_executar:
# três regras com datas manipuladas (UPDATE de created_at/desativada_em):
#
#   metadados      ip_anon/user_agent NULL só nas inscrições antigas;
#   pendentes      só inscritos nunca confirmados de lista que exige, sem
#                  inscrição recente, sem confirmação noutra lista, fora de
#                  lista ativa sem exigência, nascidos da autoinscrição;
#   lista_inativa  membros de lista desativada há mais que o prazo, exceto
#                  quem está noutra lista ativa;
#
# linha de resumo (cod_inep 0) por regra MESMO com zero + linha por escola
# afetada; idempotência; última execução; config (defaults, prazos < 1).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh   = $t->app->schema->storage->dbh;
my $has   = $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')")
         && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model = $t->app->model('Canal');
plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;

my $INEP = 99580000 + ($$ % 1000);
my $P    = sprintf '%04d', $$ % 10000;
my ($gestor_id, %lista, %tk);
my ($ex_max) = $dbh->selectrow_array('SELECT COALESCE(max(id), 0) FROM clean.canal_exclusoes');

sub limpa {
  $dbh->do('DELETE FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_exclusoes WHERE cod_inep = 0 AND origem = 'retencao' AND id > ?},
           {}, $ex_max);
  $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
             WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
             WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
             WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.retencao.%'});
}
END { limpa() if $has }

sub inscreve ($l, $nome, $n) {
  my $r = $model->registrar_inscricao(token => $tk{$l}, consentimento => 1, nome => $nome,
    telefone => "1191${P}0$n", ip_anon => "ip-$n", user_agent => "ua-$n");
  die "inscrição falhou: " . ($r->{reason} // '?') unless $r->{ok};
  return $r;
}
sub envelhece ($r, $dias) {
  $dbh->do(q{UPDATE clean.canal_inscricoes SET created_at = NOW() - make_interval(days => ?)
              WHERE contato_id = ?}, {}, $dias, $r->{contato_id});
  $dbh->do(q{UPDATE clean.canal_lista_membros SET created_at = NOW() - make_interval(days => ?)
              WHERE contato_id = ?}, {}, $dias, $r->{contato_id});
}
sub contato ($r) {
  return $dbh->selectrow_hashref('SELECT nome, telefone FROM clean.contatos WHERE id = ?',
                                 {}, $r->{contato_id});
}
sub n_membros ($r) {
  return $dbh->selectrow_array('SELECT count(*) FROM clean.canal_lista_membros WHERE contato_id = ?',
                               {}, $r->{contato_id}) + 0;
}
sub linhas_escola ($regra) {
  return $dbh->selectall_arrayref(q{SELECT contatos, inscricoes, membros FROM clean.canal_exclusoes
      WHERE cod_inep = ? AND origem = 'retencao' AND regra = ? ORDER BY id}, { Slice => {} },
      $INEP, $regra);
}

limpa();

subtest 'config: defaults e prazos inválidos' => sub {
  is $model->retencao_config,
     { enabled => 1, metadados_dias => 90, pendentes_dias => 180, listas_inativas_meses => 12 },
     'defaults';
  $model->config_put('canais.retencao.enabled', 'false', 't');
  $model->config_put('canais.retencao.metadados_dias', '30', 't');
  $model->config_put('canais.retencao.pendentes_dias', '0', 't');
  my $c = $model->retencao_config;
  is [ @$c{qw(enabled metadados_dias pendentes_dias)} ], [0, 30, 180], 'lidos; prazo 0 → default';
  my $pub = $model->retencao_publica;
  ok !$pub->{enabled}, 'enabled falso (booleano)';
  ok $model->is_config_key("canais.retencao.$_"), "folha $_"
    for qw(enabled metadados_dias pendentes_dias listas_inativas_meses);
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.retencao.%'});
};

my %p;
subtest 'setup' => sub {
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola Retenção');
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Retenção', "gestor.retencao.$$\@edumaps.test");
  for my $def ([P => 1], [N => 0], [I => 0], [J => 0], [K => 0]) {
    my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id,
      nome => "Lista $def->[0]", exige_confirmacao => $def->[1]);
    $lista{ $def->[0] } = $l->{id};
    $tk{ $def->[0] } = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id},
                                            gestor_id => $gestor_id)->{token};
  }

  # pendentes (lista P exige)
  $p{x1} = inscreve(P => 'Pendente Antigo', 1);  envelhece($p{x1}, 200);
  $p{x2} = inscreve(P => 'Confirmado Antigo', 2); envelhece($p{x2}, 200);
  $dbh->do(q{UPDATE clean.canal_lista_membros SET confirmado_em = NOW() - interval '199 days',
             confirmado_via = 'telegram' WHERE contato_id = ?}, {}, $p{x2}{contato_id});
  $p{x3} = inscreve(P => 'Em Lista Livre', 3);
  inscreve(N => 'Em Lista Livre', 3);           envelhece($p{x3}, 200);
  $p{x4} = inscreve(P => 'Pendente Recente', 4); envelhece($p{x4}, 10);
  # contato da agenda (existia antes da inscrição)
  my ($ag) = $dbh->selectrow_array(q{INSERT INTO clean.contatos (cod_inep, gestor_id, nome, telefone)
     VALUES (?, ?, 'Contato da Agenda', ?) RETURNING id}, {}, $INEP, $gestor_id, "1191${P}05");
  $p{x5} = inscreve(P => 'Contato da Agenda', 5); envelhece($p{x5}, 200);
  is $p{x5}{contato_id}, $ag, 'agenda reusada';

  # lista inativa (I antiga, K recente; J ativa)
  $p{y1} = inscreve(I => 'Só na Inativa', 6);
  $p{y2} = inscreve(I => 'Também na Ativa', 7);
  inscreve(J => 'Também na Ativa', 7);
  $p{y3} = inscreve(K => 'Inativa Recente', 8);
  $model->excluir_lista($INEP, $lista{$_}) for qw(I K);
  $dbh->do(q{UPDATE clean.canal_listas SET desativada_em = NOW() - interval '13 months'
              WHERE id = ?}, {}, $lista{I});
  $dbh->do(q{UPDATE clean.canal_listas SET desativada_em = NOW() - interval '11 months'
              WHERE id = ?}, {}, $lista{K});

  # metadados: inscrição antiga (100 dias) e recente
  $p{m1} = inscreve(J => 'Metadado Antigo', 9);
  $dbh->do(q{UPDATE clean.canal_inscricoes SET created_at = NOW() - interval '100 days'
              WHERE id = ?}, {}, $p{m1}{inscricao_id});
  ok 1, 'cenário montado';
};

subtest 'primeira execução: três regras' => sub {
  my $r = $model->retencao_executar;
  ok !$r->{$_}{erro}, "regra $_ sem erro" for qw(metadados pendentes lista_inativa);

  # metadados: 100d (m1) + as quatro de 200d (x1, x2, x3 em P e N, x5) = 6
  my $meta = $dbh->selectall_hashref(q{SELECT i.id, i.ip_anon, i.user_agent, i.nome
      FROM clean.canal_inscricoes i JOIN clean.canal_listas l ON l.id = i.lista_id
      WHERE l.cod_inep = ?}, 'id', {}, $INEP);
  ok !defined $meta->{ $p{m1}{inscricao_id} }{ip_anon} && !defined $meta->{ $p{m1}{inscricao_id} }{user_agent},
    'metadados antigos apagados';
  is $meta->{ $p{m1}{inscricao_id} }{nome}, 'Metadado Antigo', 'resto da inscrição intacto';
  is $meta->{ $p{x4}{inscricao_id} }{ip_anon}, 'ip-4', 'recente intacto';
  is linhas_escola('metadados'), [{ contatos => 0, inscricoes => 6, membros => 0 }],
    'registro da escola (metadados)';

  # pendentes
  is contato($p{x1}), { nome => '[removido]', telefone => undef }, 'pendente antigo anonimizado';
  is n_membros($p{x1}), 0, '... e fora das listas';
  is contato($p{x2})->{nome}, 'Confirmado Antigo', 'confirmado preservado';
  is contato($p{x3})->{nome}, 'Em Lista Livre', 'em lista ativa sem exigência preservado';
  is contato($p{x4})->{nome}, 'Pendente Recente', 'recente preservado';
  is contato($p{x5})->{nome}, 'Contato da Agenda', 'contato da agenda preservado';
  is linhas_escola('pendentes'), [{ contatos => 1, inscricoes => 1, membros => 1 }],
    'registro da escola (pendentes)';

  # lista inativa
  is contato($p{y1}), { nome => '[removido]', telefone => undef }, 'membro da inativa anonimizado';
  is contato($p{y2})->{nome}, 'Também na Ativa', 'membro também de lista ativa preservado';
  is n_membros($p{y2}), 2, '... com as duas filiações';
  is contato($p{y3})->{nome}, 'Inativa Recente', 'lista desativada há menos do prazo preservada';
  is linhas_escola('lista_inativa'), [{ contatos => 1, inscricoes => 1, membros => 1 }],
    'registro da escola (lista_inativa)';

  ok $r->{pendentes}{contatos} >= 1 && $r->{lista_inativa}{contatos} >= 1
    && $r->{metadados}{inscricoes} >= 6, 'totais da execução';
  my $resumo = $dbh->selectall_arrayref(q{SELECT regra FROM clean.canal_exclusoes
      WHERE cod_inep = 0 AND origem = 'retencao' AND id > ? ORDER BY id}, {}, $ex_max);
  is [ map { $_->[0] } @$resumo ], [qw(metadados pendentes lista_inativa)], 'uma linha de resumo por regra';
};

subtest 'idempotência: segunda execução zera e registra mesmo assim' => sub {
  my ($antes) = $dbh->selectrow_array('SELECT max(id) FROM clean.canal_exclusoes');
  my $r = $model->retencao_executar;
  is [ map { $r->{$_}{contatos} + $r->{$_}{inscricoes} + $r->{$_}{membros} }
       qw(metadados pendentes lista_inativa) ], [0, 0, 0], 'nada a fazer';
  my $novas = $dbh->selectall_arrayref(q{SELECT cod_inep, regra, contatos, inscricoes, membros
      FROM clean.canal_exclusoes WHERE id > ? ORDER BY id}, { Slice => {} }, $antes);
  is $novas, [ map { { cod_inep => 0, regra => $_, contatos => 0, inscricoes => 0, membros => 0 } }
               qw(metadados pendentes lista_inativa) ], 'três linhas de resumo com zero';

  my $u = $model->retencao_ultima_execucao;
  like $u->{em}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'última execução: em';
  is [ @$u{qw(metadados pendentes listas_inativas)} ], [0, 0, 0], 'última execução: contagens';
  is contato($p{x2})->{nome}, 'Confirmado Antigo', 'preservados continuam';
};

subtest 'prazos da config são respeitados' => sub {
  # pendentes_dias = 5: o pendente de 10 dias passa a entrar
  $model->config_put('canais.retencao.pendentes_dias', '5', 't');
  my $r = $model->retencao_executar;
  is contato($p{x4})->{nome}, '[removido]', 'pendente de 10 dias com prazo de 5';
  is $model->retencao_ultima_execucao->{pendentes}, $r->{pendentes}{contatos}, 'última execução';
  ok $r->{pendentes}{contatos} >= 1, 'contado';
};

done_testing;
