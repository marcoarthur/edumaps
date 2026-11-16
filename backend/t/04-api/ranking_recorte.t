# t/04-api/ranking_recorte.t
# #430 (AN-11): ranking por recorte — escolas de um município e redes
# municipais de uma UF, com o mínimo de escolas, a variação entre edições e o
# INSE como contexto. Municípios e escolas fictícios (UF "XX").
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use EduMaps::Regiao;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

# A (6000301): 4 escolas em 2023 e em 2021; B (6000302): 3 escolas só em
# 2023; C (6000303): 2 escolas (fica de fora pelo mínimo).
my @ESC = (
  # inep,        mun,      2023, 2021,  inse
  ['60003001', 6000301, 6.0, 5.0, 5.0],
  ['60003002', 6000301, 5.0, 4.0, 5.0],
  ['60003003', 6000301, 7.0, 6.0, 5.0],
  ['60003004', 6000301, 6.0, 5.0, 5.0],
  ['60003005', 6000302, 7.0, undef, 4.0],
  ['60003006', 6000302, 7.0, undef, 4.0],
  ['60003007', 6000302, 7.0, undef, 4.0],
  ['60003008', 6000303, 9.0, undef, 6.0],
  ['60003009', 6000303, 9.0, undef, 6.0],
);
my %NOME = (6000301 => 'Alfa do Teste', 6000302 => 'Beta do Teste', 6000303 => 'Gama do Teste');
my @INEPS = map { $_->[0] } @ESC;
my $ph = join ',', ('?') x @INEPS;

my $limpa = sub {
  $dbh->do("DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN ($ph)", {}, @INEPS);
  $dbh->do("DELETE FROM clean.inse WHERE id_escola IN ($ph)", {}, @INEPS);
  $dbh->do(q{DELETE FROM clean.populacao_municipal WHERE codigo_ibge IN ('6000301', '6000302')});
};
$limpa->();
END { $limpa->() }

my $ins = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas
  (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa, ideb_observado)
  VALUES (?, 'XX', ?, ?, ?, 'Municipal', ?, 'fundamental_i', ?)});
my $inse = $dbh->prepare(q{INSERT INTO clean.inse (nu_ano_saeb, id_escola, media_inse) VALUES (2023, ?, ?)});
for my $e (@ESC) {
  my ($inep, $mun, $v23, $v21, $nse) = @$e;
  $ins->execute($inep, $mun, $NOME{$mun}, "Escola $inep", 2023, $v23);
  $ins->execute($inep, $mun, $NOME{$mun}, "Escola $inep", 2021, $v21) if defined $v21;
  $inse->execute($inep, $nse);
}

# Porte (#439): Alfa com 5.000 habitantes (limite de "até 5 mil"), Beta com
# 15 mil; Gama sem população carregada.
$dbh->do(q{INSERT INTO clean.populacao_municipal (nome_municipio, populacao_estimada, codigo_ibge)
           VALUES ('Alfa do Teste', 5000, '6000301'), ('Beta do Teste', 15000, '6000302')});

subtest 'redes municipais da UF' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX')->status_is(200)->tx->res->json;
  is $r->{ano}, 2023, 'edição atual';
  is $r->{ano_anterior}, 2021, 'edição anterior';
  is $r->{minimo_escolas}, 3, 'mínimo de escolas';
  is $r->{fora_por_poucas_escolas}, 1, 'Gama (2 escolas) fora';
  is [map { $_->{municipio} } @{ $r->{redes} }], ['Beta do Teste', 'Alfa do Teste'], 'ordem pela média';

  my %rede = map { $_->{municipio} => $_ } @{ $r->{redes} };
  is $rede{'Beta do Teste'}{media}, 7, 'média simples das escolas';
  is $rede{'Alfa do Teste'}{media}, 6, 'média de Alfa';
  is $rede{'Alfa do Teste'}{variacao}, 1, 'variação 2021→2023';
  is $rede{'Beta do Teste'}{variacao}, undef, 'sem edição anterior: sem variação';
  is $rede{'Alfa do Teste'}{escolas}, 4, 'escolas contadas';
  is $rede{'Alfa do Teste'}{inse}, 5, 'INSE médio das escolas da rede';
  ok defined $rede{'Alfa do Teste'}{quinto_inse}, 'quinto de INSE';
  is $rede{'Alfa do Teste'}{posicao}, 2, 'posição';
};

