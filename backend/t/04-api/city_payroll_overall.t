# t/04-api/city_payroll_overall.t
# #554 (observação da avaliação QS-02 da P5): o total da folha do município
# saía com o acento codificado duas vezes ("SÃ£o Paulo"): o modelo já
# devolve o JSON em bytes UTF-8, e a rota codificava de novo.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my ($IBGE, $ANTIGO) = $dbh->selectrow_array(
  q{SELECT codigo_ibge, codigo_ibge_antigo FROM clean.municipios_sp WHERE nome_estado = 'São Paulo' ORDER BY codigo_ibge LIMIT 1}
);
plan skip_all => 'sem município de SP em clean.municipios_sp' unless $IBGE;

my $ANO = 2003;   # ano que nenhuma carga tem
$dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ? AND ano = ?', {}, $ANTIGO, $ANO);
$dbh->do(q{INSERT INTO clean.remuneracao_municipal
             (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, salario_total)
           VALUES (?, 'Janeiro', 'TESTE', 'xxx.000.001-xx', 99999999, ?, 'Municipal', 'Docente', 'Profissionais do magistério', 1234)},
  {}, $ANO, $ANTIGO);
END { $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ? AND ano = ?', {}, $ANTIGO, $ANO) if $dbh && $ANTIGO }

my $r = $t->get_ok("/api/city/$IBGE/payroll/overall")->status_is(200)
  ->content_type_like(qr/json/)->tx->res->json;
my ($linha) = grep { $_->{ano} == $ANO } @$r;
ok $linha, 'o ano do teste na resposta';
is $linha->{nome_estado}, 'São Paulo', 'nome do estado sem acento quebrado';
is 0 + $linha->{total_folha_salario}, 1234, 'total da folha';

done_testing;
