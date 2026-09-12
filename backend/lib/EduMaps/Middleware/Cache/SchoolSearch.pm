package EduMaps::Middleware::Cache::SchoolSearch;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Digest::SHA qw(sha256_hex);
use Mojo::Util  qw(gunzip);

has 'cache';
has ttl => 3600*24*7; # 1 semana

# Conjunto de nomes de rotas (Mojo Route Names) que representam buscas/consultas cacheáveis
my %CACHEABLE_ROUTE_NAMES = map { $_ => 1 } qw(
  school_search
  school_search_suggestion
  school_search_pageable
  school_nearby
  school_city_cluster
  school_scores
  city_schools
  city_search_by_name
  city_search_suggestions
  search_analityc_cities
  search_markers
  search_analytic
  similars
  panel_school_info
);

sub register ($self, $app, $conf = {}) {
  $self->ttl($conf->{ttl}) if $conf->{ttl};
  $self->cache($conf->{cache} // $app->chi);

  $app->hook(
    around_dispatch => sub ($next, $c) {
      $self->_cache_hook($next, $c);
    }
  );
}

sub _cache_hook ($self, $next, $c) {
  # Apenas métodos GET/HEAD idempotentes devem ser cacheados
  my $method = $c->req->method;
  return $next->() unless $method eq 'GET' || $method eq 'HEAD';

  # 1. Obtém o nome da rota casada (se $c->match já foi resolvido)
  my $endpoint   = $c->match->endpoint;
  my $route_name = $endpoint ? ($endpoint->name // '') : '';
  my $is_search  = $CACHEABLE_ROUTE_NAMES{$route_name};

  # 2. Fallback de verificação via Path Regex (caso $c->match ainda seja undef no início do dispatch)
  if (!$is_search) {
    my $path = $c->req->url->path->to_string;
    $is_search = $path =~ m{
      ^/api/
      (?:school|city|analytics)/
      (?:search|suggestions|geo/search|cluster|\d+/panel|scores|cities/search|cities/markers|city/search|city/similar_to|\d{7}/schools|\d{7}/details|detail/|search/)
    }xms;
  }

  # Se não for uma rota de busca cacheável, segue a execução normal
  return $next->() unless $is_search;

  # Chave de Cache única por URL (path + query params)
  my $cache_key = $self->_build_cache_key($c);

  # HIT no Cache
  if (my $cached_response = $self->cache->get($cache_key)) {
    $c->res->headers->header('X-Cache' => 'HIT');
    $c->render(
      data   => $cached_response->{body},
      format => 'json',
      status => $cached_response->{status} // 200
    );
    return; # Encerra o ciclo sem invocar Controller/Modelo
  }

  # MISS no Cache
  $c->res->headers->header('X-Cache' => 'MISS');

  $next->();

  if ($c->res->code == 200) {
    my $body     = $c->res->body;
    my $encoding = $c->res->headers->content_encoding // '';

    if ($encoding =~ /gzip/i) {
      $body = gunzip($body);
    }

    # Não armazena em cache se o retorno for um array vazio / sem resultados
    return if !$body || $body eq '[]';

    $self->cache->set($cache_key, {
        body   => $body,
        status => 200,
      }, $self->ttl);
  }
}

sub _build_cache_key ($self, $c) {
  my $path  = $c->req->url->path->to_string;
  my $query = $c->req->url->query->to_string // '';

  return "edumaps:cache:search:" . sha256_hex("${path}?${query}");
}

1;
