use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use Mojo::URL;
use EduMaps::Services::OSM;
use EduMaps::Services::OSM::Query;

# Garante que falhas de rede/HTTP/fixture PROPAGAM (não virem um "sucesso"
# silencioso com 0 POIs). Regressão do bug em que o erro do Overpass era
# engolido (job "finished" com raw nulo e related 0).

my $q = EduMaps::Services::OSM::Query->new(
  target  => { type => 'around', lat => -23.5, lon => -46.6, raio => 800 },
  profile => 'equipamentos_publicos',
);

subtest 'offline sem fixture morre (die sincrono)' => sub {
  my $svc = EduMaps::Services::OSM->new(
    query   => $q,
    offline => 1,
    fixture => 't/fixtures/osm/nao-existe.json',
  );

  my $err = eval { $svc->run; 1 } ? undef : $@;
  ok $err, 'run morre quando a fixture nao existe';
  like $err, qr/fixture n/i, 'mensagem fala da fixture';
};

subtest 'erro do _request propaga pelo run e pelo run_p' => sub {
  {
    package Test::OSM::Failing;
    use Mojo::Base 'EduMaps::Services::OSM', -signatures;
    sub _request($self, $ql) {
      die "Overpass retornou HTTP 504: Gateway Timeout\n";
    }
  }

  my $err = eval { Test::OSM::Failing->new(query => $q)->run; 1 } ? undef : $@;
  ok $err, 'run morre quando o _request falha (HTTP 504)';
  like $err, qr/HTTP 504/, 'erro HTTP propagado';

  my $perr;
  Test::OSM::Failing->new(query => $q)->run_p->catch(sub { $perr = shift })->wait;
  ok $perr, 'run_p rejeita (nao engole)';
  like $perr, qr/HTTP 504/, 'run_p preserva a mensagem';
};

subtest 'falha de transporte propaga pelo run' => sub {
  my $svc = EduMaps::Services::OSM->new(
    query        => $q,
    timeout      => 3,
    overpass_url => Mojo::URL->new('http://127.0.0.1:1/api/interpreter'),
  );

  my $err = eval { $svc->run; 1 } ? undef : $@;
  ok $err, 'run morre quando a conexao falha';
};

subtest 'offline com fixture (hashref) segue funcionando' => sub {
  my $svc = EduMaps::Services::OSM->new(
    query   => $q,
    offline => 1,
    fixture => {
      elements => [
        { type => 'node', id => 1, lat => -23.5, lon => -46.6,
          tags => { amenity => 'library', name => 'Biblioteca' } },
      ],
    },
  );

  my $gj = $svc->run;
  is $gj->{type}, 'FeatureCollection', 'FeatureCollection';
  is scalar(@{ $gj->{features} }), 1, 'uma feature';
  is $gj->{features}[0]{properties}{name}, 'Biblioteca', 'nome preservado';
};

done_testing;