subtest 'porte do município (#439)' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX')->status_is(200)->tx->res->json;
  my %rede = map { $_->{municipio} => $_ } @{ $r->{redes} };
  is $rede{'Alfa do Teste'}{populacao}, 5000, 'população';
  is $rede{'Alfa do Teste'}{porte}, 'ate_5mil', '5.000 entra em "até 5 mil"';
  is $rede{'Beta do Teste'}{porte}, '10_20mil', '15 mil: de 10 a 20 mil';
  is scalar @{ $r->{portes} }, 7, 'as sete classes do IBGE';
  is $r->{populacao_fonte}{ano}, '2025', 'ano da estimativa, do catálogo de fontes';

  $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&porte=ate_5mil')
    ->status_is(200)->tx->res->json;
  is [map { $_->{municipio} } @{ $r->{redes} }], ['Alfa do Teste'], 'só as redes do porte';
  is $r->{redes}[0]{posicao}, 1, 'posição entre as do mesmo porte';
  is $r->{recorte}{porte}, 'ate_5mil', 'porte no recorte';
  is $r->{fora_por_poucas_escolas}, 0, 'Gama (sem população) não conta no porte';

  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&porte=mais_500mil')
    ->status_is(200)->json_is('/total' => 0, 'porte sem rede: lista vazia, não erro');
  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&porte=enorme')->status_is(400);
};

# Salto atípico (#437): UF "XY", 8 redes de 3 escolas com 2021 e 2023;
# sete variam pouco (0 a 0,3) e uma salta 3 pontos.
my @ATIP;
for my $m (0 .. 7) {
  my $mun = 6000311 + $m;
  my $salto = $m == 7 ? 3 : $m * 0.04;
  for my $k (1 .. 3) {
    push @ATIP, [sprintf('600031%02d', $m * 3 + $k), $mun, 5 + $salto, 5];
  }
}
my @INEPS_ATIP = map { $_->[0] } @ATIP;
my $ph2 = join ',', ('?') x @INEPS_ATIP;
my $limpa2 = sub { $dbh->do("DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN ($ph2)", {}, @INEPS_ATIP) };
$limpa2->();
END { $limpa2->() }
my $ins2 = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas
  (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa, ideb_observado)
  VALUES (?, 'XY', ?, ?, 'Escola', 'Municipal', ?, 'fundamental_i', ?)});
for my $e (@ATIP) {
  $ins2->execute($e->[0], $e->[1], "Mun $e->[1]", 2023, $e->[2]);
  $ins2->execute($e->[0], $e->[1], "Mun $e->[1]", 2021, $e->[3]);
}

subtest 'salto atípico e mínimo ajustável (#437)' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XY')->status_is(200)->tx->res->json;
  is $r->{total}, 8, 'oito redes';
  is $r->{atipico}{desvios}, 2, 'regra de 2 desvios';
  is $r->{atipico}{marcadas}, 1, 'uma rede marcada';
  my @marcadas = map { $_->{codigo_ibge} } grep { $_->{atipico} } @{ $r->{redes} };
  is \@marcadas, ['6000318'], 'só a que saltou 3 pontos';
  ok $r->{atipico}{limite_superior} < 3, 'limite abaixo do salto';

  $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&minimo=4')->status_is(200)->tx->res->json;
  is $r->{minimo_escolas}, 4, 'mínimo vindo do parâmetro';
  is [map { $_->{municipio} } @{ $r->{redes} }], ['Alfa do Teste'], 'só Alfa tem 4 escolas';
  is $r->{fora_por_poucas_escolas}, 2, 'Beta e Gama fora';
  is $r->{atipico}{marcadas}, 0, 'com uma variação só, ninguém é marcado';

  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&minimo=2')->status_is(400);
  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&minimo=31')->status_is(400);
  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&minimo=3.5')->status_is(400);
};

