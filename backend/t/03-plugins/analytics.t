use lib qw(t/lib lib);
use Imports;
use EduMaps::Analytics::Client;
use Mojo::Server::Daemon;
use Mojo::IOLoop;
use Mojo::JSON;
use IO::Socket::INET;
use Time::HiRes qw(sleep);
use utf8;
use open ':std', ':encoding(UTF-8)';

# ---------------------------------------------------------------------------
# Servidor-filho que emula o serviço Plumber/edumapsr (loop dedicado).
# ---------------------------------------------------------------------------
my $portfile = "/tmp/user/1000/opencode/analytics-test-port.$$";
my $pid;

{
  my $child = sub {
    my $daemon = Mojo::Server::Daemon->new(listen => ["http://127.0.0.1:0"]);
    $daemon->unsubscribe('request')->on(request => sub ($daemon, $tx) {
      my $method = $tx->req->method;
      my $path   = $tx->req->url->path;
      my $body   = eval { Mojo::JSON::decode_json($tx->req->body) } // {};

      my ($code, $json);
      if ($method eq 'POST' && $path eq '/cluster') {
        $code = 200;
        $json = {
          analysis  => 'cluster_' . ($body->{parameters}{algorithm} // 'kmeans'),
          data      => [ { entity_id => 'E1', cluster_id => 1 } ],
          metrics   => { n_entities => 1, n_clusters => 1 },
          metadata  => { entity_id => $body->{id_column} },
          tables    => [],
          persisted => { run_id => 'run_1', rows_updated => 1 },
        };
      }
      elsif ($method eq 'POST' && $path eq '/summary') {
        $code = 200;
        $json = {
          analysis => 'city_summary',
          metrics  => { total_escolas => 3 },
          metadata => { codigo_ibge => $body->{codigo_ibge} },
          data     => [],
          tables   => [],
        };
      }
      elsif ($method eq 'POST' && $path eq '/similarity/db') {
        $code = 200;
        $json = { analysis => 'gower_similarity', data => [], metrics => { n_pairs => 1 } };
      }
      elsif ($method eq 'GET' && $path eq '/health') {
        $code = 200;
        $json = { status => 'ok' };
      }
      else {
        $code = 500;
        $json = { error => 'boom' };
      }

      $tx->res->code($code);
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
  die "fork falhou: $!" unless defined $pid;
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
}

my $deadline = time + 5;
my $port;
while (time < $deadline) {
  if (-f $portfile) {
    open my $fh, '<', $portfile or next;
    my $p = <$fh>;
    close $fh;
    if (defined $p && $p =~ /^\d+$/) {
      my $sock = IO::Socket::INET->new(
        PeerAddr => '127.0.0.1', PeerPort => $p, Proto => 'tcp', Timeout => 1
      );
      if ($sock) { close $sock; $port = $p; last }
    }
  }
  sleep 0.05;
}
die "servidor de teste (filho $pid) nunca ficou pronto" unless defined $port;

my $make_client = sub ($opts = {}) {
  EduMaps::Analytics::Client->new(
    url            => "http://127.0.0.1:$port",
    timeout        => 10,
    source_version => 'test-0.1.0',
    cache_enabled  => 0,
    %$opts,
  );
};

subtest 'run_cluster chama POST /cluster e devolve o JSON da análise' => sub {
  my $result = $make_client->()->run_cluster({
    schema     => 'staging',
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
    parameters => { algorithm => 'kmeans', clusters => 4 },
  });

  is $result->{analysis}, 'cluster_kmeans',     'análise cluster retornada';
  is $result->{metadata}{entity_id}, 'co_entidade', 'id_column propagado';
  is $result->{cache_hit}, Mojo::JSON::false,  'sem cache, cache_hit é false';
};

subtest 'run_summary chama POST /summary' => sub {
  my $result = $make_client->()->run_summary({ codigo_ibge => '3550308' });
  is $result->{metrics}{total_escolas}, 3, 'resumo retornado';
};

subtest 'run_similarity_db chama POST /similarity/db' => sub {
  my $result = $make_client->()->run_similarity_db({
    schema     => 'staging',
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
  });
  is $result->{metrics}{n_pairs}, 1, 'pares retornados';
};

subtest 'health chama GET /health' => sub {
  my $result = $make_client->()->health;
  is $result->{status}, 'ok', 'health ok';
};

subtest 'erro HTTP vira croak com status e mensagem do serviço' => sub {
  my $err;
  eval { $make_client->()->run_chart({ chart_type => 'scatter', data => [] }) };
  $err = $@;
  like "$err", qr/500/, 'croak cita o status HTTP';
  like "$err", qr/Analytics/, 'croak identifica a origem Analytics';
};

# ---------------------------------------------------------------------------
# Cache key canônica (estável entre processos, sensível a params/versão)
# ---------------------------------------------------------------------------
subtest 'cache_key é canônica e estável' => sub {
  my $a = $make_client->( { source_version => 'v1' } );
  my $b = $make_client->( { source_version => 'v1' } );

  my $k1 = $a->_cache_key('cluster_kmeans', { algorithm => 'kmeans', clusters => 4 });
  my $k2 = $b->_cache_key('cluster_kmeans', { algorithm => 'kmeans', clusters => 4 });

  is $k1, $k2, 'mesma análise+params+versão => mesma chave (entre instâncias)';

  my $k3 = $b->_cache_key('cluster_kmeans', { algorithm => 'kmeans', clusters => 5 });
  ok $k1 ne $k3, 'params diferentes => chaves diferentes';

  my $k4 = $b->_cache_key('cluster_kmeans', { algorithm => 'kmeans', clusters => 4 });
  ok $k4 eq $k1, 'chave independente da ordem das chaves dos hashes aninhados';

  my $k5 = $make_client->({ source_version => 'v2' })
    ->_cache_key('cluster_kmeans', { algorithm => 'kmeans', clusters => 4 });
  ok $k1 ne $k5, 'source_version diferente => chave diferente';
};

subtest 'cache do resumo é escopado por codigo_ibge e schema' => sub {
  my $c = $make_client->( { source_version => 'v1' } );

  my $k_sp_3550308 = $c->_cache_key('city_summary', {
    codigo_ibge => '3550308', schema => 'staging', parameters => {},
  });
  my $k_sp_3509502 = $c->_cache_key('city_summary', {
    codigo_ibge => '3509502', schema => 'staging', parameters => {},
  });
  my $k_clean      = $c->_cache_key('city_summary', {
    codigo_ibge => '3550308', schema => 'clean', parameters => {},
  });

  ok $k_sp_3550308 ne $k_sp_3509502, 'codigo_ibge diferente => chaves diferentes';
  ok $k_sp_3550308 ne $k_clean,      'schema diferente => chaves diferentes';
};

subtest 'cache do cluster é escopado por table/schema/features' => sub {
  my $c = $make_client->( { source_version => 'v1' } );

  my $params = { algorithm => 'kmeans', clusters => 4 };
  my $k_t1 = $c->_cache_key('cluster_kmeans', {
    schema => 'staging', table_name => 'censo_2023', id_column => 'co_entidade',
    features => [qw(tx_aprov tx_evasao)], parameters => $params,
  });
  my $k_t2 = $c->_cache_key('cluster_kmeans', {
    schema => 'staging', table_name => 'censo_2024', id_column => 'co_entidade',
    features => [qw(tx_aprov tx_evasao)], parameters => $params,
  });
  my $k_f2 = $c->_cache_key('cluster_kmeans', {
    schema => 'staging', table_name => 'censo_2023', id_column => 'co_entidade',
    features => [qw(tx_aprov)], parameters => $params,
  });

  ok $k_t1 ne $k_t2, 'table_name diferente => chaves diferentes';
  ok $k_t1 ne $k_f2, 'features diferentes => chaves diferentes';
};

subtest 'com cache habilitado mas sem app/pg, o ciclo HTTP segue intacto' => sub {
  my $result = $make_client->({ cache_enabled => 1 })->run_cluster({
    schema     => 'staging',
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
    parameters => { algorithm => 'kmeans', clusters => 4 },
  });

  is $result->{analysis}, 'cluster_kmeans', 'read-through s/ DB é um no-op transparente';
  is $result->{cache_hit}, Mojo::JSON::false, 'sem tabela de cache, cache_hit continua false';
};

done_testing();