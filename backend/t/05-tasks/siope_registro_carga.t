# t/05-tasks/siope_registro_carga.t
# #564 (QQ-02 da P6): cada carga da folha registrada em clean.import_metadata,
# com uma entrada por município e ano. A planilha é simulada: nada vai ao SIOPE.
use Mojo::Base -strict, -signatures;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use utf8;
use Mojo::JSON qw(decode_json);
use EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos;
use EduMaps::BaseAnalise;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $minion = $t->app->minion;
my $dbh = $t->app->schema->storage->dbh;
my $rs = $t->app->schema->resultset('RemuneracaoMunicipal');
my ($COD, $ANO, $FILA) = ('600564', 2001, "teste_registro_$$");
my $INEP = '60056401';   # a escola do teste, só deste arquivo
my $MUN7 = '6005640';
my $TAB = 'clean.remuneracao_municipal';
my @JOBS;

# o estado do registro antes do teste, para devolver no fim
my ($ANTES) = $dbh->selectrow_array('SELECT raw_manifest::text FROM clean.import_metadata WHERE table_name = ?', undef, $TAB);
my ($EXISTIA) = $dbh->selectrow_array('SELECT 1 FROM clean.import_metadata WHERE table_name = ?', undef, $TAB);

my $limpa = sub {
  $rs->search({ cod_municipio => $COD })->delete;
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', undef, $INEP);
  # tira só as entradas deste teste; sem linha antes, apaga a linha
  if ($EXISTIA) {
    $dbh->do(q{UPDATE clean.import_metadata SET raw_manifest =
                 (SELECT jsonb_agg(x) FROM jsonb_array_elements(raw_manifest) x WHERE x->>'cod_municipio' <> ?)
               WHERE table_name = ?}, undef, $COD, $TAB);
  } else {
    $dbh->do('DELETE FROM clean.import_metadata WHERE table_name = ?', undef, $TAB);
  }
};
$limpa->();
END {
  $limpa->() if $rs;
  for my $id (@JOBS) { my $j = $minion->job($id) or next; $j->remove }
}

my @PLANILHA;
my $FALHAR = 0;
{
  no warnings 'redefine';
  *EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos::get_and_process = sub ($self) {
    die "SIOPE fora do ar\n" if $FALHAR;
    return [ map { [@$_] } @PLANILHA ];
  };
  *EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos::arquivo = sub ($self) {
    return { url => 'https://www.fnde.gov.br/siope/consultarRemuneracaoMunicipal.do?municipios=' . $self->cod_mun,
             sha256 => 'ab' x 32, bytes => 4096 };
  };
}
sub linha ($mes) {
  return [$ANO, $mes, 'ANA DO TESTE', 'xxx.564.222-xx', 60056401, 'ESCOLA DO TESTE', 40,
          'Profissionais do magistério', 'Docente', 'Efetivo', 'Ensino fundamental', 1000, 1000, 0, 0, 1000];
}
sub carregar () {
  local $t->app->config->{minion_filas}{query_siope} = $FILA;
  my $id = $t->app->get_siope($COD, $ANO);
  push @JOBS, $id;
  $minion->perform_jobs({ queues => [$FILA] });
  return $minion->job($id);
}
sub entradas () {
  my ($m) = $dbh->selectrow_array('SELECT raw_manifest::text FROM clean.import_metadata WHERE table_name = ?', undef, $TAB);
  return [ grep { $_->{cod_municipio} eq $COD } @{ decode_json($m // '[]') } ];
}

# o município no Censo, para entrar na cobertura da folha
$dbh->do(q{INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf)
           VALUES (2025, ?, 'ESCOLA DO TESTE', 3, ?, 'Município do Teste', 'AC')}, undef, $INEP, $MUN7);

@PLANILHA = (linha('Janeiro'), linha('Fevereiro'));
is carregar()->info->{state}, 'finished', 'carga';
my $e = entradas();
is scalar @$e, 1, 'uma entrada do município e ano';
is [ @{ $e->[0] }{qw(ano linhas sha256 bytes)} ], [$ANO, 2, 'ab' x 32, 4096], 'ano, linhas e o arquivo';
like $e->[0]{baixado_em}, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/, 'data e hora da carga';
unlike $e->[0]{url}, qr/recaptcha/, 'URL sem o captcha';
my ($m) = grep { $_->{codigo_ibge} eq $MUN7 } @{ EduMaps::BaseAnalise->cobertura_siope($dbh, 'AC') };
is $m->{anos}[0]{carga}, substr($e->[0]{baixado_em}, 0, 10), 'a data da carga na cobertura do município';
# #576 (QH-02 da P5): o painel da escola traz a data da carga registrada
my $fin = $t->get_ok("/api/school/$INEP/finance?ano=$ANO")->status_is(200)->tx->res->json;
is $fin->{carga_folha}, substr($e->[0]{baixado_em}, 0, 10), 'painel: a data da carga do município e ano';

@PLANILHA = (linha('Janeiro'), linha('Fevereiro'), linha('Março'));
is carregar()->info->{state}, 'finished', 'recarga';
$e = entradas();
is scalar @$e, 1, 'recarga troca a entrada, sem duplicar';
is $e->[0]{linhas}, 3, 'com as linhas novas';

$FALHAR = 1;
isnt carregar()->info->{state}, 'finished', 'carga que falha (volta à fila para nova tentativa)';
is entradas()->[0]{linhas}, 3, 'não mexe no registro';
is $rs->search({ cod_municipio => $COD, ano => $ANO })->count, 3, 'nem na folha';

done_testing;