# Região (#445): uma região fictícia "TT" com as UFs de teste XX e XY. A
# região só restringe as UFs; posição, INSE e salto atípico são dela.
subtest 'região (#445)' => sub {
  is [EduMaps::Regiao->ids], [qw(N NE SE S CO)], 'as cinco regiões do IBGE';
  is(EduMaps::Regiao->ufs('NE'), [qw(AL BA CE MA PB PE PI RN SE)], 'UFs do Nordeste');
  my %todas; $todas{$_}++ for map { @{ $_->{ufs} } } @{ EduMaps::Regiao->lista };
  is [sort keys %todas], [sort qw(AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO)],
    'as 27 UFs, cada uma numa região';
  ok !(grep { $_ > 1 } values %todas), 'nenhuma UF em duas regiões';

  # #448: o CASE SQL da base de análise dá a região de cada UF.
  my $case = EduMaps::Regiao->case_sql('u');
  my $got = $dbh->selectall_arrayref("SELECT u, $case FROM unnest(?::text[]) u", undef, [sort keys %todas]);
  my %esperado = map { my $r = $_; map { $_ => $r->{label} } @{ $r->{ufs} } } @{ EduMaps::Regiao->lista };
  is { map { @$_ } @$got }, \%esperado, 'case_sql: a região das 27 UFs';
  is scalar $dbh->selectrow_array("SELECT $case FROM (SELECT 'XX'::text u) t"), undef, 'UF desconhecida: sem região';

  local @EduMaps::Regiao::REGIOES = (@EduMaps::Regiao::REGIOES, { id => 'TT', label => 'Teste', ufs => [qw(XX XY)] });

  my $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&regiao=TT')->status_is(200)->tx->res->json;
  is $r->{total}, 10, 'as redes das duas UFs (2 de XX e 8 de XY)';
  is [sort { $a cmp $b } keys %{{ map { $_->{uf} => 1 } @{ $r->{redes} } }}], [qw(XX XY)], 'só UFs da região';
  is $r->{recorte}{regiao}, { id => 'TT', nome => 'Teste' }, 'região no recorte';
  ok !exists $r->{recorte}{nacional}, 'não é o nacional';
  is $r->{fora_por_poucas_escolas}, 1, 'Gama fora pelo mínimo';
  my %rede = map { $_->{municipio} => $_ } @{ $r->{redes} };
  is $r->{redes}[0]{uf}, 'XY', 'a rede com o salto (8,0) lidera a região';
  is $rede{'Beta do Teste'}{posicao}, 2, 'Beta (7,0), primeira na UF, é a segunda na região';
  is $r->{atipico}{marcadas}, 1, 'salto atípico medido na região';
  ok( (grep { $_->{id} eq 'TT' } @{ $r->{regioes} }), 'lista de regiões na resposta');

  $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&regiao=TT&porte=ate_5mil')->status_is(200)->tx->res->json;
  is [map { $_->{municipio} } @{ $r->{redes} }], ['Alfa do Teste'], 'região com porte';

  $r = $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&uf=XX&regiao=TT&nacional=1')->status_is(200)->tx->res->json;
  is $r->{total}, 2, 'a UF vence a região e o nacional';
  is $r->{recorte}{uf}, 'XX', 'recorte da UF';

  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&regiao=ZZ')->status_is(400);
  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais&regiao=ne')->status_is(400);
};

# Destaque (#449): a rede de um município na lista, ou o motivo de não estar.
subtest 'município destacado (#449)' => sub {
  my $url = '/api/ranking/redes?indicador=ideb_anos_iniciais';
  my $d = $t->get_ok("$url&uf=XX&destaque=6000302")->status_is(200)->tx->res->json->{destaque};
  is $d->{situacao}, 'no_ranking', 'Beta está no ranking da UF';
  is $d->{posicao}, 1, 'com a posição';
  is $d->{municipio}, 'Beta do Teste', 'nome';
  is $d->{porte}, '10_20mil', 'porte';
  is $d->{escolas}, 3, 'escolas com dado';

  $d = $t->get_ok("$url&uf=XX&destaque=6000303")->tx->res->json->{destaque};
  is $d->{situacao}, 'poucas_escolas', 'Gama: poucas escolas';
  is $d->{escolas}, 2, 'duas escolas com dado';
  ok !defined $d->{posicao}, 'sem posição';

  is $t->get_ok("$url&uf=XX&destaque=6000311")->tx->res->json->{destaque}{situacao}, 'fora_do_recorte',
    'município de XY com o recorte XX';
  is $t->get_ok("$url&uf=XX&porte=ate_5mil&destaque=6000302")->tx->res->json->{destaque}{situacao}, 'fora_do_porte',
    'Beta (15 mil) fora do porte até 5 mil';
  is $t->get_ok("$url&uf=XX&porte=ate_5mil&destaque=6000303")->tx->res->json->{destaque}{situacao}, 'sem_populacao',
    'Gama sem população com filtro de porte';
  is $t->get_ok("$url&uf=XX&destaque=6000398")->tx->res->json->{destaque}{situacao}, 'sem_dado',
    'município desconhecido: sem dado';
  ok !exists $t->get_ok("$url&uf=XX")->tx->res->json->{destaque}, 'sem destaque na URL, sem o bloco';
  $t->get_ok("$url&uf=XX&destaque=123")->status_is(400);

  is(EduMaps::Regiao->de_uf('SE'), 'NE', 'de_uf: Sergipe no Nordeste');
  ok !defined EduMaps::Regiao->de_uf('XX'), 'de_uf: UF desconhecida';
};

