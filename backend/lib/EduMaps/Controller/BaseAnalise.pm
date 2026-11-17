package EduMaps::Controller::BaseAnalise;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;
use EduMaps::BaseAnalise;

# Base de análise (#439, RV-02): exportação pública, uma UF por vez.
#   GET /api/base-analise            catálogo dos blocos, anos e (com uf) o total de escolas
#   GET /api/base-analise/csv        a base (uma linha por escola em funcionamento)
#   GET /api/base-analise/dicionario o dicionário das colunas, com a fonte de cada uma

my $B = 'EduMaps::BaseAnalise';

sub _validar ($self, %o) {
  my $v = $self->validation;
  my $uf = $v->optional('uf', 'trim');
  $uf->in(@EduMaps::BaseAnalise::UFS);
  $v->optional('codigo_ibge', 'trim')->like(qr/^\d{7}$/);
  $v->optional('rede', 'trim')->in(map { $_->{id} } @EduMaps::BaseAnalise::REDES);
  $v->optional('blocos', 'trim')->like(qr/^[a-z_]+(,[a-z_]+)*$/);
  $v->optional('ano_ideb', 'trim')->like(qr/^\d{4}$/);
  return if $v->has_error;
  return { v => $v };
}

sub _recorte ($self, $v) {
  return {
    uf => $v->param('uf'),
    (defined $v->param('codigo_ibge') ? (codigo_ibge => $v->param('codigo_ibge')) : ()),
    (defined $v->param('rede') ? (rede => $v->param('rede')) : ()),
  };
}

# Blocos pedidos (os desconhecidos dão 400) e o ano do IDEB (o pedido, se
# existir, ou a edição mais recente).
sub _blocos_ano ($self, $v, $anos) {
  my %ok = map { $_ => 1 } $B->ids_blocos;
  my @blocos = grep { length } split /,/, ($v->param('blocos') // '');
  my @ruins = grep { !$ok{$_} } @blocos;
  return (undef, undef, 'Bloco desconhecido: ' . join(', ', @ruins)) if @ruins;
  my $ano = $v->param('ano_ideb');
  if (defined $ano) {
    return (undef, undef, "Sem IDEB em $ano") unless grep { $_ == $ano } @{ $anos->{ideb} };
  } else {
    $ano = $anos->{ideb}[0];
  }
  return (\@blocos, $ano);
}

sub _nome ($self, $prefixo, $v, $blocos, $anos, $ano_ideb) {
  my %quer = map { $_ => 1 } @$blocos;
  my @p = ($prefixo);
  push @p, $v->param('uf') if defined $v->param('uf');
  push @p, $v->param('codigo_ibge') if defined $v->param('codigo_ibge');
  push @p, $v->param('rede') if defined $v->param('rede');
  push @p, "censo$anos->{censo}" if defined $anos->{censo};
  push @p, "ideb$ano_ideb" if $quer{desempenho} && defined $ano_ideb;
  push @p, "inse$anos->{inse}" if $quer{inse} && defined $anos->{inse};
  push @p, $anos->{indices} if $quer{indices} && defined $anos->{indices};    # #465
  return join('-', @p) . '.csv';
}

sub _enviar_csv ($self, $nome, $conteudo) {
  $self->res->headers->content_type('text/csv; charset=utf-8');
  $self->res->headers->content_disposition(qq{attachment; filename="$nome"});
  $self->res->headers->cache_control('public, max-age=600');
  $self->render(data => Mojo::Util::encode('UTF-8', $conteudo));
}

sub index ($self) {
  my $ok = $self->_validar or return $self->bad_req;
  my $dbh = $self->app->schema->storage->dbh;
  my $anos = $B->anos($dbh);
  my $total = defined $ok->{v}->param('uf') ? $B->contar($dbh, $self->_recorte($ok->{v})) : undef;
  $self->res->headers->cache_control('public, max-age=600');
  $self->render(json => {
    blocos => $B->catalogo,
    redes  => \@EduMaps::BaseAnalise::REDES,
    ufs    => \@EduMaps::BaseAnalise::UFS,
    anos   => $anos,
    total  => $total,
  });
}

sub csv ($self) {
  my $ok = $self->_validar or return $self->bad_req;
  my $v = $ok->{v};
  return $self->render(json => { error => 'Informe a UF: a base sai uma UF por vez.' }, status => 400) unless defined $v->param('uf');
  my $dbh = $self->app->schema->storage->dbh;
  my $anos = $B->anos($dbh);
  my ($blocos, $ano_ideb, $erro) = $self->_blocos_ano($v, $anos);
  return $self->render(json => { error => $erro }, status => 400) if $erro;
  my ($cab, $linhas, $num) = $B->linhas($dbh, $self->_recorte($v), $blocos, $ano_ideb);
  $self->_enviar_csv($self->_nome('base-analise', $v, $blocos, $anos, $ano_ideb), $B->csv($cab, $linhas, $num));
}

sub dicionario ($self) {
  my $ok = $self->_validar or return $self->bad_req;
  my $v = $ok->{v};
  my $dbh = $self->app->schema->storage->dbh;
  my $anos = $B->anos($dbh);
  my ($blocos, $ano_ideb, $erro) = $self->_blocos_ano($v, $anos);
  return $self->render(json => { error => $erro }, status => 400) if $erro;
  my ($cab, $linhas) = $B->dicionario($dbh, $blocos, $ano_ideb);
  $self->_enviar_csv($self->_nome('base-analise-dicionario', $v, $blocos, $anos, $ano_ideb), $B->csv($cab, $linhas));
}

1;
