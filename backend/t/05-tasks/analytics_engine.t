use lib qw(t/lib lib);
use Imports;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Server::Daemon;
use Mojo::IOLoop;
use IO::Socket::INET;
use Time::HiRes qw(sleep);
use File::Temp qw(tempfile);
use Data::Dumper;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

# ---------------------------------------------------------------------------
# Servidor-filho emulando o Plumber (respostas fixas sem DB/R)
# ---------------------------------------------------------------------------
my $portfile = "/tmp/user/1000/opencode/ae-test-port.$$";
my $lastfile = "/tmp/user/1000/opencode/ae-test-last.$$";
my $pid;

{
  my $child = sub {
    my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1:0']);
    $daemon->unsubscribe('request')->on(request => sub ($daemon, $tx) {
      my $path   = $tx->req->url->path;
      my $method = $tx->req->method;
      my $body   = eval { Mojo::JSON::decode_json($tx->req->body) } // {};

      open my $last, '>', $lastfile or die "lastfile: $!";
      print {$last} Mojo::JSON::encode_json($body);
      close $last;

      my $json;
      if ($method eq 'POST' && $path eq '/cluster') {
        $tx->res->code(200);
        $json = {
          analysis  => 'cluster_' . ($body->{parameters}{algorithm} // 'kmeans'),
          data      => [ { entity_id => 'E1', cluster_id => 1 } ],
          metrics   => { n_entities => 1, n_clusters => 1 },
          metadata  => {},
          tables    => [],
          persisted => { run_id => 'http_run_1', rows_updated => 1 },
        };
      }
      elsif ($method eq 'POST' && $path eq '/summary') {
        $tx->res->code(200);
        $json = {
          analysis  => 'city_summary',
          metrics   => { total_escolas => 5 },
          metadata  => {},
          data      => [],
          tables    => [],
          persisted => {},
        };
      }
      elsif ($method eq 'POST' && $path eq '/similarity/db') {
        $tx->res->code(200);
        $json = {
          analysis  => 'gower_similarity',
          metrics   => { n_pairs => 1 },
          data      => [],
          tables    => [],
          persisted => { run_id => 'http_sim_1' },
        };
      }
      else {
        $tx->res->code(500);
        $json = { error => 'boom' };
      }

      $tx->res->headers->content_type('application/json');
      $tx->res->body(Mojo::JSON::encode_json($json));
      $tx->resume;
    });

    $daemon->start;
    open my $fh, '>', $portfile or die "portfile: $!";
    print {$fh} $daemon->ports->[0];
    close $fh;
    Mojo::IOLoop->start;
  };

  $pid = fork;
  die "fork: $!" unless defined $pid;
  if ($pid == 0) { $child->(); CORE::exit 0; }
}

END {
  if (defined $pid && $pid > 0) {
    kill 'TERM', $pid;
    sleep 0.05;
    kill 'KILL', $pid;
    waitpid $pid, 0;
    $? = 0;
  }
  unlink $portfile if $portfile;
  unlink $lastfile if $lastfile;
}

{
  my $deadline = time + 5;
  my $port;
  while (time < $deadline) {
    if (-f $portfile) {
      open my $fh, '<', $portfile or next;
      $port = do { local $/; <$fh> };
      close $fh;
      last if defined $port && $port =~ /^\d+$/;
    }
    sleep 0.05;
  }
  die "servidor de teste (filho $pid) não ficou pronto" unless defined $port && $port =~ /^\d+$/;

  # ---------------------------------------------------------------------------
  # Config temporário: edu_maps.conf base + analytics apontando ao servidor fake
  # ---------------------------------------------------------------------------
  my $base_conf = do './edu_maps.conf' or die "Nao foi possivel carregar edu_maps.conf: $@";

  my ($conf_fh, $conf_path) = tempfile(SUFFIX => '.conf', UNLINK => 1, DIR => '/tmp/user/1000/opencode');
  $Data::Dumper::Terse    = 1;
  $Data::Dumper::Sortkeys = 1;
  print {$conf_fh} Dumper({
    %$base_conf,
    analytics_engine         => 'http',
    analytics_url            => "http://127.0.0.1:$port",
    analytics_timeout        => 10,
    analytics_source_version => 'test',
    analytics_cache_enabled  => 0,
  });
  close $conf_fh;

  local $ENV{EDUMAPS_CONF} = $conf_path;
  my $t = Test::Mojo->new('EduMaps');

  subtest 'analytics_engine helper retorna http' => sub {
    is $t->app->analytics_engine, 'http', 'engine http por config';
  };

  # --- Cluster via POST /cluster -------------------------------------------
  subtest 'clustering via http engine' => sub {
    my $id  = $t->app->apply_clustering({
      id_column  => 'co_entidade',
      table_name => 'censo_escolas',
      schema     => 'staging',
      algorithm  => 'kmeans',
      clusters   => 3,
    });
    my $job = $t->app->minion->job($id);
    $t->app->minion->perform_jobs;

    is $job->info->{state}, 'finished', 'job clustering finalizado';

    my $r = $job->info->{result};
    is $r->{meta}{name},      'clusterization', 'meta.name';
    is $r->{meta}{algorithm}, 'kmeans',         'meta.algorithm';
    ok exists $r->{cluster_info}{r_meta},        'r_meta presente';
    is $r->{cluster_info}{r_meta}{analysis}, 'cluster_kmeans',
      'resposta do Plumber propagada em r_meta';
    is $r->{cluster_info}{r_meta}{persisted}{run_id}, 'http_run_1',
      'run_id vindo do endpoint';

    $t->app->minion->backend->remove_job($id);
  };

  # --- Cluster com geotag propaga filter ao endpoint http -------------------
  subtest 'clustering com filter (geotag) repassado ao endpoint' => sub {
    my $id = $t->app->apply_clustering({
      id_column      => 'co_entidade',
      table_name     => 'censo_escolas',
      schema         => 'staging',
      algorithm      => 'kmeans',
      clusters       => 3,
      filter         => { co_regiao => 1, co_uf => 35, co_municipio => 3550308 },
    });
    my $job = $t->app->minion->job($id);
    $t->app->minion->perform_jobs;

    is $job->info->{state}, 'finished', 'job com filter finalizado';

    open my $fh, '<', $lastfile or die "lastfile: $!";
    my $body = decode_json(do { local $/; <$fh> });
    close $fh;

    is $body->{filter}, { co_regiao => 1, co_uf => 35, co_municipio => 3550308 },
      'filter presente no payload do POST /cluster';
    is $body->{table_name}, 'censo_escolas', 'table_name preservado';

    $t->app->minion->backend->remove_job($id);
  };

  # --- Similaridade gower (suportada) --------------------------------------
  subtest 'similarity gower via http engine' => sub {
    my $id = $t->app->apply_similarity({
      id_column  => 'co_entidade',
      table_name => 'censo_escolas',
      schema     => 'staging',
      metric     => 'gower',
    });
    my $job = $t->app->minion->job($id);
    $t->app->minion->perform_jobs;

    is $job->info->{state}, 'finished', 'job similarity gower finalizado';
    is $job->info->{result}{meta}{metric}, 'gower';
    is $job->info->{result}{similarity_info}{r_meta}{persisted}{run_id},
      'http_sim_1', 'run_id vindo do endpoint';

    $t->app->minion->backend->remove_job($id);
  };

  # --- Similaridade não-gower (rejeitada em http) ---------------------------
  subtest 'similarity non-gower rejeitada em http engine' => sub {
    my $id = $t->app->apply_similarity({
      id_column  => 'co_entidade',
      table_name => 'censo_escolas',
      schema     => 'staging',
      metric     => 'euclidean_zscore',
    });
    my $job = $t->app->minion->job($id);
    $t->app->minion->perform_jobs;

    is $job->info->{state}, 'failed', 'job rejeitado';
    like $job->info->{result}, qr/nao suportada.*pipe/, 'mensagem instrui usar pipe';

    $t->app->minion->backend->remove_job($id);
  };

# --- CityAnalytics via POST /summary -------------------------------------
  # apply_city_analytics enfileira na fila 'speculative' (prioridade 0), que o
  # Minion em processo não processa (perform_jobs só roda a fila 'default').
  # Enfileira direto na fila padrão para exercitar o motor http da task.
  subtest 'city_analytics via http engine' => sub {
    my $id = $t->app->minion->enqueue(
      city_analytics => [{ codigo_ibge => '3550308', analysis => 'full_summary' }]
    );
    my $job = $t->app->minion->job($id);
    $t->app->minion->perform_jobs;

    is $job->info->{state}, 'finished', 'job city_analytics finalizado';
    is $job->info->{result}{meta}{analysis}, 'full_summary';
    is $job->info->{result}{analytics_info}{r_meta}{analysis}, 'city_summary',
      'resposta do Plumber propagada';

    $t->app->minion->backend->remove_job($id);
  };
}

done_testing();