# Infraestrutura básica (#457): município fictício 6000392 com três escolas
# no Censo — completa, sem esgoto (fossa conta como tem, então "inexistente")
# e sem água, energia e esgoto — mais uma fechada e uma sem resposta.
subtest 'infraestrutura básica (#457)' => sub {
  my $MUNB = 6000392;
  my @IB = ('60003921', '60003922', '60003923', '60003924', '60003925');
  my $ph3 = join ',', ('?') x @IB;
  my $limpa3 = sub { $dbh->do("DELETE FROM clean.censo_escolas WHERE co_entidade IN ($ph3)", {}, @IB) };
  $limpa3->();
  my ($ano) = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas') // 2025;
  my $ins3 = $dbh->prepare(q{INSERT INTO clean.censo_escolas
    (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, tp_situacao_funcionamento,
     in_agua_inexistente, in_energia_inexistente, in_esgoto_inexistente, in_banheiro)
    VALUES (?, ?, ?, ?, ?, 'Basica do Teste', 'XX', ?, ?, ?, ?, ?)});
  $ins3->execute($ano, $IB[0], 'Completa',      3, $MUNB, 1, 0, 0, 0, 1);
  $ins3->execute($ano, $IB[1], 'Sem esgoto',    2, $MUNB, 1, 0, 0, 1, 1);
  $ins3->execute($ano, $IB[2], 'Sem tres',      3, $MUNB, 1, 1, 1, 1, 1);
  $ins3->execute($ano, $IB[3], 'Fechada',       3, $MUNB, 2, 1, 1, 1, 0);
  $ins3->execute($ano, $IB[4], 'Sem resposta',  3, $MUNB, 1, 0, 0, undef, 1);

  my $r = $t->get_ok("/api/ranking/escolas?codigo_ibge=$MUNB&indicador=infraestrutura_basica")->status_is(200)->tx->res->json;
  is $r->{total}, 3, 'só as em funcionamento e com os quatro itens respondidos';
  is $r->{indicador}{maximo}, 4, 'de 4 itens';
  like $r->{indicador}{metodo}, qr/Quantos dos 4 itens básicos.*poço, gerador/s, 'método';
  my %e = map { $_->{co_entidade} => $_ } @{ $r->{escolas} };
  is [ @{ $e{$IB[0]} }{qw(valor posicao)} ], [4, 1], 'completa: 4 de 4, primeira';
  is $e{$IB[0]}{faltam}, [], 'sem faltas';
  is [ @{ $e{$IB[1]} }{qw(valor posicao)} ], [3, 2], 'sem esgoto: 3 de 4';
  is $e{$IB[1]}{faltam}, ['esgoto'], 'falta esgoto';
  is [ @{ $e{$IB[2]} }{qw(valor posicao)} ], [1, 3], 'sem água, energia e esgoto: 1 de 4, última';
  is $e{$IB[2]}{faltam}, ['água', 'energia', 'esgoto'], 'as três faltas, na ordem';

  is $t->get_ok("/api/ranking/escolas?codigo_ibge=$MUNB&indicador=infraestrutura_basica&rede=estadual")
    ->tx->res->json->{total}, 1, 'filtro de rede';

  require EduMaps::Model::Rank::School;
  my $mv = EduMaps::Model::Rank::School->new(schema => $t->app->schema);
  ok !exists $mv->indicator_registry->{infraestrutura_basica}, 'fora do registro geral (job e painel não veem)';
  like $mv->indicator_registry->{infraestrutura}{metodo}, qr/Não é infraestrutura básica/, 'método do índice antigo';
  like $mv->indicator_registry->{diversidade_discente}{metodo}, qr/educação especial em classe comum.*corrigida/, 'diversidade: inclusão corrigida (#459)';
  $limpa3->();
};

subtest 'validações das redes' => sub {
  $t->get_ok('/api/ranking/redes?indicador=ideb_anos_iniciais')->status_is(400);
  $t->get_ok('/api/ranking/redes?indicador=infraestrutura&uf=XX')->status_is(400)
    ->json_like('/error' => qr/IDEB\/SAEB/);
  $t->get_ok('/api/ranking/redes?indicador=ideb_ensino_medio&uf=XX')->status_is(404);
};

subtest 'escolas de um município' => sub {
  my $r = $t->get_ok('/api/ranking/escolas?codigo_ibge=6000301&indicador=ideb_anos_iniciais')
    ->status_is(200)->tx->res->json;
  is $r->{ano}, 2023, 'edição mais recente';
  is $r->{total}, 4, 'quatro escolas';
  is $r->{escolas}[0]{co_entidade}, '60003003', 'maior IDEB primeiro';
  is [map { $_->{posicao} } @{ $r->{escolas} }], [1, 2, 2, 4], 'empate divide a posição';
  is $r->{escolas}[0]{inse}, 5, 'INSE ao lado';

  $t->get_ok('/api/ranking/escolas?codigo_ibge=6000399&indicador=ideb_anos_iniciais')->status_is(404);
  $t->get_ok('/api/ranking/escolas?codigo_ibge=123&indicador=ideb_anos_iniciais')->status_is(400);
  $t->get_ok('/api/ranking/escolas?codigo_ibge=6000301&indicador=nao_existe')->status_is(400);
};

done_testing;
