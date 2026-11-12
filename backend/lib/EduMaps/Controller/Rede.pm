package EduMaps::Controller::Rede;
use Mojo::Base 'EduMaps::Controller::Gestor', -signatures;
use utf8;

# Visão da rede (#394, #375) — /api/rede. Sessão com papel `rede`
# (under gestor#_require_rede). Toda rota com escola confere, A CADA PEDIDO,
# que a escola está num vínculo ativo da conta (_escola_ok): revogar o vínculo
# corta o acesso na hora. Nenhuma rota daqui altera dado de plano.
#
#   GET /api/rede/me                 conta e vínculos ativos
#   GET /api/rede/escolas            escolas em atividade das redes da conta
#   GET /api/rede/escolas/:cod_inep  a escola, se for da rede (403 se não)

sub me($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  $self->render(json => $model->rede_conta($self->stash('gestor')->{id}));
}

sub escolas($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  $self->render(json => { escolas => $model->rede_escolas($self->stash('gestor')->{id}) });
}

sub escola($self) {
  my $e = $self->_escola_ok or return;
  $self->render(json => {
    cod_inep  => $e->{co_entidade} + 0,
    nome      => $e->{no_entidade},
    municipio => $e->{no_municipio},
    uf        => $e->{sg_uf},
  });
}

# A escola de :cod_inep, se estiver num vínculo ativo da conta; senão 403.
sub _escola_ok($self) {
  my $e = $self->instantiate_model(model => 'Pesquisa')
    ->rede_escola($self->stash('gestor')->{id}, $self->param('cod_inep'));
  return $e if $e;
  $self->render(json => { error => 'Esta escola não é de uma rede da sua conta.' }, status => 403);
  return;
}

1;
