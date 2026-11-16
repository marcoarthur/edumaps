# t/04-api/base_analise.t
# #439 (RV-02): base de análise pública — uma linha por escola em
# funcionamento de um recorte (uma UF por vez), com os blocos escolhidos, a
# versão dos dados e o dicionário das colunas. Município fictício 6000391 em
# AC (o filtro por município isola as escolas do teste).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::Util qw(decode);

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $MUN = 6000391;
my ($A, $B, $FECHADA) = ('60003901', '60003902', '60003903');
my @INEPS = ($A, $B, $FECHADA);
my $ANO  = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas') // 2025;
my $SAEB = $dbh->selectrow_array('SELECT max(nu_ano_saeb) FROM clean.inse') // 2023;
my $IDEB = 2023;

my $limpa = sub {
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.censo_docentes WHERE co_entidade IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.inse WHERE id_escola IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.populacao_municipal WHERE codigo_ibge = ?', {}, "$MUN");
};
$limpa->();
END { $limpa->() }

my $esc = $dbh->prepare('INSERT INTO clean.censo_escolas
   (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, tp_localizacao, co_municipio, no_municipio,
    sg_uf, tp_situacao_funcionamento, in_agua_potavel, in_internet) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
$esc->execute($ANO, $A,       'Escola "Alfa"', 3, 1, $MUN, 'Cidade Teste', 'AC', 1, 1, 1);
$esc->execute($ANO, $B,       'Escola Beta',        2, 2, $MUN, 'Cidade Teste', 'AC', 1, 0, undef);
$esc->execute($ANO, $FECHADA, 'Escola Fechada',     3, 1, $MUN, 'Cidade Teste', 'AC', 2, 1, 1);

$dbh->do('INSERT INTO clean.censo_docentes (nu_ano_censo, co_entidade, qt_doc_bas,
   qt_doc_bas_esco_sup_grad_licen, qt_doc_bas_esco_sup_pos_mestra, qt_doc_bas_esco_sup_pos_douto,
   qt_doc_bas_vinculo_concur, qt_doc_bas_espec_nenhum) VALUES (?, ?, 20, 15, 2, 0, 10, 5)', {}, $ANO, $A);

my $ideb = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas
  (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa, ideb_observado, nota_matematica)
  VALUES (?, 'AC', ?, 'Cidade Teste', 'x', 'Municipal', ?, ?, ?, ?)});
$ideb->execute($A, $MUN, $IDEB, 'fundamental_i',  6.1, 225.5);
$ideb->execute($A, $MUN, $IDEB, 'fundamental_ii', 4.9, 260);
$ideb->execute($A, $MUN, 2021,  'fundamental_i',  5.0, 210);

$dbh->do(q{INSERT INTO clean.inse (nu_ano_saeb, id_escola, media_inse, inse_classificacao) VALUES (?, ?, 5.12, 'Nível V')},
  {}, $SAEB, $A);
$dbh->do(q{INSERT INTO clean.populacao_municipal (nome_municipio, populacao_estimada, codigo_ibge)
           VALUES ('Cidade Teste', 12345678, ?)}, {}, "$MUN");

sub ler_csv ($tx) {
  my $txt = decode('UTF-8', $tx->res->body);
  like $txt, qr/^\x{FEFF}/, 'BOM';
  $txt =~ s/^\x{FEFF}//;
  return [ map { [ split /;/, $_, -1 ] } split /\r\n/, $txt ];
}

subtest 'catálogo e total do recorte' => sub {
  my $r = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->status_is(200)->tx->res->json;
  is [map { $_->{id} } @{ $r->{blocos} }], [qw(identificacao infraestrutura docencia desempenho inse porte)], 'blocos';
  is $r->{total}, 2, 'só as escolas em funcionamento';
  is $r->{anos}{censo}, $ANO, 'ano do Censo';
  ok( (grep { $_ == $IDEB } @{ $r->{anos}{ideb} }), 'edições do IDEB');
  is $r->{anos}{populacao}, '2025', 'ano da população';
  ok !exists $r->{blocos}[1]{colunas}[0]{sql}, 'sem expressão SQL no catálogo';
  is $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN&rede=estadual")->tx->res->json->{total}, 1, 'filtro de rede';
};

subtest 'CSV só com a identificação' => sub {
  my $tx = $t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN")->status_is(200)
    ->header_like('Content-Type' => qr{text/csv})
    ->header_like('Content-Disposition' => qr/"base-analise-AC-\Q$MUN\E-censo\Q$ANO\E\.csv"/)->tx;
  my $l = ler_csv($tx);
  is $l->[0], [qw(inep escola codigo_ibge municipio uf rede localizacao ano_censo)], 'cabeçalho';
  is scalar @$l, 3, 'cabeçalho + 2 escolas (a fechada fica fora)';
  is $l->[1], [$A, '"Escola ""Alfa"""', "$MUN", 'Cidade Teste', 'AC', 'Municipal', 'Urbana', "$ANO"],
    'aspas no nome escapadas';
};

