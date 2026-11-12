# t/04-api/gestor/planos_evidencias.t
# #372 (épico #368, RF-006): evidências das ações e metas dos planos.
#
#   * origens: só reuniões (não canceladas) e versões de documento da escola;
#   * ata, documento e nota ligados a ação ou meta, com o título da origem;
#   * validação: dono único, campos por tipo, duplicata 409;
#   * outra escola: 403 na reunião e no documento;
#   * origem apagada: a evidência fica, com "origem removida" e o título antigo;
#   * plano encerrado: 409; exclusão e auditoria.
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

my $INEP   = '77777772';
my $OUTRA  = '77777773';
my $EMAIL  = sprintf 'planos.ev.%d@edumaps.test', $$;
my $SENHA  = 'senha123';

my $limpar = sub {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escola_documentos WHERE cod_inep = ?', {}, $inep);
  }
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
};
$limpar->();
$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade) VALUES (2025, ?, ?)',
  {}, $INEP, "Escola Evidências $INEP");
END { return unless $has; $limpar->(); $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL) }

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestor Evidências', email => $EMAIL, senha => $SENHA })->status_is(200);
my $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
my $auth = { Authorization => "Bearer $token" };
my $base = "/api/gestor/$INEP/planos";
my ($gid) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

# --- origens: reuniões e versões de documento (desta escola e de outra) -----
my $reuniao = sub ($inep, $titulo, $status = 'realizada', $ata = undef) {
  $dbh->selectrow_array(
    q{INSERT INTO clean.reunioes (cod_inep, gestor_id, titulo, quando, status, ata_texto)
      VALUES (?, ?, ?, NOW() - interval '3 days', ?, ?) RETURNING id}, {}, $inep, $gid, $titulo, $status, $ata);
};
my $versao = sub ($inep, $nome, $n = 1) {
  my ($doc) = $dbh->selectrow_array(
    'SELECT id FROM clean.escola_documentos WHERE cod_inep = ? AND nome = ?', {}, $inep, $nome);
  ($doc) = $dbh->selectrow_array(
    'INSERT INTO clean.escola_documentos (cod_inep, gestor_id, nome) VALUES (?, ?, ?) RETURNING id',
    {}, $inep, $gid, $nome) unless $doc;
  my ($v) = $dbh->selectrow_array(
    q{INSERT INTO clean.escola_documentos_versoes (documento_id, versao, caminho, nome_original, sha1)
      VALUES (?, ?, 'x/y', ?, repeat('a', 40)) RETURNING id}, {}, $doc, $n, "$nome.pdf");
  return ($v, $doc);
};

my $r_conselho = $reuniao->($INEP, 'Conselho escolar de março', 'realizada', 'Aprovado o plano.');
my $r_cancel   = $reuniao->($INEP, 'Reunião cancelada', 'cancelada');
my $r_outra    = $reuniao->($OUTRA, 'Reunião da outra escola');
my ($v_ppp1, $doc_ppp) = $versao->($INEP, 'PPP 2026', 1);
my ($v_ppp2)           = $versao->($INEP, 'PPP 2026', 2);
my ($v_outra)          = $versao->($OUTRA, 'Documento alheio');

$t->get_ok("$base/evidencias/origens", $auth)->status_is(200);
my $o = $t->tx->res->json;
is [ map { $_->{id} } @{ $o->{reunioes} } ], [ $r_conselho ], 'origens: só reuniões da escola e não canceladas';
is $o->{reunioes}[0]{tem_ata}, Mojo::JSON::true, 'reunião com ata em texto: tem_ata';
is [ sort { $a <=> $b } map { $_->{versao_id} } @{ $o->{documentos} } ], [ $v_ppp1, $v_ppp2 ],
  'origens: todas as versões dos documentos da escola, e só dela';

$t->get_ok("/api/gestor/$OUTRA/planos/evidencias/origens", $auth)->status_is(403);

# --- plano com uma ação e uma meta ------------------------------------------
my $plano = $t->post_ok($base, $auth, json => { tipo => 'acao', titulo => 'Plano com evidências' })
  ->status_is(201)->tx->res->json->{id};
my $obj = $t->post_ok("$base/$plano/objetivos", $auth, json => { titulo => 'Aproximar as famílias' })
  ->status_is(201)->tx->res->json->{id};
my $meta = $t->post_ok("$base/$plano/metas", $auth, json => {
  objetivo_id => $obj, descricao => 'Presença nas reuniões', sentido => 'aumentar', linha_base => 30, alvo => 60 })
  ->status_is(201)->tx->res->json->{id};
my $acao = $t->post_ok("$base/$plano/acoes", $auth, json => { objetivo_id => $obj, descricao => 'Reunião bimestral' })
  ->status_is(201)->tx->res->json->{id};
my $ev = "$base/$plano/evidencias";

