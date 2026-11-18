# t/04-api/school/finance_pessoa_ano.t
# #491: o painel financeiro conta a pessoa pelo CPF mascarado E o nome
# (RJ-01) e mostra um ano por vez, com o período (RJ-02).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

plan skip_all => 'clean.remuneracao_municipal ausente'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.remuneracao_municipal')");

my $INEP   = '60049101';
my $CO_MUN = '6004911';
my $MUN    = '600491';

sub _limpar {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
}
_limpar();
END { eval { _limpar() } }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio)
          VALUES (2025, ?, ?, 3, ?)', {}, $INEP, 'Escola da Folha', $CO_MUN);

sub _folha ($ano, $mes, $nome, $cpf, $salario) {
  $dbh->do('INSERT INTO clean.remuneracao_municipal
              (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, salario_total, carga_horaria)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 40)',
    {}, $ano, $mes, $nome, $cpf, $INEP, $MUN, 'Municipal',
    'Docente habilitado em curso de pedagogia', 'Profissionais do magistério', $salario);
}

# Duas pessoas com o MESMO CPF mascarado (nomes diferentes), em 2025.
for my $mes (qw(Janeiro Fevereiro Dezembro)) {
  _folha(2025, $mes, 'ANA SOUZA',   'xxx.123.451-xx', 5000);
  _folha(2025, $mes, 'BRUNO LIMA',  'xxx.123.451-xx', 6000);
}
# 2026: só janeiro, uma pessoa.
_folha(2026, 'Janeiro', 'ANA SOUZA', 'xxx.123.451-xx', 5200);

subtest 'conta a pessoa, não o CPF mascarado (RJ-01)' => sub {
  my $r = $t->get_ok("/api/school/$INEP/finance?ano=2025")->status_is(200)->tx->res->json;
  is $r->{total_profissionais}, 2, 'duas pessoas com o mesmo CPF mascarado contam duas';
  is $r->{series}[0]{total_profissionais}, 2, 'no mês também';
  is $r->{categorias}[0]{total_profissionais}, 2, 'na categoria também';
};

subtest 'um ano por vez, com o período (RJ-02)' => sub {
  my $r = $t->get_ok("/api/school/$INEP/finance")->status_is(200)->tx->res->json;
  is $r->{ano}, 2026, 'sem o parâmetro, o ano mais recente';
  is $r->{anos}, [2026, 2025], 'anos com folha, do mais novo ao mais antigo';
  is $r->{periodo}, { mes_inicial => 1, mes_final => 1, meses => 1 }, 'período de 2026';
  is scalar @{ $r->{series} }, 1, 'série só de 2026';
  is $r->{categorias}[0]{total_salario}, 5200, 'categoria só de 2026';

  $r = $t->get_ok("/api/school/$INEP/finance?ano=2025")->status_is(200)->tx->res->json;
  is $r->{ano}, 2025, 'ano pedido';
  is $r->{periodo}, { mes_inicial => 1, mes_final => 12, meses => 3 }, 'período de 2025';
  is $r->{categorias}[0]{total_salario}, 33000, 'categoria soma só 2025 (com dezembro)';

  $t->get_ok("/api/school/$INEP/finance?ano=2019")->status_is(400)
    ->json_is('/anos', [2026, 2025]);
  $t->get_ok("/api/school/$INEP/finance?ano=abc")->status_is(400);
};

subtest 'folha detalhada da competência conta a pessoa' => sub {
  my $r = $t->get_ok("/api/school/$INEP/payroll?date=01-2025")->status_is(200)->tx->res->json;
  my $linhas = ref $r eq 'ARRAY' ? $r : [$r];
  ok scalar(@$linhas) >= 2, 'as duas pessoas na folha do mês';
};

done_testing;
