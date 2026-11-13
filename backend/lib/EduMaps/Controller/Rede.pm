package EduMaps::Controller::Rede;
use Mojo::Base 'EduMaps::Controller::Gestor', -signatures;
use utf8;
use Scalar::Util qw(blessed);

# Visão da rede (#394, #375) — /api/rede. Sessão com papel `rede`
# (under gestor#_require_rede). Toda rota com escola confere, A CADA PEDIDO,
# que a escola está num vínculo ativo da conta (_escola_ok): revogar o vínculo
# corta o acesso na hora. Nenhuma rota daqui altera dado de plano.
#
#   GET /api/rede/me                 conta e vínculos ativos
#   GET /api/rede/escolas            escolas em atividade das redes da conta
#   GET /api/rede/escolas/:cod_inep  a escola, se for da rede (403 se não)
#   GET /api/rede/painel             planos das escolas da rede e totais (#396)
#   GET /api/rede/indicadores        metas comparáveis por indicador oficial (#397)
#   GET /api/rede/escolas/:cod_inep/planos                 planos não arquivados
#   GET /api/rede/escolas/:cod_inep/planos/:id/relatorio   relatório (só leitura)

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

sub painel($self) {
  my $escolas = $self->instantiate_model(model => 'Pesquisa')->rede_escolas($self->stash('gestor')->{id});
  $self->render(json => $self->model('Gestor')->rede_painel($escolas));
}

sub indicadores($self) {
  my $escolas = $self->instantiate_model(model => 'Pesquisa')->rede_escolas($self->stash('gestor')->{id});
  $self->render(json => $self->model('Gestor')->rede_indicadores($escolas));
}

sub escola_planos($self) {
  my $e = $self->_escola_ok or return;
  $self->render(json => { planos => $self->model('Gestor')->planos_listar($e->{co_entidade}) });
}

# O mesmo relatório que a escola imprime, só leitura (não sincroniza nada).
# "Emitido por" é o cargo da conta de rede que pediu.
sub relatorio($self) {
  my $e = $self->_escola_ok or return;
  my $out = eval {
    $self->model('Gestor')->plano_relatorio($e->{co_entidade}, $self->param('id'),
      $self->stash('gestor')->{id}, { somente_leitura => 1 });
  };
  if (my $err = $@) {
    if (blessed $err && $err->isa('EduMaps::Roles::Business::Gestor::Planos::Erro')) {
      return $self->render(json => { error => $err->mensagem }, status => $err->status);
    }
    $self->app->log->error("Rede relatorio: $err");
    return $self->render(json => { error => 'Não foi possível gerar o relatório.' }, status => 500);
  }
  $self->render(json => $out);
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
