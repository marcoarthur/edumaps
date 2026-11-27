# t/04-api/folha_quebra_ano.t
# #604 (QD-02 da P2): a folha do magistério de um ano não se compara à do
# anterior quando o município muda a forma de declarar ao SIOPE (Cuiabá:
# 6 abaixo do piso em 2025, 1.559 em 2026, com o total da Secretaria de 60
# para 3.141 só ali). A contagem traz a comparação e o motivo; a lista do
# ano e a folha por município também.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::BaseAnalise ();

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

plan skip_all => 'clean.remuneracao_municipal ausente'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.remuneracao_municipal')");

my $INEP   = '60060401';
my $CO_MUN = '6006041';
my $MUN    = '600604';
my $MAG    = 'Profissionais do magistério';
my $SEC    = 99999999;

sub limpar {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
}
limpar();
END { limpar(); $dbh->do('SELECT analytics.refresh_salario_rede()') if $dbh }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf)
          VALUES (2025, ?, ?, 3, ?, ?, ?)', {}, $INEP, 'Escola da Quebra', $CO_MUN, 'Município da Quebra', 'AC');
my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
   (ano, mes, nome_profissional, cpf, cod_inep, escola, cod_municipio, rede, categoria, tipo, situacao, carga_horaria, salario_base, salario_total)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
sub pagar ($ano, $nome, $lugar, $sit, $base) {
  $f->execute($ano, $_, $nome, "xxx.$nome.604-xx", $lugar, ($lugar == $SEC ? 'SEC MUN' : 'ESCOLA DA QUEBRA'),
    $MUN, 'Municipal', 'Docente', $MAG, $sit, 40, $base, $base) for qw(Janeiro Fevereiro Março);
}
# 2024 e 2025: quatro na escola, um abaixo do piso; 2025 se compara a 2024.
for my $ano (2024, 2025) {
  pagar($ano, $_, $INEP, 'Efetivo', 6000) for qw(ANA BIA CAIO);
  pagar($ano, 'DUDA', $INEP, 'Temporário', 3000);
}
# 2026: os mesmos quatro e mais seis temporários só no total da Secretaria,
# todos abaixo do piso: o magistério vai de 4 para 10 e a parte só na
# Secretaria de 0% para 60%.
pagar(2026, $_, $INEP, 'Efetivo', 6000) for qw(ANA BIA CAIO);
pagar(2026, 'DUDA', $INEP, 'Temporário', 3000);
pagar(2026, $_, $SEC, 'Temporário', 3000) for qw(EVA FABI GIL HUGO IRIS JOAO);
$dbh->do('SELECT analytics.refresh_salario_rede()');

my $s = EduMaps::BaseAnalise->salario_rede($dbh, $MUN);

subtest 'na contagem' => sub {
  is $s->{"$MUN|2024"}{comparacao_ano_anterior}, undef, 'sem o ano anterior: sem comparação';
  my $c25 = $s->{"$MUN|2025"}{comparacao_ano_anterior};
  is [ !!${ $c25->{comparavel} }, $c25->{motivos} ], [1, []], '2025 se compara a 2024';
  my $c = $s->{"$MUN|2026"}{comparacao_ano_anterior};
  is [ !!${ $c->{comparavel} }, $c->{motivos} ], ['', [qw(magisterio secretaria)]], '2026 não se compara: os dois motivos';
  is [ @$c{qw(ano_anterior magisterio magisterio_anterior so_secretaria so_secretaria_anterior
              pct_so_secretaria pct_so_secretaria_anterior abaixo_piso_anterior)} ],
     [2025, 10, 4, 6, 0, 60, 0, 1], 'os números dos dois anos';
};

subtest 'a regra' => sub {
  my $v = sub ($mag, $sec, $meses) { { _vol => { mag => $mag, so_sec => $sec, meses => $meses } } };
  my $m = sub ($at, $ant) { EduMaps::BaseAnalise::_comparacao_ano($at, $ant, 2025)->{motivos} };
  is $m->($v->(140, 0, 11), $v->(100, 0, 11)), [], 'cresce 40%: compara';
  is $m->($v->(150, 0, 11), $v->(100, 0, 11)), ['magisterio'], 'cresce 50%: não compara';
  is $m->($v->(60, 0, 11), $v->(100, 0, 11)), ['magisterio'], 'cai 40% com o ano completo: não compara';
  is $m->($v->(60, 0, 8), $v->(100, 0, 11)), [], 'cai 40% num ano em curso: compara (faltam meses)';
  is $m->($v->(100, 25, 11), $v->(100, 10, 11)), [], 'Secretaria de 10% para 25%: compara';
  is $m->($v->(100, 30, 11), $v->(100, 10, 11)), ['secretaria'], 'de 10% para 30%: não compara';
};

subtest 'na lista do ano e na folha por município' => sub {
  my $r = $t->get_ok("/api/city/$CO_MUN/piso?ano=2026")->status_is(200)->tx->res->json;
  is [ $r->{total}, $r->{comparacao_ano_anterior}{comparavel}, $r->{comparacao_ano_anterior}{abaixo_piso_anterior} ],
     [7, F(), 1], 'a lista traz a comparação';
  my ($cab, $linhas) = EduMaps::BaseAnalise->folha_municipios($dbh, 'AC');
  my ($i) = grep { $cab->[$_] eq 'comparavel_ano_anterior' } 0 .. $#$cab;
  ok defined $i, 'a coluna no CSV';
  my %por = map { ($_->[3] => $_->[$i]) } grep { $_->[0] eq $CO_MUN } @$linhas;
  is [ @por{2024, 2025, 2026} ], [undef, 'sim', 'não'], 'vazio, sim e não';
};

done_testing;
