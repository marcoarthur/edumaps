# t/02-models/canal_segmentos.t
# Listas dinâmicas (issue #216 — Fase 3, onda 1), role Canal::Segmentos:
#
#   - validação dos critérios (listas 1..50 da escola, estado, email_confirmado,
#     datas YYYY-MM-DD com desde <= ate);
#   - CRUD com nome único por escola e isolamento por escola;
#   - resolução: união das listas, filtro por estado geral, e-mail confirmado
#     e data de entrada (America/Sao_Paulo); dedupe por e-mail; opt-out;
#   - listas excluídas (desativadas) depois → ignoradas e listadas na prévia;
#   - prévia com amostra mascarada (até 10).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh   = $t->app->schema->storage->dbh;
my $has   = $dbh->selectrow_array("SELECT to_regclass('clean.canal_segmentos')");
plan skip_all => 'migration canal_envios nao aplicada' unless $has;
my $model = $t->app->model('Canal');

my $INEP  = 99660000 + ($$ % 1000);
my $OUTRA = $INEP + 1000;
my $P     = sprintf '%04d', $$ % 10000;
my (%g, %l, %c);

sub mail ($n) { return "seg$n.$P\@exemplo.org" }

sub limpa {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.canal_segmentos WHERE cod_inep = ?', {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
               WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}
END { limpa() if $has }

sub contato ($inep, $nome, $email) {
  my ($id) = $dbh->selectrow_array(
    'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email) VALUES (?, ?, ?, ?) RETURNING id',
    {}, $inep, $g{$inep}, $nome, $email);
  return $id;
}
sub membro ($lista, $contato, %o) {
  $dbh->do(q{INSERT INTO clean.canal_lista_membros
               (lista_id, contato_id, origem, created_at, email_confirmado_em, email_confirmado_via)
             VALUES (?, ?, 'manual', COALESCE(?::timestamptz, NOW()), ?::timestamptz,
                     CASE WHEN ?::timestamptz IS NULL THEN NULL ELSE 'email' END)},
    {}, $lista, $contato, $o{em}, $o{confirmado}, $o{confirmado});
}

limpa();
for my $inep ($INEP, $OUTRA) {
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, "Escola $inep");
  ($g{$inep}) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $inep, 'Gestor Seg', "gestor.seg.$inep.$P\@edumaps.test");
}
for my $def ([A => $INEP, 1], [B => $INEP, 0], [X => $INEP, 0], [Z => $OUTRA, 0]) {
  my ($k, $inep, $exige) = @$def;
  $l{$k} = $model->criar_lista(cod_inep => $inep, gestor_id => $g{$inep}, nome => "Lista $k",
                               coleta => 'email', exige_confirmacao => $exige)->{id};
}
# Ana: A (confirmada) e B — duplicada; Bruno: A (pendente, entrou em 2026-01-10);
# Carla: B; Dora: sem e-mail (fora); Eva: X (lista será desativada).
$c{ana}   = contato($INEP, 'Ana',   '  ' . uc(mail(1)) . ' ');
$c{bruno} = contato($INEP, 'Bruno', mail(2));
$c{carla} = contato($INEP, 'Carla', mail(3));
$c{dora}  = contato($INEP, 'Dora',  undef);
$c{eva}   = contato($INEP, 'Eva',   mail(5));
$c{zeca}  = contato($OUTRA, 'Zeca', mail(9));
membro($l{A}, $c{ana}, confirmado => '2026-01-01T12:00:00Z', em => '2026-01-05T12:00:00Z');
membro($l{A}, $c{bruno}, em => '2026-01-10T12:00:00Z');
membro($l{B}, $c{ana}, em => '2026-02-01T12:00:00Z');
membro($l{B}, $c{carla}, em => '2026-02-10T02:00:00Z');   # 09/02 23h em São Paulo
membro($l{B}, $c{dora});
membro($l{X}, $c{eva});
membro($l{Z}, $c{zeca});

subtest 'máscara de e-mail' => sub {
  is $model->mascarar_email('joana@dominio.com'), 'j***@d***.com', 'formato do contrato';
  is $model->mascarar_email('a@b.org.br'), 'a***@b***.br', 'último rótulo do domínio';
  is $model->mascarar_email(undef), undef, 'undef';
};

