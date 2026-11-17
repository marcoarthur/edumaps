# t/04-api/indices_sem_registro.t
# #467 (RZ-01): escola sem o registro de que um índice depende (matrículas,
# docentes, gestores) fica sem o índice (NULL na MV, vazio na base, fora do
# ranking), não com 0. A MV só se refaz com REFRESH (pesado e global), então
# o teste usa uma escola que já está nela sem docentes; sem nenhuma, pula.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::Util qw(decode);

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

subtest 'MV: nenhum 0 no lugar do registro ausente' => sub {
  my %regra = (
    score_capacitacao_docente    => q{SELECT 1 FROM clean.censo_docentes x WHERE x.co_entidade = s.co_entidade AND x.nu_ano_censo = s.nu_ano_censo AND x.qt_doc_bas > 0},
    score_diversidade_discente   => q{SELECT 1 FROM clean.censo_matriculas x WHERE x.co_entidade = s.co_entidade AND x.nu_ano_censo = s.nu_ano_censo AND x.qt_mat_bas > 0},
    score_capacidade_atendimento => q{SELECT 1 FROM clean.censo_matriculas x WHERE x.co_entidade = s.co_entidade AND x.nu_ano_censo = s.nu_ano_censo AND x.qt_mat_bas > 0},
    score_capacidade_gestora     => q{SELECT 1 FROM clean.censo_gestor x WHERE x.co_entidade = s.co_entidade AND x.nu_ano_censo = s.nu_ano_censo AND x.qt_gest_bas > 0},
  );
  for my $col (sort keys %regra) {
    my ($com_valor) = $dbh->selectrow_array(
      "SELECT count(*) FROM clean.mv_escolas_scores s WHERE s.$col IS NOT NULL AND NOT EXISTS ($regra{$col})");
    is $com_valor, 0, "$col: vazio sem o registro";
    my ($sem_valor) = $dbh->selectrow_array(
      "SELECT count(*) FROM clean.mv_escolas_scores s WHERE s.$col IS NULL AND EXISTS ($regra{$col})");
    is $sem_valor, 0, "$col: com o registro, tem o índice";
  }
  my ($nulos) = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.mv_escolas_scores WHERE score_infraestrutura IS NULL OR score_sustentabilidade IS NULL');
  is $nulos, 0, 'infraestrutura e sustentabilidade sempre presentes';
};

sub ler ($tx) {
  my $txt = decode('UTF-8', $tx->res->body) =~ s/^\x{FEFF}//r;
  return [ map { [ split /;/, $_, -1 ] } split /\r\n/, $txt ];
}

my $s = $dbh->selectrow_hashref(q{
  SELECT s.co_entidade::text AS inep, e.sg_uf, e.co_municipio::text AS mun
    FROM clean.mv_escolas_scores s
    JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
   WHERE s.score_capacitacao_docente IS NULL AND e.tp_situacao_funcionamento = 1
     AND s.nu_ano_censo = (SELECT max(nu_ano_censo) FROM clean.mv_escolas_scores)
   ORDER BY s.co_entidade LIMIT 1});

SKIP: {
  skip 'nenhuma escola sem docentes na MV', 2 unless $s;

  subtest 'base: célula vazia' => sub {
    my $tx = $t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=indices")->status_is(200)->tx;
    my @l = @{ ler($tx) };
    my %i; @i{ @{ $l[0] } } = 0 .. $#{ $l[0] };
    my ($linha) = grep { $_->[0] eq $s->{inep} } @l[1 .. $#l];
    ok $linha, 'a escola está na base';
    is $linha->[ $i{indice_capacitacao_docente} ], '', 'capacitação docente vazia, não 0';
    isnt $linha->[ $i{indice_infraestrutura} ], '', 'infraestrutura presente';
    my $d = ler($t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=docencia")->tx);
    my %j; @j{ @{ $d->[0] } } = 0 .. $#{ $d->[0] };
    my ($ld) = grep { $_->[0] eq $s->{inep} } @$d[1 .. $#$d];
    is [ @$ld[ @j{qw(prop_superior prop_pos_graduacao prop_formacao_continuada)} ] ], ['', '', ''],
      'partes do índice vazias sem docentes (#469; LEAST(1, NULL) seria 1)';
  };

  subtest 'ranking de escolas: fora do índice sem registro' => sub {
    my $r = $t->get_ok("/api/ranking/escolas?codigo_ibge=$s->{mun}&indicador=capacitacao_docente")->tx->res->json;
    ok !(grep { $_->{co_entidade} eq $s->{inep} } @{ $r->{escolas} // [] }), 'escola sem docentes fora do ranking';
    my $i = $t->get_ok("/api/ranking/escolas?codigo_ibge=$s->{mun}&indicador=infraestrutura")->tx->res->json;
    ok( (grep { $_->{co_entidade} eq $s->{inep} } @{ $i->{escolas} // [] }), 'mas segue no de infraestrutura');
  };
}

done_testing;
