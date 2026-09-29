package EduMaps::Services::OSM;

use Mojo::Base 'Mojo::EventEmitter', -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Promise;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::File qw(path);
use Mojo::Log;
use Time::HiRes qw(gettimeofday tv_interval);
use utf8;

=head1 NAME

EduMaps::Services::OSM - Cliente Overpass do OSM (puro, sem banco)

=head1 DESCRIPTION

Executa uma L<EduMaps::Services::OSM::Query> contra o Overpass API e converte
a resposta em GeoJSON. Suporta os três tipos de elemento do OSM de forma
genérica:

  * C<node>     -> Point
  * C<way>      -> LineString (aberto) ou Polygon (fechado)
  * C<relation> -> MultiPolygon (quando C<type=multipolygon>)

Não conhece banco de dados — quem persiste/cacheia é o
L<EduMaps::Model::OSM>. Para testes offline, aceita C<offline =E<gt> 1> e
C<fixture> (caminho de um JSON gravado ou um hashref já decodificado).

Emite: C<query> (string QL), C<query_data> (C<{query,data,elapsed}>),
C<feature> (GeoJSON Feature) e C<progress> (C<{total,processed,phase}>).

=cut

has query        => undef;
has ql           => undef;
has log          => sub { Mojo::Log->new };
has timeout      => sub ($self) { $self->query ? $self->query->timeout : 60 };
has ua           => sub ($self) { Mojo::UserAgent->new->connect_timeout($self->timeout) };
has overpass_url => sub { Mojo::URL->new('https://overpass-api.de/api/interpreter') };
has offline      => sub { 0 };
has fixture      => sub { undef };

has raw_body => undef;
has raw      => undef;
has geojson  => undef;
has elapsed  => 0;

# Executa a consulta de forma SÍNCRONA (Mojo::UserAgent bloqueante, como o
# EduMaps::Analytics::Client). Erros de rede/HTTP/fixture/parse PROPAGAM
# (die) — o job Minion falha em vez de "concluir" com 0 POIs. No worker o
# IOLoop não está `is_running`, então a chamada bloqueante funciona.
sub run($self) {
  my $ql = $self->ql // ($self->query ? $self->query->to_ql : undef)
    // die 'Need query or ql';
  $self->emit(query => $ql);

  my $data;
  if ($self->offline) {
    $self->log->info('Carregando fixture OSM (offline)');
    $data = $self->_load_fixture;
  }
  else {
    $self->log->info('Requesting OSM/Overpass service');
    $data = $self->_request($ql);
  }

  $self->raw($data);
  $self->geojson( $self->parse($data) );
  return $self->geojson;
}

# API de promise (usada por Task::OSM::Service::run_query_p). Envolve o run
# síncrono; a rejeição carrega o erro real (não é engolida).
sub run_p($self) {
  my $p = Mojo::Promise->new;
  eval { $p->resolve( $self->run ) } or $p->reject($@ || 'erro desconhecido');
  return $p;
}

sub _load_fixture($self) {
  my $f = $self->fixture // die 'offline=1 exige fixture (path ou hashref)';
  return $f if ref $f eq 'HASH';
  die "fixture não encontrada: $f" unless -f $f;
  return decode_json( path($f)->slurp );
}

# Requisição bloqueante ao Overpass. HTTP não-2xx / falha de conexão -> die.
sub _request($self, $ql) {
  $self->emit(progress => { total => 0, processed => 0, phase => 'requesting osm' });

  my $t0 = [ gettimeofday ];
  my $id = $self->ua->on(
    start => sub ($ua, $tx, @rest) {
      $tx->req->once(finish => sub {
        $tx->res->on(progress => sub ($msg, @rest) {
          return unless my $len = $msg->headers->content_length;
          my $size = $msg->content->progress;
          $self->emit(progress => {
            total => 100,
            processed => int($size / ($len / 100)),
            phase => 'download osm',
          });
        });
      });
    }
  );

  my $tx = $self->ua->post($self->overpass_url => form => { data => $ql });
  $self->ua->unsubscribe(start => $id);

  if (my $err = $tx->error) {
    my $code = $err->{code} // 0;
    my $msg  = $err->{message} // 'erro';
    $self->log->error(sprintf 'Overpass falhou: %s (%s)', $ql, $code ? "HTTP $code" : $msg);
    die $code
      ? sprintf('Overpass retornou HTTP %s: %s', $code, $msg)
      : "Falha na conexão com o Overpass: $msg";
  }

  my $res = $tx->res;
  if (!$res->is_success) {
    $self->log->error(sprintf 'Overpass falhou: %s (HTTP %s)', $ql, $res->code);
    die sprintf 'Overpass retornou HTTP %s: %s', $res->code, $res->message;
  }

  $self->raw_body( $res->body );
  $self->elapsed( tv_interval($t0) );
  $self->emit(query_data => {
    query   => $ql,
    data    => $res->body,
    elapsed => $self->elapsed,
  });

  return decode_json( $res->body );
}

