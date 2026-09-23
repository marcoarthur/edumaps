package EduMaps::Analytics::Client;
use utf8;
use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON;
use Mojo::Util;
use JSON::PP;
use Carp qw(croak);
use Scalar::Util qw(blessed);

has [qw(url timeout source_version cache_enabled app)];
has ua => sub {
  Mojo::UserAgent->new(inactivity_timeout => shift->timeout);
};

# Prefixos de análise cuja resposta é pequena o bastante para o cache
# compartilhado. Similaridade (gower_similarity) retorna O(n²) pares e
# NUNCA entra no cache — só é persistida em analytics.similarity_pairs.
my %CACHEABLE_PREFIX = (
  cluster_      => 1,
  city_summary  => 1,
  chat_         => 1,
);

sub new ($class, %args) {
  my $self = $class->SUPER::new(%args);
  $self->ua(Mojo::UserAgent->new(inactivity_timeout => $self->timeout));
  return $self;
}

# ---------------------------------------------------------------------------
# Métodos públicos
# ---------------------------------------------------------------------------

sub run_cluster ($self, $args) {
  my $analysis = 'cluster_' . ($args->{parameters}{algorithm} // 'kmeans');
  $self->_run('cluster', {
    schema        => $args->{schema},
    table_name    => $args->{table_name},
    id_column     => $args->{id_column},
    features      => $args->{features},
    filter        => $args->{filter},
    parameters    => $args->{parameters} // {},
    output_schema => $args->{output_schema},
  }, $analysis, {
    cacheable => 1,
    cache_params => {
      schema     => $args->{schema},
      table_name => $args->{table_name},
      id_column  => $args->{id_column},
      features   => $args->{features},
      filter     => $args->{filter},
      parameters => $args->{parameters} // {},
    },
  });
}

sub run_summary ($self, $args) {
  $self->_run('summary', {
    codigo_ibge => $args->{codigo_ibge},
    schema      => $args->{schema},
    parameters  => $args->{parameters} // {},
  }, 'city_summary', {
    cacheable => 1,
    cache_params => {
      codigo_ibge => $args->{codigo_ibge},
      schema      => $args->{schema},
      parameters  => $args->{parameters} // {},
    },
  });
}

sub run_similarity ($self, $args) {
  $self->_run('similarity', {
    data      => $args->{data},
    variables => $args->{variables} // {},
  }, 'gower_similarity', { cacheable => 0 });
}

sub run_similarity_db ($self, $args) {
  $self->_run('similarity/db', {
    schema        => $args->{schema},
    table_name    => $args->{table_name},
    id_column     => $args->{id_column},
    features      => $args->{features},
    variables     => $args->{variables} // {},
    output_schema => $args->{output_schema},
  }, 'gower_similarity', { cacheable => 0 });
}

sub run_chart ($self, $args) {
  $self->_run('chart', {
    chart_type => $args->{chart_type},
    data       => $args->{data},
    variables  => $args->{variables} // {},
  }, $args->{chart_type} // 'chart', { cacheable => 0 });
}

sub health ($self) {
  $self->_post('health', undef, { get => 1 });
}

# Assistente do Censo (NL->SQL). A resposta é cacheável: a mesma pergunta no
# mesmo contexto (município/escola) devolve sempre a mesma payload — o cache
# também serve de fallback quando o provedor de LLM está lento/indisponível.
# A chave inclui `pergunta` + `contexto` (canonicalizados) + source_version,
# então perguntas/contextos diferentes não colidem.
sub run_chat ($self, $args) {
  my $pergunta = $args->{pergunta};
  my $contexto = $args->{contexto} // {};

  $self->_run('ask', {
    pergunta => $pergunta,
    contexto => $contexto,
  }, 'chat_' . Mojo::Util::sha1_hex($pergunta), {
    cacheable    => 1,
    cache_params => {
      pergunta => $pergunta,
      contexto => $contexto,
    },
  });
}

sub flush_cache ($self, $analysis, $params) {
  return unless $self->cache_enabled;
  my $key = $self->_cache_key($analysis, $params);
  my $db  = $self->_db or return;
  eval { $db->query('DELETE FROM analytics.analysis_cache WHERE cache_key = ?', $key); 1 }
    or return;
  return 1;
}

# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------

sub _run ($self, $endpoint, $body, $analysis, $opts = {}) {
  my $cacheable    = $opts->{cacheable};
  my $cache_params = $opts->{cache_params} // $body->{parameters} // {};

  if ($self->cache_enabled && $cacheable) {
    my $cached = $self->_cache_read($analysis, $cache_params);
    if (defined $cached) {
      $cached->{cache_hit} = Mojo::JSON::true;
      return $cached;
    }
  }

  my $response = $self->_post($endpoint, $body);

  if ($self->cache_enabled && $cacheable && defined $response) {
    $self->_cache_write($analysis, $cache_params, $response);
  }

  $response->{cache_hit} = Mojo::JSON::false;
  return $response;
}

sub _post ($self, $endpoint, $body, $opts = {}) {
  my $url = $self->url . '/';
  $url .= $endpoint;

  my $tx = $opts->{get}
    ? $self->ua->get($url)
    : $self->ua->post($url => json => $body);

  my $error = $tx->error;
  croak "Analytics: falha de conexão ($url): $error->{message}"
    if $error && !$error->{code};

  my $res = $tx->res;
  unless ($res->is_success) {
    my $decoded = eval { Mojo::JSON::decode_json($res->body)->{error} };
    my $message;
    if (ref $decoded eq 'ARRAY') {
      $message = join('; ', @$decoded);
    }
    else {
      $message = $decoded // $res->message;
    }
    croak "Analytics: $endpoint retornou " . $res->code . ": $message";
  }

  my $data = eval { Mojo::JSON::decode_json($res->body) }
    or croak "Analytics: resposta inválida de $endpoint: $@";

  return $data;
}

# ---------------------------------------------------------------------------
# Cache compartilhado (analytics.analysis_cache)
# ---------------------------------------------------------------------------

sub _cache_key ($self, $analysis, $params) {
  # encode_json do Mojo não ordena chaves e a ordem de iteração de
  # hash no Perl é aleatória por processo — a chave de cache PRECISA ser
  # canônica (JSON::PP->canonical) para ser estável entre workers.
  my $canonical = JSON::PP->new->canonical->allow_nonref;
  Mojo::Util::sha1_hex($canonical->encode({
    analysis       => $analysis,
    params         => $params,
    source_version => $self->source_version,
  }));
}

sub _cache_read ($self, $analysis, $params) {
  return unless $self->cache_enabled;
  my $db = $self->_db or return;
  my $key = $self->_cache_key($analysis, $params);

  my $row = eval {
    $db->query(
      'SELECT payload
         FROM analytics.analysis_cache
        WHERE cache_key = ?
          AND (expires_at IS NULL OR expires_at > NOW())',
      $key,
    )->hash;
  };
  return unless $row;
  return eval { Mojo::JSON::decode_json($row->{payload}) };
}

sub _cache_write ($self, $analysis, $params, $response) {
  return unless $self->cache_enabled;
  my $db = $self->_db or return;
  my $key = $self->_cache_key($analysis, $params);

  eval {
    $db->query(
      'INSERT INTO analytics.analysis_cache
         (cache_key, analysis, params, payload, source_version, expires_at)
       VALUES (?, ?, ?, ?, ?, NOW() + INTERVAL \'24 hours\')
       ON CONFLICT (cache_key) DO UPDATE SET
         params = EXCLUDED.params,
         payload = EXCLUDED.payload,
         source_version = EXCLUDED.source_version,
         expires_at = EXCLUDED.expires_at,
         updated_at = NOW()',
      $key,
      $analysis,
      Mojo::JSON::encode_json($params),
      Mojo::JSON::encode_json($response),
      $self->source_version,
    );
    1;
  } or do {
    return unless $@ && $db;
    $self->_log_warn("cache write falhou (tabela analytics.analysis_cache ausente?): $@");
  };

  return 1;
}

sub _db ($self) {
  my $app = $self->app;
  return unless $app && ref($app) && $app->can('pg');
  eval { $app->pg->db };
}

sub _log_warn ($self, $message) {
  my $app = $self->app;
  return unless $app && $app->can('log');
  $app->log->debug($message);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Analytics::Client - Cliente síncrono do serviço analítico Plumber

=head1 SYNOPSIS

    use EduMaps::Analytics::Client;

    my $client = EduMaps::Analytics::Client->new(
      url            => 'http://analytic:8000',
      timeout        => 300,
      source_version => 'edumapsr-0.1.0',
      cache_enabled  => 1,
      app            => $app,   # opcional (para o cache compartilhado)
    );

    my $result = $client->run_cluster({
      schema     => 'staging',
      table_name => 'censo_escolas',
      id_column  => 'co_entidade',
      parameters => { algorithm => 'kmeans', clusters => 4 },
    });

=head1 DESCRIPTION

Executa chamadas HTTP síncronas (Mojo::UserAgent bloqueante) contra o serviço
analítico Plumber do edumapsr. Análises de cluster e resumo de cidade usam
leitura-through no cache compartilhado C<analytics.analysis_cache>; pares de
similaridade (O(n²)) nunca são cacheados.

=head1 METHODS

=head2 run_cluster / run_summary / run_similarity / run_similarity_db / run_chart

Veja L<EduMaps::Plugin::Analytics> para os formatos de C<args>.

=head2 health

Retorna o JSON de C<GET /health>.

=head2 flush_cache($analysis, $params)

Remove a entrada de C<analytics.analysis_cache> correspondente à chave
calculada a partir de C<$analysis>+C<$params>.

=cut