# t/02-models/censo_dictionary.t
# Dicionário canônico do Censo (clean.censo_data_dictionary, issue #134).
#
# É um GATE: no CI (fixtures) e em dev, clean.censo_dict_violacoes() tem de
# voltar vazia. Uma coluna nova sem dicionário, um código fora do domínio
# oficial do INEP ou uma in_* fora de 0/1 quebram o build. Cobre também os
# domínios-chave que o seed antigo tinha errados, as colunas derivadas e a
# capacidade de a função detectar violações (numa transação desfeita).
use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use Mojo::JSON qw(from_json);
use utf8;

my $sch = EduMaps::Schema->go;
my $dbh = $sch->storage->dbh;

my @TABELAS = qw(
  clean.censo_escolas clean.censo_matriculas clean.censo_docentes clean.censo_gestor
);

my $tem_origem = $dbh->selectrow_array(q{
  SELECT 1 FROM pg_attribute
  WHERE attrelid = to_regclass('clean.censo_data_dictionary')
    AND attname = 'origem' AND NOT attisdropped
});
skip_all('migration censo_data_dictionary_inep não aplicada') unless $tem_origem;

sub linha ($tabela, $coluna) {
  my $r = $dbh->selectrow_hashref(q{
    SELECT * FROM clean.censo_data_dictionary
    WHERE table_name = ? AND column_name = ?
    ORDER BY year_introduced DESC LIMIT 1
  }, undef, $tabela, $coluna);
  $r->{dominio} = from_json($r->{value_domain}) if $r && defined $r->{value_domain};
  return $r;
}

sub violacoes {
  return $dbh->selectall_arrayref(
    'SELECT tipo, tabela, coluna, valor, n FROM clean.censo_dict_violacoes()',
    { Slice => {} });
}

subtest 'gate: nenhuma violação do dicionário' => sub {
  my $v = violacoes();
  is(scalar @$v, 0, 'clean.censo_dict_violacoes() vazia')
    or diag join "\n", map {
      sprintf '%s %s.%s valor=%s n=%s', $_->{tipo}, $_->{tabela}, $_->{coluna},
        $_->{valor} // 'NULL', $_->{n} // 'NULL'
    } @$v;
};

subtest 'tabelas do Censo cobertas' => sub {
  for my $t (@TABELAS) {
    my $n = $dbh->selectrow_array(
      'SELECT count(*) FROM clean.censo_data_dictionary WHERE table_name = ?', undef, $t);
    ok($n > 50, "$t tem $n colunas no dicionário");
  }
};