subtest 'validação dos critérios' => sub {
  my $err = sub ($c) { $model->segmento_validar_criterios($INEP, $c)->{error} // 'ok' };
  like $err->(undef), qr/objeto/, 'não é objeto';
  like $err->({ listas => [] }), qr/listas/, 'listas vazia';
  like $err->({ listas => [ (1) x 51 ] }), qr/listas/, 'mais de 50';
  like $err->({ listas => ['x'] }), qr/inteiros/, 'id não inteiro';
  like $err->({ listas => [ $l{Z} ] }), qr/não é desta escola/, 'lista de outra escola';
  like $err->({ listas => [ $l{A} ], estado => ['bla'] }), qr/estado/, 'estado inválido';
  like $err->({ listas => [ $l{A} ], email_confirmado => 'talvez' }), qr/email_confirmado/, 'booleano';
  like $err->({ listas => [ $l{A} ], inscritos_desde => '2026-13-01' }), qr/data/, 'data impossível';
  like $err->({ listas => [ $l{A} ], inscritos_desde => '2026-02-01', inscritos_ate => '2026-01-01' }),
    qr/anterior/, 'desde > ate';
  my $ok = $model->segmento_validar_criterios($INEP,
    { listas => [ $l{A}, "$l{B}", $l{A} ], estado => ['confirmado', 'confirmado'] });
  is $ok->{criterios}{listas}, [ $l{A}, $l{B} ], 'ids normalizados e únicos';
  is $ok->{criterios}{estado}, ['confirmado'], 'estado único';
  is $ok->{criterios}{email_confirmado}, undef, 'indiferente';
};

subtest 'resolução: união, dedupe, filtros' => sub {
  my $r = $model->resolver_destinatarios($INEP, [ $l{A}, $l{B} ]);
  is [ sort map { $_->{email} } @{ $r->{itens} } ], [ mail(1), mail(2), mail(3) ],
    'e-mails normalizados; sem e-mail fica fora';
  is $r->{duplicados}, 1, 'Ana nas duas listas: um duplicado';
  my ($ana) = grep { $_->{contato_id} == $c{ana} } @{ $r->{itens} };
  is $ana->{lista_id}, $l{A}, 'lista de origem = menor id';
  like $ana->{email_hash}, qr/^[0-9a-f]{64}$/, 'hash sha256';

  my $prev = sub ($crit) { $model->segmento_previa($INEP, { listas => [ $l{A}, $l{B} ], %$crit }) };
  is $prev->({})->{destinatarios}, 3, 'todos';
  is $prev->({ estado => ['confirmado'] })->{destinatarios}, 1, 'só confirmados (Ana em A)';
  is $prev->({ estado => ['pendente'] })->{destinatarios}, 1, 'pendente (Bruno; A exige)';
  is $prev->({ estado => ['nao_exigida'] })->{destinatarios}, 2, 'nao_exigida (B: Ana e Carla)';
  is $prev->({ email_confirmado => true })->{destinatarios}, 1, 'e-mail confirmado';
  is $prev->({ email_confirmado => false })->{destinatarios}, 3,
    'e-mail não confirmado (Ana conta pela lista B)';
  is $prev->({ inscritos_desde => '2026-01-06', inscritos_ate => '2026-02-09' })->{destinatarios}, 3,
    'datas inclusivas, fuso de São Paulo (Carla entrou em 09/02 local)';
  is $prev->({ inscritos_ate => '2026-01-31' })->{destinatarios}, 2, 'até janeiro: Ana e Bruno';
  is $prev->({ inscritos_desde => '2026-02-10' })->{destinatarios}, 0, 'nada depois de 10/02 local';
};

subtest 'opt-out por lista' => sub {
  my ($h) = $dbh->selectrow_array(q{SELECT encode(digest(?, 'sha256'), 'hex')}, {}, mail(1));
  $dbh->do(q{INSERT INTO clean.canal_optouts (lista_id, email_hash) VALUES (?, ?)}, {}, $l{B}, $h);
  my $r = $model->resolver_destinatarios($INEP, [ $l{A}, $l{B} ]);
  my ($ana) = grep { $_->{contato_id} == $c{ana} } @{ $r->{itens} };
  ok $ana->{optout}, 'saiu de uma das listas do alvo → opt-out';
  is $ana->{lista_id}, $l{B}, 'origem = lista de onde saiu';
  my $r2 = $model->resolver_destinatarios($INEP, [ $l{A} ]);
  ok !(grep { $_->{optout} } @{ $r2->{itens} }), 'alvo só com A: não saiu de A';
  is $model->segmento_previa($INEP, { listas => [ $l{A}, $l{B} ] })->{destinatarios}, 2,
    'prévia sem o opt-out';
  $dbh->do('DELETE FROM clean.canal_optouts WHERE lista_id = ?', {}, $l{B});
};

subtest 'CRUD, nome único, isolamento' => sub {
  my $s = $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => ' Confirmados ',
    criterios => { listas => [ $l{A}, $l{X} ], estado => ['confirmado'] });
  ok $s->{id}, 'criado';
  is $s->{nome}, 'Confirmados', 'nome com trim';
  is $s->{criterios}, { listas => [ $l{A}, $l{X} ], estado => ['confirmado'],
    email_confirmado => undef, inscritos_desde => undef, inscritos_ate => undef }, 'critérios';
  is $s->{listas}, [ { id => $l{A}, nome => 'Lista A', existe => true },
                     { id => $l{X}, nome => 'Lista X', existe => true } ], 'listas com nome';
  like $s->{created_at}, qr/Z$/, 'ISO UTC';

  is $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'Confirmados',
    criterios => { listas => [ $l{A} ] })->{status}, 409, 'nome repetido → 409';
  is $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => '',
    criterios => { listas => [ $l{A} ] })->{status}, 400, 'nome vazio → 400';
  is $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'Outra',
    criterios => { listas => [ $l{Z} ] })->{status}, 400, 'lista de outra escola → 400';

  my $s2 = $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'Abc',
    criterios => { listas => [ $l{B} ] });
  is [ map { $_->{nome} } @{ $model->segmentos_listar($INEP) } ], [qw(Abc Confirmados)], 'por nome';
  is $model->segmentos_listar($OUTRA), [], 'outra escola não vê';
  ok !$model->segmento_detalhe($OUTRA, $s->{id}), 'detalhe: isolado';
  ok !$model->segmento_atualizar($OUTRA, $s->{id}, nome => 'x', criterios => { listas => [ $l{Z} ] }),
    'atualizar: isolado';
  ok !$model->segmento_apagar($OUTRA, $s->{id}), 'apagar: isolado';
  ok !$model->segmento_previa_salvo($OUTRA, $s->{id}), 'prévia: isolada';

  is $model->segmento_atualizar($INEP, $s2->{id}, nome => 'Confirmados',
    criterios => { listas => [ $l{B} ] })->{status}, 409, 'PUT com nome de outro → 409';
  my $u = $model->segmento_atualizar($INEP, $s2->{id}, nome => 'Abc 2',
    criterios => { listas => [ $l{B} ], email_confirmado => false });
  is $u->{nome}, 'Abc 2', 'PUT';
  is $u->{criterios}{email_confirmado}, false, 'booleano JSON';
  is $model->segmento_apagar($INEP, $s2->{id}), { ok => 1 }, 'apagado';
  ok !$model->segmento_detalhe($INEP, $s2->{id}), 'sumiu';
};

