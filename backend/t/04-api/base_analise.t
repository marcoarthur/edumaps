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
  $dbh->do('DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.inse WHERE id_escola IN (?, ?, ?)', {}, @INEPS);
  $dbh->do('DELETE FROM clean.populacao_municipal WHERE codigo_ibge = ?', {}, "$MUN");
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep IN (?, ?, ?) OR (cod_municipio::text = ? AND ano IN (2001, 2002))', {}, @INEPS, '600039');
};
$limpa->();
END { $limpa->() }

my $esc = $dbh->prepare('INSERT INTO clean.censo_escolas
   (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, tp_localizacao, co_municipio, no_municipio,
    sg_uf, tp_situacao_funcionamento, in_agua_potavel, in_internet,
    in_esgoto_rede_publica, in_esgoto_inexistente, in_energia_inexistente, in_agua_inexistente,
    latitude, longitude,
    in_comum_fund_ai, in_comum_medio_medio, in_comum_medio_integrado, in_comum_medio_normal, in_profissionalizante)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
# #461: Alfa oferece anos iniciais e não oferece médio; Beta só tem o médio
# integrado (conta como médio) e não respondeu a educação profissional.
# #452: Alfa tem fossa (esgoto fora da rede pública, mas tem esgoto) e
# coordenadas com mais de 6 casas; Beta não tem esgoto nem coordenadas.
$esc->execute($ANO, $A,       'Escola "Alfa"', 3, 1, $MUN, 'Cidade Teste', 'AC', 1, 1, 1,     0, 0, 0, 0, -9.97432149, -67.8076543, 1, 0, 0, 0, 0);
$esc->execute($ANO, $B,       'Escola Beta',        2, 2, $MUN, 'Cidade Teste', 'AC', 1, 0, undef, 0, 1, 0, 0, undef, undef, 0, 0, 1, 0, undef);
$esc->execute($ANO, $FECHADA, 'Escola Fechada',     3, 1, $MUN, 'Cidade Teste', 'AC', 2, 1, 1,     1, 0, 0, 0, undef, undef, 1, 0, 0, 0, 0);

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
  is [map { $_->{id} } @{ $r->{blocos} }], [qw(identificacao etapas infraestrutura docencia desempenho indices inse remuneracao porte)], 'blocos (etapas depois da identificação, #461; índices depois do IDEB, #465; remuneração, #491)';
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
  is $l->[0], [qw(inep escola codigo_ibge municipio uf regiao rede localizacao latitude longitude ano_censo)],
    'cabeçalho (região depois da UF, #448; coordenadas no fim da identificação, #452)';
  is scalar @$l, 3, 'cabeçalho + 2 escolas (a fechada fica fora)';
  is $l->[1], [$A, '"Escola ""Alfa"""', "$MUN", 'Cidade Teste', 'AC', 'Norte', 'Municipal', 'Urbana', '-9,974321', '-67,807654', "$ANO"],
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
  # #452 (VJ-01): fora da rede pública não é "sem".
  is [ @a[ @i{qw(in_esgoto_rede_publica in_esgoto_inexistente)} ] ], ['0', '0'], 'Alfa: fossa, tem esgoto';
  is [ @b[ @i{qw(in_esgoto_rede_publica in_esgoto_inexistente)} ] ], ['0', '1'], 'Beta: sem esgoto';
  is [ @cab[ $i{in_agua_potavel} + 1, $i{in_energia_rede_publica} + 1, $i{in_esgoto_rede_publica} + 1 ] ],
    [qw(in_agua_inexistente in_energia_inexistente in_esgoto_inexistente)], 'cada "inexistente" ao lado do serviço';
  is $b[$i{latitude}], '', 'sem coordenada: vazio';
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
  is $d{populacao_municipio}[4], '2025', 'ano da população';
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
    is [ @cab[ $i{prop_sem_especializacao} + 1 .. $i{prop_sem_especializacao} + 3 ] ],
      [qw(prop_superior prop_pos_graduacao prop_formacao_continuada)], 'no fim do bloco, na ordem';
    my ($linha) = grep { $_->[0] eq $s->{inep} } @$l[1 .. $#$l];
    my $v = sub ($c) { my $x = $linha->[ $i{$c} ]; $x =~ tr/,/./; 0 + $x };
    my $refeito = 10 * (0.3 * $v->('prop_superior') + 0.3 * $v->('prop_pos_graduacao')
                      + 0.2 * ($v->('prop_efetivos') > 1 ? 1 : $v->('prop_efetivos')) + 0.2 * $v->('prop_formacao_continuada'));
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
  is $d{ano_ideb}[1], 'Edição do IDEB/SAEB', 'edição mais recente: sem ressalva';
  like $d{qt_docentes}[1], qr/mais de uma escola conta em cada uma/, 'contagem por escola';
  like $d{$_}[1], qr/÷ docentes da escola \(qt_docentes\)/, "$_: denominador"
    for qw(prop_licenciatura prop_mestrado prop_doutorado prop_efetivos prop_sem_especializacao
           prop_superior prop_pos_graduacao prop_formacao_continuada);
  like $d{prop_superior}[1], qr/Parte de 30% do índice de capacitação docente/, 'superior: parte do índice (#469)';
  like $d{prop_pos_graduacao}[1], qr/limitada a 1.*Parte de 30%/, 'pós: limite e parte';
  like $d{prop_formacao_continuada}[1], qr/Parte de 20%/, 'formação continuada: parte';
  like $d{prop_efetivos}[1], qr/Parte de 20%/, 'efetivos: parte';

  $l = ler_csv($t->get_ok("/api/base-analise/dicionario?blocos=desempenho&ano_ideb=2021")->status_is(200)->tx);
  %d = map { $_->[0] => $_ } @$l[1 .. $#$l];
  like $d{ano_ideb}[1], qr/\(2021\), cruzada com o Censo Escolar \Q$ANO\E/, 'edição antiga: cruzamento dito';
  like $d{ano_ideb}[1], qr/fechadas depois de 2021 não entram/, 'escolas fechadas';
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
  # mês só com a Secretaria: não conta nos meses da cobertura
  $f->execute($SIOPE2, 'Março', 'DORA', 'xxx.555.551-xx', 99999999, '600039', 'Municipal', 'Docente', $mag, 40, 9999);

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
  # #512 (QZ-03): pessoas por mês (ANA e BRUNO nos três meses)
  is $a->[ $i{prof_magisterio_mes} ], '2', 'magistério por mês';
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
  is [ map { [ @$_{qw(ano meses escolas)} ] } @{ $cid->{anos} } ], [[2002, 2, 1], [2001, 3, 1]],
    'anos (mais recente primeiro), meses e escolas';
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

done_testing;