subtest 'ligar ata, documento e nota' => sub {
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'ata', reuniao_id => $r_conselho })
    ->status_is(201)
    ->json_is('/tipo' => 'ata')->json_is('/titulo' => 'Conselho escolar de março')
    ->json_is('/reuniao_id' => $r_conselho)->json_is('/origem_removida' => Mojo::JSON::false);

  $t->post_ok($ev, $auth, json => { meta_id => $meta, tipo => 'documento', documento_versao_id => $v_ppp1 })
    ->status_is(201)
    ->json_is('/titulo' => 'PPP 2026 (v1)')->json_is('/documento_id' => $doc_ppp)->json_is('/versao' => 1);

  $t->post_ok($ev, $auth, json => { meta_id => $meta, tipo => 'nota', texto => 'Lista de presença no mural.' })
    ->status_is(201)->json_is('/texto' => 'Lista de presença no mural.')->json_is('/titulo' => undef);

  my $j = $t->get_ok("$base/$plano", $auth)->status_is(200)->tx->res->json;
  my $o = $j->{objetivos}[0];
  is [ map { $_->{tipo} } @{ $o->{acoes}[0]{evidencias} } ], [ 'ata' ], 'detalhe: evidência na ação';
  is [ map { $_->{tipo} } @{ $o->{metas}[0]{evidencias} } ], [ 'documento', 'nota' ], 'detalhe: evidências na meta';
};

subtest 'validação' => sub {
  $t->post_ok($ev, $auth, json => { tipo => 'nota', texto => 'x' })->status_is(400);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, meta_id => $meta, tipo => 'nota', texto => 'x' })->status_is(400);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'ata' })->status_is(400)
    ->json_like('/error' => qr/reuniao_id/);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'nota', texto => 'x', reuniao_id => $r_conselho })
    ->status_is(400)->json_like('/error' => qr/não usa reuniao_id/);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'video' })->status_is(400);
  $t->post_ok($ev, $auth, json => { acao_id => 999999999, tipo => 'nota', texto => 'x' })->status_is(400)
    ->json_like('/error' => qr/Ação não encontrada/);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'ata', reuniao_id => 999999999 })->status_is(400);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'ata', reuniao_id => $r_conselho })
    ->status_is(409)->json_like('/error' => qr/já está ligada/);
};

subtest 'outra escola: 403' => sub {
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'ata', reuniao_id => $r_outra })->status_is(403);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'documento', documento_versao_id => $v_outra })
    ->status_is(403);
  $t->post_ok("/api/gestor/$OUTRA/planos/$plano/evidencias", $auth,
    json => { acao_id => $acao, tipo => 'nota', texto => 'x' })->status_is(403);
};

subtest 'origem apagada: a evidência fica' => sub {
  $dbh->do('DELETE FROM clean.reunioes WHERE id = ?', {}, $r_conselho);
  $dbh->do('DELETE FROM clean.escola_documentos WHERE id = ?', {}, $doc_ppp);    # versões em cascata
  my $o = $t->get_ok("$base/$plano", $auth)->tx->res->json->{objetivos}[0];
  my ($ata) = @{ $o->{acoes}[0]{evidencias} };
  is $ata->{origem_removida}, Mojo::JSON::true, 'ata: origem removida';
  is $ata->{titulo}, 'Conselho escolar de março', 'ata: título guardado no vínculo';
  is $ata->{reuniao_id}, undef, 'ata: sem link';
  my ($doc) = grep { $_->{tipo} eq 'documento' } @{ $o->{metas}[0]{evidencias} };
  is $doc->{origem_removida}, Mojo::JSON::true, 'documento: origem removida';
  is $doc->{titulo}, 'PPP 2026 (v1)', 'documento: título guardado';
  my ($nota) = grep { $_->{tipo} eq 'nota' } @{ $o->{metas}[0]{evidencias} };
  is $nota->{origem_removida}, Mojo::JSON::false, 'nota nunca é origem removida';
};

subtest 'excluir, encerrado e auditoria' => sub {
  my $o = $t->get_ok("$base/$plano", $auth)->tx->res->json->{objetivos}[0];
  my ($nota) = grep { $_->{tipo} eq 'nota' } @{ $o->{metas}[0]{evidencias} };
  $t->delete_ok("$ev/$nota->{id}", $auth)->status_is(200)->json_is('/excluido' => Mojo::JSON::true);
  $t->delete_ok("$ev/$nota->{id}", $auth)->status_is(404);

  $t->put_ok("$base/$plano", $auth, json => { situacao => 'encerrado' })->status_is(200);
  $t->post_ok($ev, $auth, json => { acao_id => $acao, tipo => 'nota', texto => 'tarde demais' })->status_is(409);
  my ($ata) = @{ $o->{acoes}[0]{evidencias} };
  $t->delete_ok("$ev/$ata->{id}", $auth)->status_is(409);

  my $aud = $t->get_ok("$base/$plano/auditoria", $auth)->tx->res->json->{auditoria};
  my @ev = grep { $_->{entidade} eq 'evidencia' } @$aud;
  is scalar(grep { $_->{acao} eq 'criado' } @ev), 3, 'auditoria: três evidências criadas';
  is scalar(grep { $_->{acao} eq 'excluido' } @ev), 1, 'auditoria: uma excluída';

  # meta apagada leva as evidências junto (CASCADE), sem erro
  $t->put_ok("$base/$plano", $auth, json => { situacao => 'vigente' })->status_is(200);
  $t->delete_ok("$base/$plano/metas/$meta", $auth)->status_is(200);
  is $dbh->selectrow_array('SELECT count(*) FROM clean.planos_evidencias WHERE meta_id = ?', {}, $meta), 0,
    'meta excluída: evidências dela também';
};

done_testing;
