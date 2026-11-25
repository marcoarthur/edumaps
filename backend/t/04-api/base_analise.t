# t/04-api/base_analise.t
# #439 (RV-02): base de análise pública — uma linha por escola em
# funcionamento de um recorte (uma UF por vez), com os blocos escolhidos, a
# versão dos dados e o dicionário das colunas. Município fictício 6000391 em
# AC (o filtro por município isola as escolas do teste).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use List::Util ();
use utf8;
use open ':std', ':encoding(UTF-8)';
use Mojo::Util qw(decode);
use EduMaps::Model::Rank::School;
use EduMaps::BaseAnalise;

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
  $dbh->do('DELETE FROM clean.censo_matriculas WHERE co_entidade IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.inse WHERE id_escola IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.populacao_municipal WHERE codigo_ibge = ?', {}, "$MUN");
  $dbh->do(q{DELETE FROM clean.ibge_agregados WHERE codigo_ibge = ? AND tabela_id = '9514'}, {}, "$MUN");
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep IN (?, ?, ?) OR (cod_municipio::text = ? AND ano IN (2001, 2002, 2003, 2004, 2005, 2026))', {}, @INEPS, '600039');
};
$limpa->();
END { $limpa->() }

my $esc = $dbh->prepare('INSERT INTO clean.censo_escolas
   (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, tp_localizacao, co_municipio, no_municipio,
    sg_uf, tp_situacao_funcionamento, in_agua_potavel, in_internet,
    in_esgoto_rede_publica, in_esgoto_inexistente, in_energia_inexistente, in_agua_inexistente,
    latitude, longitude,
    in_comum_fund_ai, in_comum_medio_medio, in_comum_medio_integrado, in_comum_medio_normal, in_profissionalizante,
    co_cep, no_bairro, ds_endereco, nu_endereco)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
# #461: Alfa oferece anos iniciais e não oferece médio; Beta só tem o médio
# integrado (conta como médio) e não respondeu a educação profissional.
# #452: Alfa tem fossa (esgoto fora da rede pública, mas tem esgoto) e
# coordenadas com mais de 6 casas; Beta não tem esgoto nem coordenadas.
$esc->execute($ANO, $A,       'Escola "Alfa"', 3, 1, $MUN, 'Cidade Teste', 'AC', 1, 1, 1,     0, 0, 0, 0, -9.97432149, -67.8076543, 1, 0, 0, 0, 0,
              '01001000', ' Centro ', 'Rua das Flores', ' 10 ');
$esc->execute($ANO, $B,       'Escola Beta',        2, 2, $MUN, 'Cidade Teste', 'AC', 1, 0, undef, 0, 1, 0, 0, undef, undef, 0, 0, 1, 0, undef,
              '69900123', '', 'Ramal do Limoeiro', 'S/N');
$esc->execute($ANO, $FECHADA, 'Escola Fechada',     3, 1, $MUN, 'Cidade Teste', 'AC', 2, 1, 1,     1, 0, 0, 0, undef, undef, 1, 0, 0, 0, 0,
              '69900000', undef, undef, undef);

$dbh->do('INSERT INTO clean.censo_docentes (nu_ano_censo, co_entidade, qt_doc_bas,
   qt_doc_bas_esco_sup_grad_licen, qt_doc_bas_esco_sup_pos_mestra, qt_doc_bas_esco_sup_pos_douto,
   qt_doc_bas_vinculo_concur, qt_doc_bas_espec_nenhum, qt_doc_fund_ai, qt_doc_fund_af)
   VALUES (?, ?, 20, 15, 2, 0, 10, 5, 12, 11)', {}, $ANO, $A);

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
# #533: população por idade do Censo 2022 (SIDRA 9514), 0 a 3 = 46 e 4 a 5 = 29
my %IDADE = ('Total' => 1000, 'Menos de 1 ano' => 10, '1 ano' => 11, '2 anos' => 12, '3 anos' => 13,
             '4 anos' => 14, '5 anos' => 15, '6 anos' => 16);
$dbh->do(q{INSERT INTO clean.ibge_agregados (codigo_ibge, ano, tabela_id, variavel, classificacao, valor, unidade)
           VALUES (?, 2022, '9514', '93', ?, ?, 'Pessoas')}, {}, "$MUN", $_, $IDADE{$_}) for sort keys %IDADE;

sub ler_csv ($tx) {
  my $txt = decode('UTF-8', $tx->res->body);
  like $txt, qr/^\x{FEFF}/, 'BOM';
  $txt =~ s/^\x{FEFF}//;
  return [ map { [ split /;/, $_, -1 ] } split /\r\n/, $txt ];
}

subtest 'catálogo e total do recorte' => sub {
  my $r = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->status_is(200)->tx->res->json;
  is [map { $_->{id} } @{ $r->{blocos} }], [qw(identificacao etapas matriculas parceria infraestrutura docencia desempenho indices inse remuneracao porte)], 'blocos (etapas depois da identificação, #461; matrículas depois das etapas, #516; parceria depois das matrículas, #518; índices depois do IDEB, #465; remuneração, #491)';
  is $r->{total}, 2, 'só as escolas em funcionamento';
  is $r->{anos}{censo}, $ANO, 'ano do Censo';
  ok( (grep { $_ == $IDEB } @{ $r->{anos}{ideb} }), 'edições do IDEB');
  is $r->{anos}{populacao}, '2025', 'ano da população';
  is $r->{anos}{indices}, $EduMaps::Model::Rank::School::INDICES_VERSAO, 'versão dos índices (#465)';
  ok !exists $r->{blocos}[1]{colunas}[0]{sql}, 'sem expressão SQL no catálogo';
  is $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN&rede=estadual")->tx->res->json->{total}, 1, 'filtro de rede';
};

subtest 'CSV só com a identificação' => sub {
  my $tx = $t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN")->status_is(200)
    ->header_like('Content-Type' => qr{text/csv})
    ->header_like('Content-Disposition' => qr/"base-analise-AC-\Q$MUN\E-censo\Q$ANO\E\.csv"/)->tx;
  my $l = ler_csv($tx);
  is $l->[0], [qw(inep escola codigo_ibge municipio uf regiao rede localizacao latitude longitude cep bairro endereco ano_censo)],
    'cabeçalho (região depois da UF, #448; coordenadas, #452; endereço no fim da identificação, #531)';
  is scalar @$l, 3, 'cabeçalho + 2 escolas (a fechada fica fora)';
  is $l->[1], [$A, '"Escola ""Alfa"""', "$MUN", 'Cidade Teste', 'AC', 'Norte', 'Municipal', 'Urbana', '-9,974321', '-67,807654',
                '01001-000', 'Centro', 'Rua das Flores, 10', "$ANO"],
    'aspas no nome escapadas; CEP com hífen e o zero do começo (#531)';
  is [ @{ $l->[2] }[8 .. 12] ], ['', '', '69900-123', '', 'Ramal do Limoeiro'],
    'sem coordenada, com CEP; bairro vazio; S/N fora do endereço (#531)';
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
  # #452 (VJ-01): fora da rede pública não é "sem".
  is [ @a[ @i{qw(in_esgoto_rede_publica in_esgoto_inexistente)} ] ], ['0', '0'], 'Alfa: fossa, tem esgoto';
  is [ @b[ @i{qw(in_esgoto_rede_publica in_esgoto_inexistente)} ] ], ['0', '1'], 'Beta: sem esgoto';
  is [ @cab[ $i{in_agua_potavel} + 1, $i{in_energia_rede_publica} + 1, $i{in_esgoto_rede_publica} + 1 ] ],
    [qw(in_agua_inexistente in_energia_inexistente in_esgoto_inexistente)], 'cada "inexistente" ao lado do serviço';
  is $b[$i{latitude}], '', 'sem coordenada: vazio';
  is $a[$i{qt_docentes}], '20', 'docentes';
  is $a[$i{prop_licenciatura}], '0,75', 'proporção com vírgula';
  # #529 (QS-01): docentes por etapa no fim do bloco; quem dá aula em duas
  # etapas conta nas duas (12 + 11 > 20); sem a etapa, 0; sem docentes, vazio
  is [ @cab[ $i{prop_formacao_continuada} + 1 .. $i{prop_formacao_continuada} + 4 ] ],
    [qw(qt_docentes_infantil qt_docentes_ai qt_docentes_af qt_docentes_em)], 'docentes por etapa no fim do bloco (#529)';
  is [ @a[ @i{qw(qt_docentes_infantil qt_docentes_ai qt_docentes_af qt_docentes_em)} ] ], ['0', '12', '11', '0'], 'Alfa: por etapa';
  is $b[$i{qt_docentes_ai}], '', 'sem docentes: vazio';
  is $a[$i{ideb_ai}], '6,1', 'IDEB dos anos iniciais na edição pedida';
  is $a[$i{ideb_af}], '4,9', 'IDEB dos anos finais';
  is $a[$i{nota_matematica_ai}], '225,5', 'nota por etapa';
  is $a[$i{ideb_em}], '', 'sem ensino médio: vazio';
  is $b[$i{ideb_ai}], '', 'escola sem IDEB: vazio';
  is $a[$i{inse_media}], '5,12', 'INSE';
  is $a[$i{inse_classificacao}], 'Nível V', 'nível do INSE';
  is $a[$i{populacao_municipio}], '12345678', 'população inteira, sem notação científica';
  is $a[$i{porte_municipio}], 'mais_500mil', 'porte';
  # #533: crianças na idade da creche e da pré-escola, do Censo Demográfico
  is [ @cab[ $i{porte_municipio} + 1, $i{porte_municipio} + 2 ] ], [qw(populacao_0_3 populacao_4_5)],
    'população por idade depois do porte (#533)';
  is [ @a[ @i{qw(populacao_0_3 populacao_4_5)} ] ], ['46', '29'], '0 a 3 e 4 e 5 anos (#533)';
  is [@cab[-5 .. -1]], [qw(ano_censo ano_ideb ano_inse ano_populacao ano_populacao_idade)], 'versão no fim';
  is [@a[-5 .. -1]], ["$ANO", "$IDEB", "$SAEB", '2025', '2022'], 'versão em toda linha';
};

subtest 'etapas oferecidas e cobertura do IDEB (#461)' => sub {
  my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=etapas,desempenho&ano_ideb=$IDEB")->status_is(200)->tx);
  my %i; @i{ @{ $l->[0] } } = 0 .. $#{ $l->[0] };
  my ($a) = grep { $_->[0] eq $A } @$l;
  my ($b) = grep { $_->[0] eq $B } @$l;
  is [ @$a[ @i{qw(oferece_ai oferece_em oferece_profissional)} ] ], ['1', '0', '0'], 'Alfa: anos iniciais, sem médio';
  is $b->[$i{oferece_em}], '1', 'Beta: médio integrado conta como médio';
  is $b->[$i{oferece_profissional}], '', 'sem resposta: vazio, não 0';
  is $a->[$i{ideb_ai}], '6,1', 'IDEB ao lado da oferta';
  ok $i{classe_especial_exclusiva}, 'classe especial exclusiva';

  my $d = ler_csv($t->get_ok('/api/base-analise/dicionario?blocos=etapas,desempenho')->status_is(200)->tx);
  my %dd = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $dd{ideb_af}[1], qr/Vazio: a escola não oferece a etapa \(veja oferece_af\).*A falta não é aleatória/, 'aviso de cobertura no IDEB';
  like $dd{nota_matematica_em}[1], qr/veja oferece_em/, 'e nas notas';
  like $dd{oferece_em}[1], qr/inclusive integrado e normal.*in_comum_medio_medio, _integrado e _normal/, 'origem da oferta';
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
  # #531 (QR-01): a falta de coordenada e o endereço
  like $d{latitude}[1], qr/privadas \(cerca de 1 em cada 3.*use o cep, o bairro e o endereco/, 'latitude: cobertura por rede e o endereço (#531)';
  like $d{cep}[1], qr/00000-000.*zero do começo.*geocodifique/, 'cep: formato e uso (#531)';
  like $d{bairro}[1], qr/rurais/, 'bairro: falta nas rurais (#531)';
  like $d{endereco}[1], qr/S\/N, 0 ou nada/, 'endereço: sem o número S/N (#531)';
  is $d{populacao_municipio}[4], '2025', 'ano da população';
  # #533: a população por idade é de outra fonte e de outro ano que o bloco
  is $d{populacao_0_3}[3], 'População por idade (Censo Demográfico) (IBGE)', 'fonte da população por idade (#533)';
  is $d{populacao_0_3}[4], '2022', 'ano do Censo Demográfico (#533)';
  like $d{populacao_0_3}[5], qr{sidra\.ibge\.gov\.br/tabela/9514}, 'link da tabela do SIDRA (#533)';
  like $d{populacao_4_5}[1], qr/pré-escola.*Taxa bruta de matrícula.*Não é o indicador oficial da meta 1 do PNE.*passar de 100%.*anterior ao Censo Escolar/, 'a conta e os avisos (#533, #549)';
  like $d{ano_populacao_idade}[1], qr/anterior ao das matrículas/, 'ano da população por idade (#533)';
  ok $d{ano_censo}, 'colunas de versão no dicionário';
  like $d{regiao}[1], qr/Região geográfica do IBGE.*derivada da UF/, 'região no dicionário (#448)';
  like $d{latitude}[1], qr/como declarada ao Censo Escolar, sem verificação/, 'coordenada no dicionário (#452)';
  ok !$d{inse_media}, 'só os blocos pedidos';
};

# #465 (RY-01): os índices do EduMaps. A MV só se refaz com REFRESH (pesado
# e global), então o teste usa uma escola que já está nela.
subtest 'índices do EduMaps (#465)' => sub {
  my $V = $EduMaps::Model::Rank::School::INDICES_VERSAO;
  my $s = $dbh->selectrow_hashref(q{
    SELECT e.co_entidade::text AS inep, e.sg_uf, e.co_municipio::text AS mun, s.score_infraestrutura::float8 AS infra,
           s.score_diversidade_discente::float8 AS div
      FROM clean.mv_escolas_scores s
      JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
     WHERE e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ?
     ORDER BY e.co_entidade LIMIT 1}, undef, $ANO);
  SKIP: {
    skip 'MV de índices vazia no ano do Censo', 8 unless $s;
    my $tx = $t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=indices")->status_is(200)
      ->header_like('Content-Disposition' => qr/-censo\Q$ANO\E-\Q$V\E\.csv"/)->tx;
    my $l = ler_csv($tx);
    my @cab = @{ $l->[0] };
    my %i; @i{@cab} = 0 .. $#cab;
    is [ grep { /^indice_/ } @cab ],
      [map {"indice_$_"} qw(infraestrutura capacidade_atendimento capacitacao_docente diversidade_discente capacidade_gestora sustentabilidade)],
      'as seis colunas, na ordem';
    is [@cab[-2, -1]], [qw(ano_censo versao_indice)], 'versão da fórmula no fim';
    my ($linha) = grep { $_->[0] eq $s->{inep} } @$l[1 .. $#$l];
    my $num = sub ($v) { defined $v ? (0 + $v == int $v ? sprintf('%d', $v) : sprintf('%.6g', $v) =~ s/\./,/r) : '' };
    is [ @$linha[ @i{qw(indice_infraestrutura indice_diversidade_discente)} ] ], [ $num->($s->{infra}), $num->($s->{div}) ],
      'valores iguais aos da MV';
    is $linha->[-1], $V, 'versão em toda linha, como texto';
  }

  my $sem = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN")->tx);
  ok !(grep { /^indice_|versao_indice/ } @{ $sem->[0] }), 'sem o bloco, sem índices nem versão';

  my $tx = $t->get_ok('/api/base-analise/dicionario?blocos=indices')->status_is(200)
    ->header_like('Content-Disposition' => qr/-\Q$V\E\.csv"/)->tx;
  my $d = ler_csv($tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{indice_diversidade_discente}[1], qr/educação especial em classe comum/, 'método do índice no dicionário';
  like $d{indice_sustentabilidade}[1], qr/Energia renovável, reciclagem/, '";" do método trocado por vírgula';
  is $d{indice_infraestrutura}[3], 'Índices do EduMaps', 'fonte sem o órgão repetido (#467, RZ-02)';
  is $d{in_agua_inexistente}, undef, 'só os blocos pedidos';
  unlike $d{indice_infraestrutura}[1], qr/use "Infraestrutura básica"/, 'sem apontar coluna que a base não tem (RZ-02)';
  like $d{indice_infraestrutura}[1], qr/in_\*_inexistente e in_banheiro do bloco Infraestrutura/, 'aponta os itens da base';
  like $d{indice_capacitacao_docente}[1], qr/fica sem o índice \(vazio, não 0\).*Vazio: escola sem docentes no Censo/, 'vazio sem registro (#467)';
  like $d{indice_infraestrutura}[1], qr/Vazio: índices ainda não recalculados/, 'infraestrutura: só o vazio da carga nova';
  like $d{indice_infraestrutura}[5], qr{rankings\.md#o-que-cada}, 'link para o método';
  is $d{versao_indice}[4], $V, 'versão no dicionário';
};

# #469 (RW-01): as quatro partes do índice de capacitação docente estão na
# base e refazem o índice da MV.
subtest 'partes do índice de capacitação docente (#469)' => sub {
  my $s = $dbh->selectrow_hashref(q{
    SELECT e.co_entidade::text AS inep, e.sg_uf, e.co_municipio::text AS mun, s.score_capacitacao_docente::float8 AS cap
      FROM clean.mv_escolas_scores s
      JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
     WHERE e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ? AND s.score_capacitacao_docente > 0
     ORDER BY e.co_entidade LIMIT 1}, undef, $ANO);
  SKIP: {
    skip 'nenhuma escola com o índice de capacitação na MV', 6 unless $s;
    my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=docencia,indices")->status_is(200)->tx);
    my @cab = @{ $l->[0] };
    my %i; @i{@cab} = 0 .. $#cab;
    is [ @cab[ $i{prop_sem_formacao_continuada} + 1 .. $i{prop_sem_formacao_continuada} + 3 ] ],
      [qw(prop_superior prop_pos_graduacao prop_formacao_continuada)], 'no fim do bloco, na ordem';
    my ($linha) = grep { $_->[0] eq $s->{inep} } @$l[1 .. $#$l];
    my $v = sub ($c) { my $x = $linha->[ $i{$c} ]; $x =~ tr/,/./; 0 + $x };
    # #524: concursados vazios na privada, com o peso redistribuído
    my $tem_ef = $linha->[ $i{prop_efetivos} ] ne '';
    my $refeito = 10 * (0.3 * $v->('prop_superior') + 0.3 * $v->('prop_pos_graduacao')
                      + ($tem_ef ? 0.2 * ($v->('prop_efetivos') > 1 ? 1 : $v->('prop_efetivos')) : 0)
                      + 0.2 * $v->('prop_formacao_continuada')) / ($tem_ef ? 1 : 0.8);
    ok abs($refeito - $s->{cap}) < 0.01, "índice refeito com as partes ($refeito vs $s->{cap})";
    ok $v->('prop_pos_graduacao') <= 1 && $v->('prop_formacao_continuada') <= 1, 'limitadas a 1';
  }
  my $l = ler_csv($t->get_ok('/api/base-analise/dicionario?blocos=indices')->tx);
  my %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{$_}[1], qr/pesos são uma escolha do EduMaps, não estimados contra o IDEB/, "$_: pesos normativos (RW-02)"
    for map {"indice_$_"} qw(infraestrutura capacitacao_docente sustentabilidade);
};

# #471 (RT-02): as partes do índice de diversidade refazem o índice, com e
# sem a parte racial (menos de metade das matrículas com cor declarada).
subtest 'partes do índice de diversidade (#471)' => sub {
  my $DECL = '(COALESCE(m.qt_mat_bas_branca,0)+COALESCE(m.qt_mat_bas_preta,0)+COALESCE(m.qt_mat_bas_parda,0)+COALESCE(m.qt_mat_bas_amarela,0)+COALESCE(m.qt_mat_bas_indigena,0))';
  for my $caso (['com a parte racial', ">= 0.5 * m.qt_mat_bas AND $DECL > 0"], ['sem a parte racial', '< 0.5 * m.qt_mat_bas']) {
    my ($nome, $cond) = @$caso;
    my $s = $dbh->selectrow_hashref(qq{
      SELECT e.co_entidade::text AS inep, e.sg_uf, e.co_municipio::text AS mun, s.score_diversidade_discente::float8 AS div
        FROM clean.mv_escolas_scores s
        JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
        JOIN clean.censo_matriculas m ON m.co_entidade = s.co_entidade AND m.nu_ano_censo = s.nu_ano_censo
       WHERE e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ? AND m.qt_mat_bas > 0 AND $DECL $cond
       ORDER BY e.co_entidade LIMIT 1}, undef, $ANO);
    SKIP: {
      skip "nenhuma escola $nome na MV", 3 unless $s;
      my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=indices")->tx);
      my @cab = @{ $l->[0] };
      my %i; @i{@cab} = 0 .. $#cab;
      my ($linha) = grep { $_->[0] eq $s->{inep} } @$l[1 .. $#$l];
      my $v = sub ($c) { my $x = $linha->[ $i{$c} ]; return undef if $x eq ''; $x =~ tr/,/./; 0 + $x };
      my ($r, $g, $ee, $eja) = map { $v->($_) } qw(diversidade_racial equilibrio_genero prop_educacao_especial_cc prop_eja);
      my $refeito = defined $r ? 10 * (0.35 * $r + 0.25 * $g + 0.2 * $ee + 0.2 * $eja)
                               : 10 * (0.25 * $g + 0.2 * $ee + 0.2 * $eja) / 0.65;
      ok abs($refeito - $s->{div}) < 0.01, "$nome: índice refeito ($refeito vs $s->{div})";
      ok( (defined $r) == ($nome eq 'com a parte racial'), "$nome: diversidade_racial " . (defined $r ? 'preenchida' : 'vazia'));
    }
  }
  my $l = ler_csv($t->get_ok('/api/base-analise/csv?uf=AC&codigo_ibge=' . $MUN . '&blocos=indices')->tx);
  my @cab = @{ $l->[0] };
  is [ @cab[ -25 .. -3 ] ], [qw(diversidade_racial prop_cor_nao_declarada equilibrio_genero prop_educacao_especial_cc prop_eja
                               alunos_sala_turno turnos etapas_regulares prop_tempo_integral alimentacao
                               gestores_formacao prop_gestores_espec_gestao alunos_por_gestor orgaos_colegiados prop_acesso_cargo_selecao
                               infra_basico infra_salas_equipamentos infra_acessibilidade infra_tecnologia
                               energia_renovavel reciclagem_lixo area_verde_plantio educacao_ambiental)],
    'partes da diversidade, do atendimento (#473), da gestora (#475), da infraestrutura e da sustentabilidade (#477) no fim do bloco, antes de ano_censo e versao_indice';
  my $d = ler_csv($t->get_ok('/api/base-analise/dicionario?blocos=indices,inse')->tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{diversidade_racial}[1], qr/sobre as matrículas com cor declarada.*Vazio: menos de metade/, 'parte racial no dicionário';
  like $d{inse_media}[1], qr/Vazio: a escola não teve alunos avaliados no SAEB.*privadas nunca/, 'motivo do INSE vazio (RT-03)';
  like $d{inse_classificacao}[1], qr/privadas nunca/, 'nível do INSE também';
};

# #473 (RS-02): as partes do índice de capacidade de atendimento refazem o
# índice, numa escola de um turno e numa de dois ou mais.
subtest 'partes do índice de capacidade de atendimento (#473)' => sub {
  my $T = 'GREATEST(1, (COALESCE(m.qt_mat_bas_dm,0)>0)::int + (COALESCE(m.qt_mat_bas_dv,0)>0)::int + (COALESCE(m.qt_mat_bas_n,0)>0)::int)';
  for my $caso (['um turno', "= 1"], ['dois ou mais turnos', "> 1"]) {
    my ($nome, $cond) = @$caso;
    my $s = $dbh->selectrow_hashref(qq{
      SELECT e.co_entidade::text AS inep, e.sg_uf, e.co_municipio::text AS mun, s.score_capacidade_atendimento::float8 AS cap
        FROM clean.mv_escolas_scores s
        JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
        JOIN clean.censo_matriculas m ON m.co_entidade = s.co_entidade AND m.nu_ano_censo = s.nu_ano_censo
       WHERE e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ? AND m.qt_mat_bas > 0 AND e.qt_salas_utilizadas > 0 AND $T $cond
       ORDER BY e.co_entidade LIMIT 1}, undef, $ANO);
    SKIP: {
      skip "nenhuma escola com $nome na MV", 2 unless $s;
      my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=indices")->tx);
      my %i; @i{ @{ $l->[0] } } = 0 .. $#{ $l->[0] };
      my ($linha) = grep { $_->[0] eq $s->{inep} } @$l[1 .. $#$l];
      my $v = sub ($c) { my $x = $linha->[ $i{$c} ]; return undef if $x eq ''; $x =~ tr/,/./; 0 + $x };
      my $dens = 1 - $v->('alunos_sala_turno') / 50; $dens = 0 if $dens < 0;
      my $refeito = 10 * (0.4 * $dens + 0.2 * $v->('etapas_regulares') / 7 + 0.2 * $v->('prop_tempo_integral') + 0.2 * ($v->('alimentacao') // 0));
      ok abs($refeito - $s->{cap}) < 0.01, "$nome: índice refeito ($refeito vs $s->{cap})";
      ok( ($nome eq 'um turno') == ($v->('turnos') == 1), "$nome: turnos = " . $v->('turnos'));
    }
  }
  my $d = ler_csv($t->get_ok('/api/base-analise/dicionario?blocos=indices')->tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{alunos_sala_turno}[1], qr/salas utilizadas × turnos/, 'parte de alunos por sala e turno no dicionário';
  like $d{indice_capacidade_atendimento}[1], qr/alunos por sala e por turno/, 'método com os turnos';
};

# #475: as partes do índice de capacidade gestora refazem o índice, com as
# partes vazias fora da soma e dos pesos: escola pública com matrícula,
# escola privada (sem o acesso ao cargo) e escola sem matrícula.
subtest 'partes do índice de capacidade gestora (#475)' => sub {
  my $M = 'EXISTS (SELECT 1 FROM clean.censo_matriculas m WHERE m.co_entidade = s.co_entidade AND m.nu_ano_censo = s.nu_ano_censo AND m.qt_mat_bas > 0)';
  for my $caso (['pública com matrícula', "e.tp_dependencia <> 4 AND $M"], ['privada', "e.tp_dependencia = 4 AND $M"],
                ['sem matrícula', "NOT $M"]) {
    my ($nome, $cond) = @$caso;
    my $s = $dbh->selectrow_hashref(qq{
      SELECT e.co_entidade::text AS inep, e.sg_uf, e.co_municipio::text AS mun, s.score_capacidade_gestora::float8 AS ges, e.tp_dependencia AS dep
        FROM clean.mv_escolas_scores s
        JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
       WHERE e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ? AND s.score_capacidade_gestora IS NOT NULL AND $cond
       ORDER BY e.co_entidade LIMIT 1}, undef, $ANO);
    SKIP: {
      skip "nenhuma escola $nome com gestor na MV", 3 unless $s;
      my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=indices")->tx);
      my %i; @i{ @{ $l->[0] } } = 0 .. $#{ $l->[0] };
      my ($linha) = grep { $_->[0] eq $s->{inep} } @$l[1 .. $#$l];
      my $v = sub ($c) { my $x = $linha->[ $i{$c} ]; return undef if $x eq ''; $x =~ tr/,/./; 0 + $x };
      my ($apg, $ac) = map { $v->($_) } qw(alunos_por_gestor prop_acesso_cargo_selecao);
      my $col = $v->('orgaos_colegiados') / 5; $col = 1 if $col > 1;
      my ($soma, $pesos) = (0.3 * $v->('gestores_formacao') + 0.2 * $v->('prop_gestores_espec_gestao') + 0.2 * $col, 0.7);
      if (defined $apg) { my $p = $apg > 0 ? 200 / $apg : 1; $p = 1 if $p > 1; $soma += 0.2 * $p; $pesos += 0.2 }
      if (defined $ac)  { $soma += 0.1 * $ac; $pesos += 0.1 }
      my $refeito = 10 * $soma / $pesos;
      ok abs($refeito - $s->{ges}) < 0.01, "$nome: índice refeito ($refeito vs $s->{ges})";
      ok( (defined $apg) == ($nome ne 'sem matrícula'), "$nome: alunos_por_gestor " . (defined $apg ? 'preenchido' : 'vazio'));
      ok( (defined $ac) == ($s->{dep} != 4),
          "$nome: prop_acesso_cargo_selecao " . (defined $ac ? 'preenchida' : 'vazia'));
    }
  }
  my $d = ler_csv($t->get_ok('/api/base-analise/dicionario?blocos=indices')->tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{prop_acesso_cargo_selecao}[1], qr/Vazio: escola privada/, 'acesso ao cargo vazio nas privadas no dicionário';
  like $d{alunos_por_gestor}[1], qr/Vazio: sem matrículas/, 'gestores por aluno vazio sem matrícula no dicionário';
  like $d{indice_capacidade_gestora}[1], qr/só na rede pública.*indices-v6/, 'método da gestora com a v6';
};

# #477 (RQ-02): as partes da infraestrutura e da sustentabilidade refazem os
# dois índices, em todas as escolas de um município da MV.
subtest 'partes da infraestrutura e da sustentabilidade (#477)' => sub {
  my $s = $dbh->selectrow_hashref(q{
    SELECT e.sg_uf, e.co_municipio::text AS mun
      FROM clean.mv_escolas_scores s
      JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
     WHERE e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ?
     GROUP BY 1, 2 ORDER BY count(*) DESC LIMIT 1}, undef, $ANO);
  SKIP: {
    skip 'MV vazia', 3 unless $s;
    my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=$s->{sg_uf}&codigo_ibge=$s->{mun}&blocos=indices")->tx);
    my %i; @i{ @{ $l->[0] } } = 0 .. $#{ $l->[0] };
    my ($n, $infra, $sust) = (0, 0, 0);
    for my $linha (@$l[1 .. $#$l]) {
      my $v = sub ($c) { my $x = $linha->[ $i{$c} ]; return undef if !defined $x || $x eq ''; $x =~ tr/,/./; 0 + $x };
      next unless defined $v->('indice_infraestrutura');
      $n++;
      my $ri = 10 * (List::Util::sum(map { $v->($_) } qw(infra_basico infra_salas_equipamentos infra_acessibilidade infra_tecnologia)) / 4);
      my $rs = 10 * (List::Util::sum(map { $v->($_) } qw(energia_renovavel reciclagem_lixo area_verde_plantio educacao_ambiental)) / 4);
      $infra++ if abs($ri - $v->('indice_infraestrutura')) < 0.006;
      $sust++  if abs($rs - $v->('indice_sustentabilidade')) < 0.006;
    }
    ok $n > 0, "$n escolas com o índice";
    is $infra, $n, 'infraestrutura refeita pelos quatro grupos em todas';
    is $sust, $n, 'sustentabilidade refeita pelas quatro partes em todas';
  }
  my $d = ler_csv($t->get_ok('/api/base-analise/dicionario?blocos=indices')->tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{infra_basico}[1], qr/esgoto da rede ou fossa séptica/, 'itens do básico no dicionário';
  like $d{area_verde_plantio}[1], qr/meio ponto cada/, 'área verde e plantio no dicionário';
};

subtest 'dicionário: rede pública não é "sem" (#452)' => sub {
  my $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=infraestrutura")->status_is(200)->tx);
  my %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{in_esgoto_rede_publica}[1], qr/0 não quer dizer sem esgoto.*in_esgoto_inexistente/, 'esgoto';
  like $d{in_energia_rede_publica}[1], qr/0 não quer dizer sem energia.*in_energia_inexistente/, 'energia';
  like $d{in_agua_potavel}[1], qr/0 não quer dizer sem água.*in_agua_inexistente/, 'água';
  like $d{in_esgoto_inexistente}[1], qr/^Não tem esgotamento sanitário \(1 = não tem/, 'inexistente';
  my $r = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->tx->res->json;
  my ($infra) = grep { $_->{id} eq 'infraestrutura' } @{ $r->{blocos} };
  is scalar @{ $infra->{colunas} }, 14, 'bloco de infraestrutura com 14 colunas';
};

subtest 'dicionário: ressalvas (#444)' => sub {
  my $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=docencia,desempenho")->status_is(200)->tx);
  my %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  # #514 (QY-01): a edição mais recente também é cruzada com o Censo (a
  # ressalva só some quando os anos são iguais)
  my $cat = $t->get_ok('/api/base-analise')->tx->res->json->{anos};
  if (defined $cat->{ideb}[0] && $cat->{ideb}[0] != $ANO) {
    like $d{ano_ideb}[1], qr/\($cat->{ideb}[0]\), cruzada com o Censo Escolar \Q$ANO\E/,
      'edição mais recente: cruzamento dito (#514)';
  } else {
    is $d{ano_ideb}[1], 'Edição do IDEB/SAEB', 'IDEB do mesmo ano do Censo: sem ressalva';
  }
  like $d{qt_docentes}[1], qr/mais de uma escola conta em cada uma/, 'contagem por escola';
  like $d{$_}[1], qr/÷ docentes da escola \(qt_docentes\)/, "$_: denominador"
    for qw(prop_licenciatura prop_mestrado prop_doutorado prop_efetivos prop_sem_formacao_continuada
           prop_superior prop_pos_graduacao prop_formacao_continuada);
  like $d{prop_superior}[1], qr/Parte de 30% do índice de capacitação docente/, 'superior: parte do índice (#469)';
  like $d{prop_pos_graduacao}[1], qr/limitada a 1.*Parte de 30%/, 'pós: limite e parte';
  like $d{prop_formacao_continuada}[1], qr/Parte de 20%/, 'formação continuada: parte';
  like $d{prop_efetivos}[1], qr/Parte de 20%/, 'efetivos: parte';
  like $d{qt_docentes_ai}[1], qr/anos iniciais.*conta em cada uma.*não só os desta etapa/, 'por etapa: dupla contagem e proporções da escola (#529)';
  like $d{prop_efetivos}[1], qr/Vazia nas escolas privadas: o Censo só pergunta o vínculo do docente na escola pública/,
    'efetivos: vazia nas privadas (#524)';
  # #522 (QU-01, QU-02): a coluna de qt_doc_bas_espec_nenhum é a formação
  # continuada, não a pós; e a soma de cursos não conta pessoas.
  ok !exists $d{prop_sem_especializacao}, 'nome antigo fora da base (#522)';
  like $d{prop_sem_formacao_continuada}[1], qr/sem formação continuada de no mínimo 80 horas.*Não é a pós-graduação.*se chamava prop_sem_especializacao/,
    'sem formação continuada: o que mede e o nome antigo (#522)';
  unlike $d{$_}[1], qr/sem especialização/i, "$_: sem 'especialização' (#522)"
    for qw(prop_sem_formacao_continuada prop_formacao_continuada);
  like $d{prop_formacao_continuada}[1], qr/Conta cursos, não pessoas.*1 − prop_sem_formacao_continuada/,
    'formação continuada: cursos e pessoas (#522)';

  $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=desempenho&ano_ideb=2021")->status_is(200)->tx);
  %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{ano_ideb}[1], qr/\(2021\), cruzada com o Censo Escolar \Q$ANO\E/, 'edição antiga: cruzamento dito';
  like $d{ano_ideb}[1], qr/fechadas depois de 2021 não entram/, 'escolas fechadas';

  # #514 (QY-01): a regra, com anos fixos
  my $anos = { censo => 2025, inse => 2023, ideb => [2023, 2021] };
  my $B = 'EduMaps::BaseAnalise';
  is $B->descricao_ano_ideb({ %$anos, censo => 2023 }, 2023), 'Edição do IDEB/SAEB', 'mesmo ano: sem ressalva';
  my $mais_recente = $B->descricao_ano_ideb($anos, 2023);
  like $mais_recente, qr/\(2023\), cruzada com o Censo Escolar 2025 \(dois anos depois\)/, 'edição mais recente: distância dita';
  like $mais_recente, qr/fechadas depois de 2023 não entram/, 'escolas fechadas';
  like $mais_recente, qr/medido depois do IDEB/, 'consequência para modelos';
  like $B->descricao_ano_ideb($anos, 2021), qr/quatro anos depois/, 'edição antiga: quatro anos';
  is $B->descricao_ano_inse($anos, 2023, 1), 'Edição do SAEB do INSE (2023), a mesma do IDEB', 'INSE da mesma edição';
  like $B->descricao_ano_inse($anos, 2021, 1), qr/diferente da edição do IDEB \(2021\)/, 'INSE de outra edição';
  is $B->descricao_ano_inse($anos, 2023, 0), 'Edição do SAEB do INSE', 'sem o IDEB na base: texto curto';

  $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=desempenho,inse&ano_ideb=2021")->status_is(200)->tx);
  %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{ano_inse}[1], qr/diferente da edição do IDEB \(2021\)/, 'dicionário: INSE de outra edição do IDEB'
    if defined $cat->{inse} && $cat->{inse} != 2021;
};

subtest 'matrículas da escola (#516)' => sub {
  # A com matrículas (B sem linha: vazio, não 0)
  $dbh->do(q{INSERT INTO clean.censo_matriculas
    (nu_ano_censo, co_entidade, qt_mat_bas, qt_mat_inf_cre, qt_mat_inf_pre, qt_mat_fund_ai, qt_mat_fund_af,
     qt_mat_med, qt_mat_prof, qt_mat_eja, qt_mat_esp, qt_mat_bas_int)
    VALUES (?, ?, 300, 40, 60, 200, 0, 0, 0, 0, 12, 25)}, {}, $ANO, $A);
  my $c = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=matriculas,indices")->status_is(200)->tx);
  my @cab = @{ $c->[0] };
  my %i; @i{@cab} = 0 .. $#cab;
  my @col = qw(mat_basica mat_creche mat_pre mat_ai mat_af mat_medio mat_profissional mat_eja mat_especial mat_integral);
  ok( (!grep { !defined $i{$_} } @col), 'as dez colunas');
  my ($a) = grep { $_->[0] eq $A } @$c;
  my ($b) = grep { $_->[0] eq $B } @$c;
  is [ @$a[ @i{@col} ] ], [qw(300 40 60 200 0 0 0 0 12 25)], 'matrículas da escola; 0 é 0';
  is [ @$b[ @i{@col} ] ], [ ('') x 10 ], 'escola sem linha de matrículas: vazio';

  my $d = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=matriculas")->tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{mat_creche}[1], qr/não somam o total.*mat_basica/, 'dicionário: as etapas não somam o total';
  like $d{mat_basica}[1], qr/0 é 0 matrículas/, 'dicionário: vazio e 0';
  like $d{mat_creche}[3], qr/Censo Escolar/, 'fonte';
};

subtest 'parceria com o poder público (#518)' => sub {
  # A: municipal com parceria estadual; B vira, só neste subtest, uma privada
  # filantrópica conveniada com a prefeitura e o estado.
  $dbh->do('UPDATE clean.censo_escolas SET in_poder_publico_parceria = 1, tp_poder_publico_parceria = 2
            WHERE co_entidade = ?', {}, $A);
  $dbh->do('UPDATE clean.censo_escolas SET tp_dependencia = 4, in_poder_publico_parceria = 1,
            tp_poder_publico_parceria = 3, tp_categoria_escola_privada = 4 WHERE co_entidade = ?', {}, $B);
  my $c = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=matriculas,parceria")->status_is(200)->tx);
  my @cab = @{ $c->[0] };
  my %i; @i{@cab} = 0 .. $#cab;
  my @col = qw(parceria_poder_publico parceria_esfera categoria_privada);
  is [ @cab[ map { $i{$_} } @col ] ], \@col, 'as três colunas';
  ok $i{parceria_poder_publico} > $i{mat_integral}, 'depois das matrículas';
  my ($a) = grep { $_->[0] eq $A } @$c;
  my ($b) = grep { $_->[0] eq $B } @$c;
  is [ @$a[ @i{@col} ] ], [1, 'Estadual', ''], 'pública com parceria: sem categoria';
  is [ @$b[ @i{@col} ] ], [1, 'Estadual e municipal', 'Filantrópica'], 'privada conveniada';

  $dbh->do('UPDATE clean.censo_escolas SET in_poder_publico_parceria = 0, tp_poder_publico_parceria = NULL
            WHERE co_entidade = ?', {}, $A);
  ($a) = grep { $_->[0] eq $A } @{ ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=parceria")->tx) };
  is [ @$a[ 13 .. 15 ] ], [0, '', ''], 'sem parceria: 0 e vazio (depois do endereço, #531)';

  my $d = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=parceria")->tx);
  my %d = map { $_->[0] => $_ } @$d[1 .. $#$d];
  like $d{parceria_poder_publico}[1], qr/filtre a rede privada/, 'dicionário: públicas com parceria';
  like $d{parceria_esfera}[1], qr/oferta da prefeitura/, 'dicionário: a esfera da prefeitura';
  # #520 (QV-01): o Censo marca a escola, não a vaga; a soma é um teto.
  like $d{parceria_poder_publico}[1], qr/não a vaga.*teto.*Particular/, 'dicionário: a soma das conveniadas é um teto';
  unlike $d{parceria_poder_publico}[1], qr/custeia/, 'dicionário: sem dizer que o convênio custeia tudo';

  $dbh->do('UPDATE clean.censo_escolas SET in_poder_publico_parceria = NULL, tp_poder_publico_parceria = NULL WHERE co_entidade = ?', {}, $A);
  $dbh->do('UPDATE clean.censo_escolas SET tp_dependencia = 2, in_poder_publico_parceria = NULL,
            tp_poder_publico_parceria = NULL, tp_categoria_escola_privada = NULL WHERE co_entidade = ?', {}, $B);
};

subtest 'remuneração do SIOPE por escola (#491)' => sub {
  my $SIOPE = 2001;
  my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
     (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, carga_horaria, salario_total)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  my $mag = 'Profissionais do magistério';
  my @l = (
    # duas pessoas com o MESMO CPF mascarado; Bruno com dois vínculos em janeiro
    ['Janeiro',   'ANA',   30, 3000, $mag], ['Fevereiro', 'ANA',   30, 3000, $mag], ['Dezembro', 'ANA',   30, 6000, $mag],
    ['Janeiro',   'BRUNO', 40, 4000, $mag], ['Janeiro',   'BRUNO', 20, 1000, $mag],
    ['Fevereiro', 'BRUNO', 40, 4000, $mag], ['Dezembro',  'BRUNO', 40, 4000, $mag],
  );
  $f->execute($SIOPE, $_->[0], $_->[1], 'xxx.111.221-xx', $A, '600039', 'Municipal', 'Docente', $_->[4], $_->[2], $_->[3]) for @l;
  $f->execute($SIOPE, $_, 'CAIO', 'xxx.999.881-xx', $A, '600039', 'Municipal', 'Apoio', 'Outros profissionais da educação', 40, 2000)
    for qw(Janeiro Fevereiro Dezembro);
  # agregado da Secretaria: não é escola, fica fora
  $f->execute($SIOPE, 'Janeiro', 'DORA', 'xxx.555.551-xx', 99999999, '600039', 'Municipal', 'Docente', $mag, 40, 9999);
  # #512 (QZ-02): uma auxiliar educacional (outros profissionais)
  my $aux = $EduMaps::BaseAnalise::AUX_EDUCACIONAL;
  $f->execute($SIOPE, $_->[0], 'EVA', 'xxx.777.771-xx', $A, '600039', 'Municipal', $aux, 'Outros profissionais da educação', 30, $_->[1])
    for ['Janeiro', 1500], ['Fevereiro', 1500], ['Dezembro', 3000];
  # 2002: a escola só com a auxiliar (como as creches de Cuiabá)
  my $SIOPE2 = 2002;
  $f->execute($SIOPE2, $_, 'EVA', 'xxx.777.771-xx', $A, '600039', 'Municipal', $aux, 'Outros profissionais da educação', 30, 1600)
    for qw(Janeiro Fevereiro);
  # #554: escola que o SIOPE declara e o Censo não tem (código novo): fora da lista da base
  my $FORA = '60003904';
  $f->execute($SIOPE, 'Janeiro', 'FABIO', 'xxx.444.441-xx', $FORA, '600039', 'Municipal', 'Docente', $mag, 40, 500);
  # mês só com a Secretaria: não conta nos meses da cobertura
  $f->execute($SIOPE2, 'Março', 'DORA', 'xxx.555.551-xx', 99999999, '600039', 'Municipal', 'Docente', $mag, 40, 9999);

  # #553: a fonte de cada pagamento: o magistério pela parcela de 70% do
  # Fundeb, a auxiliar pela de 30% e o apoio (CAIO) por outras fontes.
  $dbh->do(q{UPDATE clean.remuneracao_municipal
                SET salario_fundeb_max = CASE WHEN tipo = ? THEN salario_total ELSE 0 END,
                    salario_fundeb_min = CASE WHEN categoria = ? THEN salario_total ELSE 0 END,
                    salario_outros     = CASE WHEN tipo <> ? AND categoria <> ? THEN salario_total ELSE 0 END
              WHERE cod_inep = ? AND ano = ?}, {}, $mag, $aux, $mag, $aux, $A, $SIOPE);

  my $r = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->tx->res->json;
  ok( (grep { $_ == $SIOPE } @{ $r->{anos}{siope} }), 'ano da folha no catálogo');

  my $tx = $t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao&ano_siope=$SIOPE")->status_is(200)
    ->header_like('Content-Disposition' => qr/censo\Q$ANO\E-siope$SIOPE\.csv/)->tx;
  my $c = ler_csv($tx);
  my @cab = @{ $c->[0] };
  my %i; @i{@cab} = 0 .. $#cab;
  my ($a) = grep { $_->[0] eq $A } @$c;
  my ($b) = grep { $_->[0] eq $B } @$c;
  is [ @$a[ @i{qw(prof_magisterio salario_medio_magisterio carga_horaria_media_magisterio salario_40h_magisterio gasto_pessoal_ano meses_folha)} ] ],
     ['2', '3750', '40', '3833', '37000', '3'],
     'pessoa = CPF mascarado + nome; média por pessoa e mês sem dezembro; gasto do ano com o 13º (e a auxiliar); sem a Secretaria';
  # #553: as três fontes somam o gasto do ano (37000)
  is [ @$a[ @i{qw(gasto_fundeb_70_ano gasto_fundeb_30_ano gasto_outras_fontes_ano)} ] ], ['25000', '6000', '6000'],
     'gasto por fonte: Fundeb 70%, Fundeb 30% e outras';
  ok !(grep { defined && /e\+/ } @$a), 'nenhum valor em notação científica';
  is [ @$b[ @i{qw(gasto_fundeb_70_ano gasto_fundeb_30_ano gasto_outras_fontes_ano)} ] ], ['', '', ''],
     'escola sem folha: as fontes vazias';
  # #512 (QZ-03): pessoas por mês (ANA e BRUNO nos três meses)
  is $a->[ $i{prof_magisterio_mes} ], '2', 'magistério por mês';
  # #561: sem mês incompleto, as colunas dos meses completos repetem o ano
  is [ @$a[ @i{qw(meses_completos gasto_pessoal_meses_completos)} ] ], ['3', '37000'], 'sem mês incompleto: igual ao ano';
  # #512 (QZ-02): a auxiliar, no ano, por mês e o salário sem dezembro
  is [ @$a[ @i{qw(aux_educacional aux_educacional_mes salario_medio_aux_educacional)} ] ], ['1', '1', '1500'],
     'auxiliares e assistentes educacionais';
  ok $i{prof_magisterio_mes} < $i{salario_medio_magisterio} && $i{salario_medio_aux_educacional} < $i{gasto_pessoal_ano},
     'colunas novas entre as do magistério e o gasto';
  is [ @$b[ @i{qw(prof_magisterio salario_medio_magisterio gasto_pessoal_ano meses_folha)} ] ], ['', '', '', ''],
     'escola estadual sem folha: vazio, não zero';
  ok !(grep { /nome|cpf/ } @cab), 'sem nome nem CPF';
  is $cab[-1], 'ano_siope', 'ano da folha no fim';
  is $a->[-1], "$SIOPE", 'ano da folha em toda linha';

  my $d = ler_csv($t->get_ok("/api/base-analise/dicionario?uf=AC&blocos=remuneracao&ano_siope=$SIOPE")->tx);
  my ($linha) = grep { $_->[0] eq 'prof_magisterio' } @$d;
  like $linha->[3], qr/SIOPE/, 'fonte no dicionário';
  is $linha->[4], "$SIOPE", 'ano no dicionário';
  my ($f70) = grep { $_->[0] eq 'gasto_fundeb_70_ano' } @$d;
  like $f70->[1], qr/Não é a verificação do mínimo de 70%/, 'dicionário avisa que não é o mínimo legal';
  $t->get_ok("/api/base-analise/csv?uf=AC&blocos=remuneracao&ano_siope=1990")->status_is(400);

  # #512 (QZ-02): só a auxiliar no ano: 0 no magistério, salário vazio
  my $c2 = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao&ano_siope=$SIOPE2")->tx);
  my ($a2) = grep { $_->[0] eq $A } @$c2;
  is [ @$a2[ @i{qw(prof_magisterio prof_magisterio_mes salario_medio_magisterio aux_educacional salario_medio_aux_educacional)} ] ],
     ['0', '0', '', '1', '1600'], 'escola sem magistério: 0 pessoas, salário vazio, auxiliar presente';
  my ($sm) = grep { $_->[0] eq 'salario_medio_magisterio' } @$d;
  like $sm->[1], qr/prof_magisterio = 0/, 'dicionário diz o motivo do salário vazio com 0 no magistério';
  my ($pm) = grep { $_->[0] eq 'prof_magisterio' } @$d;
  like $pm->[1], qr/Não é o número de docentes/, 'dicionário: prof_magisterio não é o número de docentes';

  # #512 (QZ-01): a folha da UF no catálogo e o padrão da UF
  my $cat = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->tx->res->json;
  my ($cid) = grep { $_->{codigo_ibge} eq "$MUN" } @{ $cat->{folha}{municipios} };
  ok $cid, 'município do teste na cobertura da UF';
  is $cid->{uf}, 'AC', 'UF do município';
  is [ map { [ @$_{qw(ano meses escolas)} ] } @{ $cid->{anos} } ], [[2002, 2, 1], [2001, 3, 2]],
    'anos (mais recente primeiro), meses e escolas (a do SIOPE fora do Censo também)';
  # #554 (QS-02 da P5): o total declarado e de onde vem; as partes fecham
  my ($a2001) = grep { $_->{ano} == 2001 } @{ $cid->{anos} };
  my $fe = $a2001->{fechamento};
  is [ @$fe{qw(total escolas_base secretaria fora_total)} ], [47499, 37000, 9999, 500],
    'fechamento: escolas da base + Secretaria + fora da lista = total';
  is $fe->{fora}, [{ inep => '60003904', escola => undef, valor => 500 }], 'a escola fora da lista, com o código';
  # #579 (QG-01 da P6): a folha inteira por fonte (o teste do #553 marca o
  # magistério de A pela parcela de 70%, a auxiliar pela de 30%, o apoio por outras)
  is $fe->{por_fonte}, { fundeb_70 => 25000, fundeb_30 => 6000, outras => 6000 }, 'a folha inteira por fonte (a Secretaria e a escola fora, sem fonte, ficam de fora da soma das fontes)';
  my ($a2002) = grep { $_->{ano} == 2002 } @{ $cid->{anos} };
  is [ @{ $a2002->{fechamento} }{qw(total escolas_base secretaria fora_total)} ], [13199, 3200, 9999, 0],
    'em 2002: a auxiliar e o mês só da Secretaria';
  is $cat->{folha}{escolas}{2001}, 1, 'escolas do recorte com folha em 2001';
  is $cat->{folha}{escolas}{2002}, 1, 'e em 2002';
  if (!grep { $_->{codigo_ibge} ne "$MUN" } @{ $cat->{folha}{municipios} }) {
    is $cat->{folha}{padrao}, 2002, 'sem ano completo na UF: o mais recente da UF';
    $t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao")->status_is(200)
      ->header_like('Content-Disposition' => qr/-siope2002\.csv/, 'CSV sem ano_siope: o padrão da UF');
  }
  is $t->get_ok('/api/base-analise')->tx->res->json->{folha}, undef, 'sem UF: sem a folha da UF';

  my $padrao = EduMaps::BaseAnalise->siope_padrao_uf([
    { anos => [ { ano => 2026, meses => 8, escolas => 48 }, { ano => 2025, meses => 12, escolas => 0 } ] },
    { anos => [ { ano => 2024, meses => 12, escolas => 10 } ] },
  ]);
  is $padrao, 2024, 'padrão da UF: último ano completo com escolas (o só-Secretaria não conta)';
  is(EduMaps::BaseAnalise->siope_padrao_uf([]), undef, 'UF sem folha: sem padrão');
};

subtest 'erros' => sub {
  $t->get_ok('/api/base-analise/csv')->status_is(400)->json_like('/error' => qr/UF/);
  $t->get_ok('/api/base-analise/csv?uf=XX')->status_is(400);
  $t->get_ok('/api/base-analise/csv?uf=AC&blocos=salarios')->status_is(400)->json_like('/error' => qr/salarios/);
  $t->get_ok('/api/base-analise/csv?uf=AC&blocos=desempenho&ano_ideb=1990')->status_is(400)->json_like('/error' => qr/1990/);
  $t->get_ok('/api/base-analise/csv?uf=AC&rede=comunitaria')->status_is(400);
};

# #524 (QT-01): o vínculo do docente só é perguntado na escola pública; na
# privada, prop_efetivos fica vazia e o índice de capacitação docente pode
# chegar a 10 (antes, teto de 8).
subtest 'concursados vazios nas privadas (#524)' => sub {
  my $p = $dbh->selectrow_hashref(q{
    SELECT e.sg_uf, e.co_municipio::text AS mun
      FROM clean.censo_escolas e
      JOIN clean.censo_docentes d ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = e.nu_ano_censo
     WHERE e.tp_dependencia = 4 AND e.tp_situacao_funcionamento = 1 AND e.nu_ano_censo = ? AND d.qt_doc_bas > 0
     ORDER BY e.co_entidade LIMIT 1}, undef, $ANO);
  SKIP: {
    skip 'nenhuma privada com docentes no banco', 3 unless $p;
    my $l = ler_csv($t->get_ok("/api/base-analise/csv?uf=$p->{sg_uf}&codigo_ibge=$p->{mun}&rede=privada&blocos=docencia")->status_is(200)->tx);
    my %i; @i{ @{ $l->[0] } } = 0 .. $#{ $l->[0] };
    my @linhas = @$l[1 .. $#$l];
    ok @linhas > 0, 'privadas na base';
    is [ grep { $_->[ $i{prop_efetivos} ] ne '' } @linhas ], [], 'prop_efetivos vazia em toda privada';
  }
  like $EduMaps::Model::Rank::School::METODO{capacitacao_docente},
    qr/Na escola privada, a parte de concursados fica de fora.*indices-v6/, 'método diz a mudança';
};

subtest 'mês com a folha pela metade (#557)' => sub {
  my $ANO_F = 2003;
  my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
     (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, carga_horaria, salario_total)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  my @pessoas = (['ANA', 'Docente', 'Profissionais do magistério'], ['BIA', 'Docente', 'Profissionais do magistério'],
                 ['CIDA', 'Merendeira', 'Outros profissionais da educação'], ['DUDA', 'Merendeira', 'Outros profissionais da educação']);
  my %mes = (
    Janeiro => [0, 1, 2],          # janeiro mais baixo (3 de 4), com as duas categorias: não é alarme
    Fevereiro => [0 .. 3], 'Março' => [0 .. 3], Abril => [0 .. 3],
    Maio => [0],                   # só o magistério: incompleto
    Dezembro => [0 .. 3],          # com o 13º: o valor dobra, os registros não
  );
  for my $m (sort keys %mes) {
    for my $k (@{ $mes{$m} }) {
      my ($nome, $cat, $tipo) = @{ $pessoas[$k] };
      $f->execute($ANO_F, $m, $nome, "xxx.$k$k$k.33$k-xx", $A, '600039', 'Municipal', $cat, $tipo, 40, $m eq 'Dezembro' ? 4000 : 2000);
    }
  }

  my $inc = EduMaps::BaseAnalise->meses_incompletos($dbh, '600039');
  is [ map { [ @$_{qw(mes nome registros categorias registros_habitual categorias_habitual)} ] } @{ $inc->{"600039|$ANO_F"} } ],
     [[5, 'maio', 1, 1, 4, 2]], 'só maio: uma categoria e um registro contra 2 e 4';

  my $cat = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->tx->res->json;
  my ($cid) = grep { $_->{codigo_ibge} eq "$MUN" } @{ $cat->{folha}{municipios} };
  my ($a3) = grep { $_->{ano} == $ANO_F } @{ $cid->{anos} };
  is [ map { $_->{nome} } @{ $a3->{incompletos} } ], ['maio'], 'cobertura com o mês incompleto';
  my ($a1) = grep { $_->{ano} == 2001 } @{ $cid->{anos} };
  is $a1->{incompletos}, [], 'ano sem mês incompleto: lista vazia';

  my $c = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao&ano_siope=$ANO_F")->tx);
  my %i; @i{ @{ $c->[0] } } = 0 .. $#{ $c->[0] };
  my ($a) = grep { $_->[0] eq $A } @$c;
  my ($b) = grep { $_->[0] eq $B } @$c;
  is $a->[ $i{meses_folha_incompletos} ], 'mai', 'coluna da base com o mês incompleto';
  # #561 (QM-01 da P4): o gasto só dos meses completos, para anualizar
  is [ @$a[ @i{qw(meses_folha meses_completos gasto_pessoal_ano gasto_pessoal_meses_completos)} ] ], ['6', '5', '48000', '46000'],
    'meses completos: sem maio (2.000); dezembro com o 13º entra';
  is [ @$b[ @i{qw(meses_completos gasto_pessoal_meses_completos)} ] ], ['', ''], 'escola sem folha: vazio';
  is $b->[ $i{meses_folha_incompletos} ], '', 'escola sem folha: vazio';
  ok $i{meses_folha_incompletos} == $i{meses_folha} + 1, 'logo depois de meses_folha';

  my $r = $t->get_ok("/api/school/$A/finance?ano=$ANO_F")->status_is(200)->tx->res->json;
  is [ map { $_->{nome} } @{ $r->{meses_incompletos} // [] } ], ['maio'], 'painel financeiro com o mês incompleto';
};

subtest 'mês da Secretaria não conta como por escola (#558)' => sub {
  my $ANO_S = 2004;
  my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
     (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, carga_horaria, salario_total)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  my $mag = 'Profissionais do magistério';
  # janeiro só na escola; fevereiro dividido, a maior parte na escola;
  # março com um centavo na escola e o resto na Secretaria; abril só na Secretaria
  my @l = (['Janeiro', $A, 3000], ['Fevereiro', $A, 3000], ['Fevereiro', 99999999, 1000],
           ['Março', $A, 0.01], ['Março', 99999999, 5000], ['Abril', 99999999, 5000]);
  $f->execute($ANO_S, $_->[0], 'ANA', 'xxx.111.444-xx', $_->[1], '600039', 'Municipal', 'Docente', $mag, 40, $_->[2]) for @l;

  my $lugar = EduMaps::BaseAnalise->meses_por_lugar($dbh, '600039')->{"600039|$ANO_S"};
  is $lugar, { escola => [1, 2], secretaria => [3, 4] }, 'pela maior parte do valor';

  my $cat = $t->get_ok("/api/base-analise?uf=AC&codigo_ibge=$MUN")->tx->res->json;
  my ($cid) = grep { $_->{codigo_ibge} eq "$MUN" } @{ $cat->{folha}{municipios} };
  my ($a4) = grep { $_->{ano} == $ANO_S } @{ $cid->{anos} };
  is [ @$a4{qw(meses escolas)} ], [2, 1], 'meses por escola: só janeiro e fevereiro';
  is [ $a4->{meses_escola}, $a4->{meses_secretaria} ], [[1, 2], [3, 4]], 'as duas listas de meses';

  my $r = $t->get_ok("/api/school/$A/finance?ano=$ANO_S")->status_is(200)->tx->res->json;
  is $r->{meses_secretaria}, [3, 4], 'painel da escola: os meses só da Secretaria';
};

subtest 'salário base e o piso do magistério (#563)' => sub {
  my $ANO_P = 2026;
  is(EduMaps::BaseAnalise->piso_magisterio(2026), 5130.63, 'piso de 2026');
  is(EduMaps::BaseAnalise->piso_magisterio(2001), undef, 'ano sem piso cadastrado');
  my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
     (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, carga_horaria, salario_base, salario_total)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  my $mag = 'Profissionais do magistério';
  my @l = (
    # ANA: base de 4.000 por 40 h nos três meses, abaixo do piso
    (map { ['ANA', $_, 40, 4000, 6000] } qw(Janeiro Fevereiro Março)),
    # BIA: admitida em janeiro (mês pela metade), depois 6.000: não conta
    ['BIA', 'Janeiro', 40, 1000, 1500], ['BIA', 'Fevereiro', 40, 6000, 7000], ['BIA', 'Março', 40, 6000, 7000],
    # CAIO: 5.000 por 20 h = 10.000 por 40 h
    (map { ['CAIO', $_, 20, 5000, 5500] } qw(Janeiro Fevereiro Março)),
    # dezembro fica de fora (13º)
    ['ANA', 'Dezembro', 40, 100, 12000],
  );
  $f->execute($ANO_P, $_->[1], $_->[0], "xxx.$_->[0].563-xx", $A, '600039', 'Municipal', 'Docente', $mag, $_->[2], $_->[3], $_->[4]) for @l;
  # #575: na Secretaria, sem escola: DUDA abaixo nos três meses; EVA só em março (avulso)
  $f->execute($ANO_P, $_, 'DUDA', 'xxx.DUDA.575-xx', 99999999, '600039', 'Municipal', 'Docente', $mag, 40, 3000, 4000) for qw(Janeiro Fevereiro Março);
  $f->execute($ANO_P, 'Março', 'EVA', 'xxx.EVA.575-xx', 99999999, '600039', 'Municipal', 'Docente', $mag, 40, 1000, 1000);

  my $c = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao&ano_siope=$ANO_P")->tx);
  my %i; @i{ @{ $c->[0] } } = 0 .. $#{ $c->[0] };
  my ($a) = grep { $_->[0] eq $A } @$c;
  my ($b) = grep { $_->[0] eq $B } @$c;
  is [ @$a[ @i{qw(salario_base_40h_magisterio piso_magisterio_ano prof_magisterio_base_abaixo_piso)} ] ], ['6111', '5130,63', '1'],
    'base médio por 40 h, o piso do ano e só ANA abaixo (BIA não, pelo mês de admissão)';
  is [ @$b[ @i{qw(salario_base_40h_magisterio piso_magisterio_ano prof_magisterio_base_abaixo_piso)} ] ], ['', '', ''], 'escola sem folha: vazio';
  ok $i{salario_base_40h_magisterio} == $i{salario_40h_magisterio} + 1, 'logo depois do salário total';
  # #575 (QH-01 da P5): na rede inteira, com a Secretaria; EVA (1 mês) não conta
  my $s = EduMaps::BaseAnalise->salario_rede($dbh, '600039')->{"600039|$ANO_P"};
  is [ @$s{qw(piso abaixo_piso abaixo_piso_so_secretaria)} ], [5130.63, 2, 1], 'rede: ANA e DUDA abaixo, DUDA só na Secretaria';
  is $a->[ $i{carga_comum_municipio} ], '40', '#572: carga mais comum do município, em horas';

  my $c1 = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao&ano_siope=2001")->tx);
  my %j; @j{ @{ $c1->[0] } } = 0 .. $#{ $c1->[0] };
  my ($a1) = grep { $_->[0] eq $A } @$c1;
  is [ @$a1[ @j{qw(piso_magisterio_ano prof_magisterio_base_abaixo_piso)} ] ], ['', ''], 'ano sem piso: vazio, não zero';

  my $d = ler_csv($t->get_ok("/api/base-analise/dicionario?uf=AC&blocos=remuneracao&ano_siope=$ANO_P")->tx);
  my ($ab) = grep { $_->[0] eq 'prof_magisterio_base_abaixo_piso' } @$d;
  like $ab->[1], qr/Não é a verificação legal do piso/, 'dicionário avisa';
};

subtest 'carga que não parece em horas (#572)' => sub {
  my $ANO_C = 2005;
  my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
     (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, carga_horaria, salario_base, salario_total)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  for my $p (qw(ANA BIA CAIO)) {
    $f->execute($ANO_C, $_, $p, "xxx.$p.572-xx", $A, '600039', 'Municipal', 'Docente', 'Profissionais do magistério', 18, 2000, 5000)
      for qw(Janeiro Fevereiro Março);
  }
  my $s = EduMaps::BaseAnalise->salario_rede($dbh, '600039')->{"600039|$ANO_C"};
  is [ $s->{carga_comum}, !!${ $s->{carga_suspeita} } ], [18, 1], 'carga 18 na maioria: suspeita';
  # #595: o work_mem maior vale só na consulta do salário
  $dbh->do(q{SET work_mem = '7MB'});
  EduMaps::BaseAnalise->salario_rede($dbh, '600039');
  is $dbh->selectrow_array(q{SHOW work_mem}), '7MB', '#595: o work_mem da conexão volta ao que era';
  $dbh->do(q{RESET work_mem});

  my $c = ler_csv($t->get_ok("/api/base-analise/csv?uf=AC&codigo_ibge=$MUN&blocos=remuneracao&ano_siope=$ANO_C")->tx);
  my %i; @i{ @{ $c->[0] } } = 0 .. $#{ $c->[0] };
  my ($a) = grep { $_->[0] eq $A } @$c;
  is [ @$a[ @i{qw(salario_medio_magisterio carga_comum_municipio salario_40h_magisterio salario_base_40h_magisterio prof_magisterio_base_abaixo_piso)} ] ],
     ['5000', '18', '', '', ''], 'salário sem conversão e a carga ficam; as contas por 40 h ficam vazias';

  my $d = ler_csv($t->get_ok("/api/base-analise/dicionario?uf=AC&blocos=remuneracao&ano_siope=$ANO_C")->tx);
  my ($cc) = grep { $_->[0] eq 'carga_comum_municipio' } @$d;
  like $cc->[1], qr/não parece estar em horas semanais/, 'dicionário explica';
};

subtest 'folha por município, num arquivo (#580)' => sub {
  my $c = ler_csv($t->get_ok('/api/base-analise/folha-municipios.csv?uf=AC')->status_is(200)
    ->header_like('Content-Disposition' => qr/folha-municipios-AC\.csv/)->tx);
  my %i; @i{ @{ $c->[0] } } = 0 .. $#{ $c->[0] };
  my ($l) = grep { $_->[0] eq "$MUN" && $_->[ $i{ano} ] eq '2001' } @$c;
  ok $l, 'o município do teste em 2001';
  is [ @$l[ @i{qw(meses_por_escola escolas_com_folha total_declarado total_escolas_base total_secretaria total_fora_lista)} ] ],
     ['3', '2', '47499', '37000', '9999', '500'], 'meses, escolas e o fechamento';
  is [ @$l[ @i{qw(fundeb_70 fundeb_30 outras_fontes)} ] ], ['25000', '6000', '6000'], 'a folha inteira por fonte';
  ok exists $i{abaixo_piso_rede} && exists $i{data_carga} && exists $i{sha256_planilha}, 'piso da rede e a carga';
  $t->get_ok('/api/base-analise/folha-municipios.csv')->status_is(400);
  my $d = ler_csv($t->get_ok('/api/base-analise/folha-municipios-dicionario.csv')->status_is(200)->tx);
  is scalar(@$d) - 1, scalar(@{ $c->[0] }), 'uma linha do dicionário por coluna';
  my ($fu) = grep { $_->[0] eq 'fundeb_70' } @$d;
  like $fu->[1], qr/Não é a verificação do mínimo legal/, 'o aviso do Fundeb';
};

done_testing;