subtest 'listas excluídas depois e prévia mascarada' => sub {
  my ($s) = grep { $_->{nome} eq 'Confirmados' } @{ $model->segmentos_listar($INEP) };
  $model->excluir_lista($INEP, $l{X});   # desativa
  my $d = $model->segmento_detalhe($INEP, $s->{id});
  is $d->{listas}[1], { id => $l{X}, nome => undef, existe => false }, 'excluída: existe false';

  my $p = $model->segmento_previa_salvo($INEP, $s->{id});
  is $p->{listas_ignoradas}, [ $l{X} ], 'listas ignoradas';
  is $p->{destinatarios}, 1, 'só Ana (confirmada em A)';
  is $p->{amostra}, [ { nome => 'Ana', email => 's***@e***.org' } ], 'amostra mascarada';

  # lista removida fisicamente também é ignorada (sem 400)
  my $tmp = $model->criar_lista(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'Temp')->{id};
  my $s3 = $model->segmento_criar(cod_inep => $INEP, gestor_id => $g{$INEP}, nome => 'Com temp',
    criterios => { listas => [ $l{B}, $tmp ] });
  $dbh->do('DELETE FROM clean.canal_listas WHERE id = ?', {}, $tmp);
  my $p3 = $model->segmento_previa_salvo($INEP, $s3->{id});
  is $p3->{listas_ignoradas}, [ $tmp ], 'removida: ignorada';
  is $p3->{destinatarios}, 2, 'B: Ana e Carla';

  # amostra limitada a 10
  for my $i (10 .. 22) {
    membro($l{B}, contato($INEP, "Pessoa $i", mail($i)));
  }
  my $p4 = $model->segmento_previa($INEP, { listas => [ $l{B} ] });
  is $p4->{destinatarios}, 15, 'contagem completa';
  is scalar @{ $p4->{amostra} }, 10, 'amostra de até 10';
  ok !(grep { $_->{email} !~ /^\w\*\*\*\@\w\*\*\*\.\w+$/ } @{ $p4->{amostra} }), 'todas mascaradas';
};

done_testing;
