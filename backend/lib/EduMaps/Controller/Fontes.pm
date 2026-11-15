package EduMaps::Controller::Fontes;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use EduMaps::Fontes;

# GET /api/fontes — catálogo público das fontes (#428). Cache de 10 min por
# processo: anos e cargas mudam com uma carga nova, não a cada pedido.
my ($CACHE, $CACHE_EM) = (undef, 0);

sub index ($self) {
  if (!$CACHE || time - $CACHE_EM > 600) {
    $CACHE    = EduMaps::Fontes->resolver($self->app->schema->storage->dbh);
    $CACHE_EM = time;
  }
  $self->res->headers->cache_control('public, max-age=600');
  $self->render(json => $CACHE);
}

1;
