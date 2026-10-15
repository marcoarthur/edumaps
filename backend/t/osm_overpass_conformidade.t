use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use Mojo::File qw(path);
use File::Temp ();
use Time::HiRes ();
use EduMaps::Services::OSM;
use EduMaps::Services::OSM::Query;

# Conformidade com a política de uso do Overpass (#131):
#  - User-Agent que identifica a aplicação;
#  - retry/backoff só para falhas transitórias (429/504/5xx/rede);
#  - 4xx (excepto 429) é definitivo — não se repete.

my $q = EduMaps::Services::OSM::Query->new(
  target  => { type => 'around', lat => -23.5, lon => -46.6, raio => 800 },
  profile => 'equipamentos_publicos',
);

my $node = {
  type => 'node', id => 1, lat => -23.5, lon => -46.6,
  tags => { amenity => 'library', name => 'Biblioteca' },
};

# Substitui _request por um guião: cada passo é [code] (falha) ou
# [200, payload] (sucesso). Guarda as chamadas para se contar quantas houve.
{
  package Test::OSM::Scripted;
  use Mojo::Base 'EduMaps::Services::OSM', -signatures;

  has script => sub { [] };
  has calls  => sub { [] };

  sub _request($self, $ql) {
    push @{ $self->calls }, $ql;
    my $step = shift @{ $self->script }
      or die "Script esgotado: chamada inesperada ao Overpass\n";
    my ($code, $payload) = @$step;
    if ($code == 200) {
      $self->_http_code(undef);
      return $payload // { elements => [] };
    }
    $self->_http_code($code);
    die "Overpass retornou HTTP $code: erro simulado\n";
  }
}

subtest 'User-Agent identifica a aplicação (política OSMF)' => sub {
  my $svc  = EduMaps::Services::OSM->new(query => $q);
  my $name = $svc->ua->transactor->name;

  is   $name, $svc->user_agent, 'o UA do cliente é o user_agent configurado';
  like $name, qr/EduMaps/,  'nomeia a aplicação';
  unlike $name, qr/Mojolicious/i, 'não é o default do Mojolicious';
};

subtest '429 é transitório: retenta e conclui' => sub {
  my $svc = Test::OSM::Scripted->new(
    query          => $q,
    backoff_base   => 0,
    jitter         => 0,
    max_tentativas => 3,
    script         => [ [429], [200, { elements => [$node] }] ],
  );

  my $gj = $svc->run;
  is scalar(@{ $svc->calls }), 2, 'duas chamadas (1x 429 + 1x sucesso)';
  is $gj->{type}, 'FeatureCollection', 'conclui após o retry';
  is scalar(@{ $gj->{features} }), 1, 'uma feature';
};

subtest '504 é transitório: retenta e conclui' => sub {
  my $svc = Test::OSM::Scripted->new(
    query          => $q,
    backoff_base   => 0,
    jitter         => 0,
    max_tentativas => 3,
    script         => [ [504], [504], [200, { elements => [$node] }] ],
  );

  my $gj = $svc->run;
  is scalar(@{ $svc->calls }), 3, 'três chamadas (2x 504 + 1x sucesso)';
  is $gj->{type}, 'FeatureCollection', 'conclui após dois retries';
};

subtest '4xx definitivo (400) NÃO é retentado' => sub {
  my $svc = Test::OSM::Scripted->new(
    query          => $q,
    backoff_base   => 0,
    jitter         => 0,
    max_tentativas => 3,
    script         => [ [400] ],
  );

  my $err = eval { $svc->run; 1 } ? undef : $@;
  ok $err, 'propaga o erro';
  like $err, qr/HTTP 400/, 'mensagem preservada';
  is scalar(@{ $svc->calls }), 1, 'uma só chamada: 400 não se repete';
};

subtest 'falha transitória persistente morre no limite de tentativas' => sub {
  my $svc = Test::OSM::Scripted->new(
    query          => $q,
    backoff_base   => 0,
    jitter         => 0,
    max_tentativas => 3,
    script         => [ [504], [504], [504] ],
  );

  my $err = eval { $svc->run; 1 } ? undef : $@;
  ok $err, 'propaga depois de esgotar as tentativas';
  like $err, qr/HTTP 504/, 'erro original preservado';
  is scalar(@{ $svc->calls }), 3, 'exatamente max_tentativas chamadas';
};

subtest 'sucesso limpa o rasto de HTTP' => sub {
  my $svc = Test::OSM::Scripted->new(
    query  => $q,
    script => [ [200, { elements => [] }] ],
  );

  $svc->run;
  is $svc->_http_code, undef, 'sem código de erro pendente após sucesso';
};

# Repetição espaçada (#131): consultas ao Overpass NÃO correm em paralelo
# (flock) e são espaçadas por `min_interval` via estampilho em `lock_dir`.
subtest 'min_interval espaça chamadas consecutivas (repetição espaçada)' => sub {
  my $dir = File::Temp::tempdir(CLEANUP => 1);
  # Estampilho como se a última chamada fosse agora: força a espera. Com
  # min_interval=2, mesmo que a leitura caia no segundo seguinte, a espera
  # é >= 1s — a asserção tolera a granularidade de `time` sem flutuar.
  path($dir, 'overpass.last')->spew(time);

  my $svc = Test::OSM::Scripted->new(
    query        => $q,
    lock_dir     => $dir,
    min_interval => 2,
    script       => [ [200, { elements => [] }] ],
  );

  my $t0 = Time::HiRes::time;
  $svc->run;
  my $dt = Time::HiRes::time - $t0;
  ok $dt >= 0.5, sprintf('esperou pelo intervalo antes de chamar (%.2fs)', $dt);
};

subtest 'min_interval=0 desliga o espaçamento (sem estampilho)' => sub {
  my $dir = File::Temp::tempdir(CLEANUP => 1);

  my $svc = Test::OSM::Scripted->new(
    query        => $q,
    lock_dir     => $dir,
    min_interval => 0,
    script       => [ [200, { elements => [] }] ],
  );

  $svc->run;
  ok !-f path($dir, 'overpass.last'), 'sem espaçamento: nenhum estampilho gravado';
};

done_testing;