# Converte a resposta do Overpass em GeoJSON (genérico nwr).
sub parse($self, $osm_data = $self->raw) {
  die 'Sem dados OSM para parsear (chame run antes)' unless $osm_data;
  my $elements = $osm_data->{elements} // [];

  my (%nodes, %ways);

  # Passada 1: indexa os nós (o Overpass devolve os ways antes dos nós).
  for my $el (@$elements) {
    if (($el->{type} // '') eq 'node') {
      $nodes{ $el->{id} } = [ $el->{lon}, $el->{lat} ];
    }
  }

  # Passada 2: monta as coordenadas dos ways a partir dos nós.
  for my $el (@$elements) {
    next unless (($el->{type} // '') eq 'way');
    my @coords = map { $nodes{$_} } @{ $el->{nodes} // [] };
    $ways{ $el->{id} } = [ grep { $_ } @coords ];
  }

  my $total = scalar @$elements;
  my $processed = 0;
  $self->emit(progress => { total => $total, processed => 0, phase => 'geojson' });

  my @features;
  for my $el (@$elements) {
    my $type = $el->{type} // '';
    my $tags = $el->{tags} // {};

    # Ignora elementos "skel" (nós/vias da recursão `>` sem tags) — só
    # interessam feições reais (com pelo menos uma tag).
    next unless keys %$tags;

    my $geometry; my $coords;

    if ($type eq 'node') {
      next unless defined $el->{lat} && defined $el->{lon};
      $coords = [ $el->{lon}, $el->{lat} ];
      $geometry = { type => 'Point', coordinates => $coords };
    }
    elsif ($type eq 'way') {
      $coords = $ways{ $el->{id} } // [];
      next unless @$coords >= 2;
      $geometry = $self->_way_geometry($coords);
    }
    elsif ($type eq 'relation') {
      $geometry = $self->_relation_geometry($el, \%ways);
    }

    if ($geometry) {
      my $feat = {
        type     => 'Feature',
        geometry => $geometry,
        properties => {
          %$tags,
          id       => $el->{id},
          osm_type => $type,
          osm_id   => $el->{id},
        },
      };
      push @features, $feat;
      $self->emit(feature => $feat);
    }

    $self->emit(progress => { total => $total, processed => ++$processed, phase => 'geojson' });
  }

  return { type => 'FeatureCollection', features => \@features };
}

sub _way_geometry($self, $coords) {
  my $closed = @$coords >= 4
    && $coords->[0][0] == $coords->[-1][0]
    && $coords->[0][1] == $coords->[-1][1];

  if ($closed) {
    return { type => 'Polygon', coordinates => [ $coords ] };
  }
  return { type => 'LineString', coordinates => $coords };
}

sub _relation_geometry($self, $rel, $ways) {
  my $tags = $rel->{tags} // {};
  return undef unless (($tags->{type} // '') eq 'multipolygon' || $tags->{boundary});

  my @outers; my @inners;
  for my $m (@{ $rel->{members} // [] }) {
    next unless ($m->{type} // '') eq 'way';
    my $ring = $ways->{ $m->{ref} } // [];
    next unless @$ring >= 3;
    push @{ ($m->{role} // '') eq 'inner' ? \@inners : \@outers }, $ring;
  }
  return undef unless @outers;

  # Aproximação: cada outer vira um polígono; anéis internos entram no
  # primeiro outer (sem teste de contenção geométrica).
  my @polygons;
  for my $i (0 .. $#outers) {
    my $poly = [ $outers[$i] ];
    push @$poly, @inners if $i == 0;
    push @polygons, $poly;
  }

  return { type => 'MultiPolygon', coordinates => \@polygons };
}

1;