subtest 'domínios oficiais do INEP' => sub {
  my $esc = 'clean.censo_escolas';

  my $dep = linha($esc, 'tp_dependencia');
  is($dep->{dominio},
    { 1 => 'Federal', 2 => 'Estadual', 3 => 'Municipal', 4 => 'Privada' },
    'tp_dependencia 1..4');
  is($dep->{year_introduced}, 2007, 'tp_dependencia coletada desde 2007');

  # O seed antigo tinha 1..5,8 (tipos de sala); o INEP define 0/1/2.
  for my $c (qw(tp_aee tp_atividade_complementar tp_itinerario_formativo)) {
    my $r = linha($esc, $c);
    is([sort keys %{ $r->{dominio} // {} }], [qw(0 1 2)], "$c = 0/1/2");
    is($r->{dominio}{0}, 'Não oferece', "$c: 0 = Não oferece");
  }
  is(linha($esc, 'tp_itinerario_formativo')->{year_introduced}, 2022,
    'tp_itinerario_formativo desde 2022');

  # Era "esfera de governo" no seed antigo.
  is(linha($esc, 'tp_regulamentacao')->{dominio},
    { 0 => 'Não', 1 => 'Sim', 2 => 'Em tramitação' },
    'tp_regulamentacao = Não/Sim/Em tramitação');

  my $ld = linha($esc, 'tp_localizacao_diferenciada');
  is([sort keys %{ $ld->{dominio} }], [qw(0 1 2 3 8)],
    'tp_localizacao_diferenciada = 0,1,2,3,8');
  is($ld->{dominio}{3}, 'Comunidade quilombola', 'tp_localizacao_diferenciada: 3');
  is($ld->{year_changed}, 2023, 'tp_localizacao_diferenciada mudou em 2023 (código 8)');

  is(linha($esc, 'tp_responsavel_regulamentacao')->{dominio}{9}, 'Não informado',
    'tp_responsavel_regulamentacao: 9 = Não informado');
  is(linha($esc, 'tp_rede_local')->{dominio}{9}, 'Não informado',
    'tp_rede_local: 9 = Não informado');
  # 9 que o INEP só cita nas notas ("Em 2019: existe adicionalmente…").
  is(linha($esc, 'in_material_ped_jogos')->{dominio}{9}, 'Não informado',
    'in_material_ped_jogos: 9 das notas do INEP');

  is(linha($esc, 'in_internet')->{dominio}, { 0 => 'Não', 1 => 'Sim' },
    'in_internet binária');

  # Sentinelas (88888) não viram domínio fechado de quantidades.
  my $qt = linha($esc, 'qt_equip_tv');
  ok(!defined $qt->{value_domain}, 'qt_equip_tv sem value_domain');
  like($qt->{notes} // '', qr/88888/, 'qt_equip_tv: 88888 na nota');
};

subtest 'origem: colunas derivadas e nomes divergentes' => sub {
  for my $c (qw(linha_id geometry nro_etapas nro_participacoes_exame)) {
    my $r = linha('clean.censo_escolas', $c);
    is($r && $r->{origem}, 'derivada', "$c é derivada");
    ok(($r->{notes} // '') ne '', "$c tem nota explicativa");
  }
  is(linha('clean.censo_escolas', 'latitude')->{origem}, 'inep', 'latitude vem do INEP');

  my $r = linha('clean.censo_matriculas', 'qt_mat_prof_fic_con');
  is($r->{origem}, 'inep', 'qt_mat_prof_fic_con mapeada ao INEP');
  like($r->{notes}, qr/QT_MAT_PROF_FIC_CONC/, 'nota registra o nome oficial');

  my $inep_sem_fonte = $dbh->selectrow_array(q{
    SELECT count(*) FROM clean.censo_data_dictionary
    WHERE origem = 'inep' AND table_name = ANY(?) AND source_url IS NULL
  }, undef, \@TABELAS);
  is($inep_sem_fonte, 0, 'toda linha inep tem proveniência');
};

subtest 'colunas PK marcadas' => sub {
  ok(linha('clean.censo_escolas', 'linha_id')->{is_pk}, 'linha_id é PK em censo_escolas');
  ok(!linha('clean.censo_escolas', 'co_entidade')->{is_pk}, 'co_entidade não é PK em censo_escolas');
  for my $t (qw(clean.censo_matriculas clean.censo_docentes clean.censo_gestor)) {
    ok(linha($t, 'nu_ano_censo')->{is_pk}, "nu_ano_censo é PK em $t");
    ok(linha($t, 'co_entidade')->{is_pk}, "co_entidade é PK em $t");
  }
};

subtest 'a função detecta violações (transação desfeita)' => sub {
  $dbh->begin_work;
  my $ok = eval {
    my $id = $dbh->selectrow_array('SELECT min(linha_id) FROM clean.censo_escolas');
    $dbh->do('UPDATE clean.censo_escolas SET tp_aee = 7, in_internet = 5 WHERE linha_id = ?',
      undef, $id);
    $dbh->do('ALTER TABLE clean.censo_gestor ADD COLUMN zz_coluna_teste integer');
    1;
  };
  my $v = $ok ? violacoes() : [];
  $dbh->rollback;
  ok($ok, 'violações plantadas') or diag $@;

  my %achou = map { join('|', $_->{tipo}, $_->{coluna}, $_->{valor} // '') => $_->{n} } @$v;
  is($achou{'codigo_fora_do_dominio|tp_aee|7'}, 1, 'tp_aee = 7 fora do domínio');
  is($achou{'binaria_invalida|in_internet|5'}, 1, 'in_internet = 5 binária inválida');
  ok(exists $achou{'coluna_sem_dicionario|zz_coluna_teste|'}, 'coluna nova sem dicionário');

  my $sobrou = $dbh->selectrow_array(q{
    SELECT count(*) FROM clean.censo_escolas WHERE tp_aee = 7 OR in_internet = 5
  });
  is($sobrou, 0, 'rollback: dados intactos');
};

done_testing;
