package EduMaps::Task::Entorno;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use utf8;

# Refresh da arealização do setor censitário sobre a área de influência da
# escola (Tier 3, bloco B do IVET; changes `escola_entorno_socioeconomico` e
# `escola_entorno_socioeconomico_saneamento`, docs/analises/ivet.md §4.5).
# A lógica é PostGIS — clean.refresh_escola_entorno_socioeconomico() — e este
# job só a dispara. Depende da camada `clean.escola_influencia` já materializada
# (task `refresh_influencia`, EduMaps::Task::Influencia).
#
#   refresh_entorno_socioeconomico => []                        # país, raios default
#   refresh_entorno_socioeconomico => [{raios => [500,1000]}]   # raios explícitos
#   refresh_entorno_socioeconomico => [{uf => 'SP'}]            # uma UF (lote)
#   refresh_entorno_socioeconomico => [{co_entidades => [...]}] # escolas explícitas
#
# Idempotente (UPSERT): pode rodar quantas vezes quiser. Como a função global
# leva ~2 h, a forma de materializar o país é um job por UF (chunked): cada um
# é uma transação curta e retomável. O filtro `uf` monta a lista de escolas no
# banco (evita trafegar dezenas de milhares de INEPs).

sub register ($self, $app, $config) {
  $app->minion->add_task(refresh_entorno_socioeconomico => \&_refresh);
  $app->helper(
    refresh_entorno_socioeconomico => sub ($c, $args = {}) {
      $app->minion->enqueue(refresh_entorno_socioeconomico => [$args] => { attempts => 3 });
    }
  );
}

sub _refresh ($job, $args = undef) {
  $args ||= {};
  my $raios = ref $args->{raios} eq 'ARRAY' && @{ $args->{raios} } ? $args->{raios} : undef;
  my $lit   = $raios ? _array_lit($raios) : undef;   # NULL → default da função
  my $uf    = $args->{uf};
  my $cos   = $args->{co_entidades};
  my $linhas;

  try {
    my $dbh = $job->app->schema->storage->dbh;

    if (ref $cos eq 'ARRAY' && @$cos) {
      $linhas = $dbh->selectrow_array(
        'SELECT clean.refresh_escola_entorno_socioeconomico(COALESCE(?::integer[], ARRAY[500,1000,2000]), ?::bigint[])',
        {}, $lit, _array_lit($cos)
      );
    } elsif (defined $uf && length $uf) {
      $linhas = $dbh->selectrow_array(
        'SELECT clean.refresh_escola_entorno_socioeconomico(COALESCE(?::integer[], ARRAY[500,1000,2000]),
           (SELECT array_agg(co_entidade) FROM clean.censo_escolas
             WHERE geometry IS NOT NULL AND sg_uf = ?))',
        {}, $lit, $uf
      );
    } elsif ($raios) {
      $linhas = $dbh->selectrow_array(
        'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[])', {}, $lit
      );
    } else {
      $linhas = $dbh->selectrow_array('SELECT clean.refresh_escola_entorno_socioeconomico()');
    }
  } catch ($err) {
    $job->app->log->error("refresh_entorno_socioeconomico falhou: $err");
    return $job->fail({ error => "$err" });
  }

  return $job->finish({ linhas => 0 + ($linhas // 0) });
}

# Literal de array PostgreSQL `{500,1000}` a partir de uma lista de inteiros.
sub _array_lit ($vals) {
  return '{' . join(',', map { 0 + $_ } @$vals) . '}';
}

1;
