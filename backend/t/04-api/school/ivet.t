# t/04-api/school/ivet.t
# Testes da rota do IVET materializado (issue #296):
#   GET /api/school/:cod_inep/ivet
#
# A rota lê a última medição vigente em analytics.ivet_escola (job
# refresh_ivet). É um teste de integração: usa o banco de teste (a change
# analytics_ivet_escola precisa estar deployada — o `ci_db.sh up` do CI
# faz isso) com fixture própria e INEPs fora do censo real, para não
# depender do estado do painel.
#
# Regras verificadas aqui:
#   - snapshot mais recente vence (regra da view nacional, max(dt_snapshot));
#   - ausência vira JSON null, nunca 0 (#154);
#   - escola sem medição -> 404.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;

my @FIXTURE = (99999998, 99999997, 99999996); # INEPs de teste
sub _limpar {
  $dbh->do(
    'DELETE FROM analytics.ivet_escola WHERE co_entidade IN (?,?,?)',
    undef, @FIXTURE
  );
}

# limpa resíduos de execuções anteriores e garante a limpeza no fim
_limpar();
END { eval { _limpar() } }

sub _inserir ($co, %campos) {
  my %base = (
    nu_ano_censo      => 2025,
    raio_m            => 1000,
    ivet              => 0.42,
    publicavel        => 1,
    bloco_a           => 0.10,
    bloco_b           => 0.20,
    bloco_c           => 0.30,
    bloco_d           => 0.40,
    bloco_e           => 0.50,
    bloco_f           => 0.60,
    bloco_g           => 0.70,
    formula           => 'ivet-v1.2-teste',
    dataset_version   => undef,
    transform_version => undef,
    dt_snapshot       => '2026-10-20',
  );
  my %c = (%base, %campos);
  $dbh->do(
    q{
      INSERT INTO analytics.ivet_escola
        (co_entidade, nu_ano_censo, raio_m, ivet, publicavel,
         bloco_a, bloco_b, bloco_c, bloco_d, bloco_e, bloco_f, bloco_g,
         formula, dataset_version, transform_version, dt_snapshot)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    },
    undef,
    $co, @c{qw/nu_ano_censo raio_m ivet publicavel
                bloco_a bloco_b bloco_c bloco_d bloco_e bloco_f bloco_g
                formula dataset_version transform_version dt_snapshot/}
  );
}

subtest 'devolve a medição vigente da escola' => sub {
  _inserir(99999998);

  my $res  = $t->get_ok('/api/school/99999998/ivet')->status_is(200)->tx->res;
  my $json = $res->json;

  is $json->{co_entidade},   99999998,   'co_entidade';
  is $json->{nu_ano_censo},  2025,       'nu_ano_censo';
  is $json->{raio_m},        1000,       'raio_m';
  is $json->{ivet},          0.42,       'ivet';
  is $json->{formula},       'ivet-v1.2-teste', 'formula (proveniência)';
  is $json->{dt_snapshot},   '2026-10-20', 'dt_snapshot';
  like $res->text, qr/"publicavel":true/, 'publicavel é JSON true';
  ok defined $json->{calculado_em}, 'calculado_em presente';

  is $json->{blocos}{A}, 0.10, 'bloco A';
  is $json->{blocos}{C}, 0.30, 'bloco C';
  is $json->{blocos}{G}, 0.70, 'bloco G';
  ok !exists $json->{bloco_a}, 'chaves bloco_a..g não vazam (só blocos {})';
};

subtest 'snapshot mais recente vence (regra max(dt_snapshot))' => sub {
  _limpar();
  _inserir(99999998);                                    # 2026-10-20, 0.42
  _inserir(99999998, dt_snapshot => '2026-10-21', ivet => 0.77);

  my $res = $t->get_ok('/api/school/99999998/ivet')->status_is(200)->tx->res;
  my $json = $res->json;
  is $json->{ivet},        0.77,      'linha do snapshot novo vence';
  is $json->{dt_snapshot}, '2026-10-21', 'snapshot novo exposto';
};

subtest 'ausência vira JSON null, nunca 0 (#154)' => sub {
  _inserir(
    99999997,
    ivet              => undef,
    publicavel        => 0,
    bloco_f           => undef,
    dataset_version   => undef,
    transform_version => undef,
  );

  my $res  = $t->get_ok('/api/school/99999997/ivet')->status_is(200)->tx->res;
  my $json = $res->json;

  like $res->text, qr/"ivet":null/,            'ivet null (não publicável)';
  like $res->text, qr/"publicavel":false/,     'publicavel é JSON false';
  like $res->text, qr/"F":null/,               'bloco F null (não calculado)';
  like $res->text, qr/"dataset_version":null/, 'proveniência ausente null';
  is $json->{blocos}{C}, 0.30, 'bloco C calculado continua valorado';
};

subtest 'escola sem medição -> 404' => sub {
  $t->get_ok('/api/school/99999996/ivet')->status_is(404);
};

done_testing;