subtest 'todos os blocos' => sub {
  my $tx = $t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=infraestrutura,docencia,desempenho,inse,porte&ano_ideb=$IDEB")
    ->status_is(200)
    ->header_like('Content-Disposition' => qr/censo\Q$ANO\E-ideb\Q$IDEB\E-inse\Q$SAEB\E\.csv/)->tx;
  my $txt = decode('UTF-8', $tx->res->body) =~ s/^\x{FEFF}//r;
  my @l = split /\r\n/, $txt;
  my @cab = split /;/, $l[0];
  my %i; @i{@cab} = 0 .. $#cab;
  my @a = split /;/, (grep { /^$A;/ } @l)[0], -1;
  my @b = split /;/, (grep { /^$B;/ } @l)[0], -1;

  is $a[$i{in_agua_potavel}], '1', 'infraestrutura';
  is $b[$i{in_internet}], '', 'sem dado fica vazio (não zero)';
  is $a[$i{qt_docentes}], '20', 'docentes';
  is $a[$i{prop_licenciatura}], '0,75', 'proporção com vírgula';
  is $a[$i{ideb_ai}], '6,1', 'IDEB dos anos iniciais na edição pedida';
  is $a[$i{ideb_af}], '4,9', 'IDEB dos anos finais';
  is $a[$i{nota_matematica_ai}], '225,5', 'nota por etapa';
  is $a[$i{ideb_em}], '', 'sem ensino médio: vazio';
  is $b[$i{ideb_ai}], '', 'escola sem IDEB: vazio';
  is $a[$i{inse_media}], '5,12', 'INSE';
  is $a[$i{inse_classificacao}], 'Nível V', 'nível do INSE';
  is $a[$i{populacao_municipio}], '12345678', 'população inteira, sem notação científica';
  is $a[$i{porte_municipio}], 'mais_500mil', 'porte';
  is [@cab[-4 .. -1]], [qw(ano_censo ano_ideb ano_inse ano_populacao)], 'versão no fim';
  is [@a[-4 .. -1]], ["$ANO", "$IDEB", "$SAEB", '2025'], 'versão em toda linha';
};

subtest 'edição anterior do IDEB' => sub {
  my $tx = $t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=desempenho&ano_ideb=2021")->status_is(200)->tx;
  my $l = ler_csv($tx);
  my %i; @i{ @{ $l->[0] } } = 0 .. $#{ $l->[0] };
  my ($a) = grep { $_->[0] eq $A } @$l;
  is $a->[$i{ideb_ai}], '5', 'valor de 2021';
  is $a->[$i{ano_ideb}], '2021', 'ano na linha';
};

subtest 'dicionário' => sub {
  my $tx = $t->get_ok("/api/base-analise/dicionario?blocos=desempenho,porte")->status_is(200)
    ->header_like('Content-Disposition' => qr/"base-analise-dicionario-censo\d{4}-ideb\d{4}\.csv"/)->tx;
  my $l = ler_csv($tx);
  is $l->[0], [qw(coluna descricao bloco fonte ano url_fonte)], 'cabeçalho';
  my %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{ideb_af}[1], qr/IDEB observado, anos finais/, 'descrição da coluna';
  like $d{ideb_af}[3], qr/IDEB e SAEB \(INEP\)/, 'fonte';
  like $d{ideb_af}[5], qr{^https://www\.gov\.br/inep/}, 'link oficial';
  is $d{populacao_municipio}[4], '2025', 'ano da população';
  ok $d{ano_censo}, 'colunas de versão no dicionário';
  ok !$d{inse_media}, 'só os blocos pedidos';
};

subtest 'dicionário: ressalvas (#444)' => sub {
  my $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=docencia,desempenho")->status_is(200)->tx);
  my %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  is $d{ano_ideb}[1], 'Edição do IDEB/SAEB', 'edição mais recente: sem ressalva';
  like $d{qt_docentes}[1], qr/mais de uma escola conta em cada uma/, 'contagem por escola';
  like $d{$_}[1], qr/÷ docentes da escola \(qt_docentes\)/, "$_: denominador"
    for qw(prop_licenciatura prop_mestrado prop_doutorado prop_efetivos prop_sem_especializacao);

  $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=desempenho&ano_ideb=2021")->status_is(200)->tx);
  %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{ano_ideb}[1], qr/\(2021\), cruzada com o Censo Escolar \Q$ANO\E/, 'edição antiga: cruzamento dito';
  like $d{ano_ideb}[1], qr/fechadas depois de 2021 não entram/, 'escolas fechadas';
};

subtest 'erros' => sub {
  $t->get_ok('/api/base-analise/csv')->status_is(400)->json_like('/error' => qr/UF/);
  $t->get_ok('/api/base-analise/csv?uf=XX')->status_is(400);
  $t->get_ok('/api/base-analise/csv?uf=AC&blocos=salarios')->status_is(400)->json_like('/error' => qr/salarios/);
  $t->get_ok('/api/base-analise/csv?uf=AC&blocos=desempenho&ano_ideb=1990')->status_is(400)->json_like('/error' => qr/1990/);
  $t->get_ok('/api/base-analise/csv?uf=AC&rede=comunitaria')->status_is(400);
};

done_testing;
