package EduMaps::Ingestion::App;
use Mojo::Base -base, -signatures;

use EduMaps::Schema;

# ---------------------------------------------------------------------------
# Contexto mínimo exigido pelos jobs de ingestão por `$self->app`.
# ---------------------------------------------------------------------------
#
# Os jobs usam APENAS `$self->app->schema->storage->dbh` — 20 usos em
# `Ingestion/Job/*`, contados. O único `app->helper` do pacote está no plugin
# `Ingestion/Job.pm`, que nenhuma subclasse de job chama. Ou seja: arrancar a
# aplicação Mojolicious inteira para correr um loader significaria pagar
# Minion, plugins, middlewares, handlers e o arranque de rotas para aceder a
# uma ligação de base de dados.
#
# `Base.pm` declara `has app => sub { die "app must be set" }`, portanto um
# loader construído sem `app` morre logo que toque na BD — que é exactamente o
# que acontecia via `ingestion_runner.pl` (ver t/05-tasks/ingestion_runner.t).
#
# A ligação é lazy: instanciar este objeto não abre socket nenhum. Só o
# primeiro acesso a `->schema` invoca `Schema->go()`, que lê `EDUMAPS_CONF`
# ou `./edu_maps.conf` — logo tem de ser chamado a partir de `backend/`.

has schema => sub { EduMaps::Schema->go() };

1;
