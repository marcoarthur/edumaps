package EduMaps::Plugin::Idempotencia;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use Digest::SHA qw(sha256_hex);
use Mojo::Util qw(encode decode);

# ============================================================================
# IDEMPOTÊNCIA DOS POSTs AUTENTICADOS — #416
# ============================================================================
#
# Complemento da trava de interface (PR #415). O cliente manda o cabeçalho
# `Idempotency-Key` nos POSTs; a chave vale por conta (gestor_id), em
# clean.idempotencia:
#
#   - chave nova: grava "em andamento" e segue para o controller;
#   - chave já concluída, mesma rota e mesmo corpo: devolve a resposta
#     guardada, sem criar de novo (cabeçalho `Idempotent-Replayed: true`);
#   - chave ainda em andamento: 409;
#   - a mesma chave com outra rota ou outro corpo: 422 (nunca devolve, calada,
#     a resposta de outro envio);
#   - sem o cabeçalho: nada muda.
#
# No fim do pedido (after_dispatch): resposta 2xx fica guardada; qualquer outra
# apaga o registro, para a nova tentativa ser processada.
#
# Ponto de entrada único: os portões de login (gestor#_require_sessao,
# _require_rede, _require_admin e pesquisa#_require_gestor) terminam com
# `return $c->idempotencia_inicio;`, depois de pôr o gestor no stash.
#
# Validade: 10 min. Um "em andamento" com mais de 2 min conta como abandonado
# (o servidor caiu no meio). As chaves vencidas da conta são apagadas a cada
# envio novo, sem job.

our $VALIDADE  = 600;
our $ABANDONO  = 120;
our $MAX_CORPO = 1_048_576;    # resposta maior não é guardada (só o status)
my  $CHAVE_OK  = qr/\A[A-Za-z0-9_-]{8,128}\z/;

sub register ($self, $app, $conf = {}) {
  $app->helper(idempotencia_inicio => \&inicio);
  $app->hook(after_dispatch => \&_fim);
}

sub _dbh ($c) { $c->app->schema->storage->dbh }

sub _corpo_hash ($c) {
  my $tipo = $c->req->headers->content_type // '';
  # multipart: o navegador sorteia o boundary a cada envio, o hash nunca bateria
  return 'multipart' if $tipo =~ m{^multipart/}i;
  return sha256_hex($c->req->body // '');
}

# Devolve 1 para seguir a cadeia do under; 0 quando já respondeu. Falha do
# banco aqui não derruba o envio: segue sem a trava (como sem o cabeçalho).
sub inicio ($c) {
  my $r = eval { _inicio($c) };
  return $r if defined $r;
  $c->app->log->warn("idempotencia: seguindo sem a trava: $@");
  return 1;
}

sub _inicio ($c) {
  return 1 unless $c->req->method eq 'POST';
  my $chave = $c->req->headers->header('Idempotency-Key');
  return 1 unless defined $chave && length $chave;
  return 1 if $c->stash('idempotencia');    # já tratado neste pedido

  unless ($chave =~ $CHAVE_OK) {
    $c->render(json => { error => 'Chave de envio inválida.' }, status => 400);
    return 0;
  }
  my $gestor_id = ($c->stash('gestor') // {})->{id} or return 1;

  my $dbh  = _dbh($c);
  my $rota = 'POST ' . $c->req->url->path->to_string;
  my $hash = _corpo_hash($c);

  $dbh->do(q{
    DELETE FROM clean.idempotencia
     WHERE gestor_id = ?
       AND (criado_em < NOW() - make_interval(secs => ?)
            OR (status IS NULL AND criado_em < NOW() - make_interval(secs => ?)))
  }, undef, $gestor_id, $VALIDADE, $ABANDONO);

  my $nova = $dbh->do(q{
    INSERT INTO clean.idempotencia (gestor_id, chave, rota, corpo_hash)
    VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING
  }, undef, $gestor_id, $chave, $rota, $hash);

  if ($nova && $nova > 0) {
    $c->stash(idempotencia => { gestor_id => $gestor_id, chave => $chave });
    return 1;
  }

  my $reg = $dbh->selectrow_hashref(q{
    SELECT rota, corpo_hash, status, resposta FROM clean.idempotencia
     WHERE gestor_id = ? AND chave = ?
  }, undef, $gestor_id, $chave);
  # sumiu entre o INSERT e o SELECT (o outro pedido falhou): segue sem chave
  return 1 unless $reg;

  if ($reg->{rota} ne $rota || $reg->{corpo_hash} ne $hash) {
    $c->render(json => { error => 'Este envio já foi feito com outros dados. Recarregue a página.' },
      status => 422);
    return 0;
  }
  unless (defined $reg->{status}) {
    $c->render(json => { error => 'Este envio ainda está sendo processado.' }, status => 409);
    return 0;
  }

  $c->res->headers->header('Idempotent-Replayed' => 'true');
  if (defined $reg->{resposta} && length $reg->{resposta}) {
    $c->res->headers->content_type('application/json;charset=UTF-8');
    $c->render(data => encode('UTF-8', $reg->{resposta}), status => $reg->{status});
  }
  else {
    $c->render(data => '', status => $reg->{status});
  }
  return 0;
}

sub _fim ($c) {
  my $reg = $c->stash('idempotencia') or return;
  $c->stash(idempotencia => undef);
  my $code = $c->res->code // 0;
  my $dbh  = _dbh($c);
  eval {
    if ($code >= 200 && $code < 300) {
      my $tipo  = $c->res->headers->content_type // '';
      my $corpo = $c->res->body;
      $corpo = undef unless $tipo =~ m{json}i && defined $corpo && length($corpo) <= $MAX_CORPO;
      $corpo = decode('UTF-8', $corpo) // $corpo if defined $corpo;   # bytes → texto
      $dbh->do('UPDATE clean.idempotencia SET status = ?, resposta = ? WHERE gestor_id = ? AND chave = ?',
        undef, $code, $corpo, $reg->{gestor_id}, $reg->{chave});
    }
    else {
      $dbh->do('DELETE FROM clean.idempotencia WHERE gestor_id = ? AND chave = ?',
        undef, $reg->{gestor_id}, $reg->{chave});
    }
    1;
  } or $c->app->log->warn("idempotencia: não foi possível concluir a chave: $@");
}

1;
