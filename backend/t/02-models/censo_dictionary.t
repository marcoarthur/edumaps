use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use Test::More;

my $sch = EduMaps::Schema->go;

subtest 'tabela censo_data_dictionary existe e tem estrutura' => sub {
    my $rs = $sch->resultset('CensoDataDictionary');
    ok($rs, 'resultset CensoDataDictionary existe');

    # Verificar se a tabela foi populada (pode ser 0 se Fase 0 não rodou)
    my $count = $rs->count;
    diag("Linhas no dicionário: $count");

    # Estrutura: deve ter as colunas obrigatórias
    my @required_cols = qw(
        table_name column_name data_type year_introduced
        is_pk is_fk value_domain description
    );
    for my $col (@required_cols) {
        ok($rs->result_source->has_column($col), "coluna $col existe");
    }
};

subtest 'tabelas censo cobertas' => sub {
    my $rs = $sch->resultset('CensoDataDictionary');
    my @tables = qw(
        clean.censo_escolas
        clean.censo_matriculas
        clean.censo_docentes
        clean.censo_gestor
    );

    for my $t (@tables) {
        my $cnt = $rs->search({ table_name => $t })->count;
        ok($cnt > 50, "$t tem $cnt colunas no dicionário (esperado > 50)");
    }
};

subtest 'tp_dependencia tem value_domain em censo_escolas' => sub {
    my $rs = $sch->resultset('CensoDataDictionary');
    # tp_dependencia só existe em censo_escolas (verificado no banco)
    my $row = $rs->find({ table_name => 'clean.censo_escolas', column_name => 'tp_dependencia' });
    ok($row, "tp_dependencia existe em clean.censo_escolas");
    ok($row->value_domain, "tp_dependencia tem value_domain em clean.censo_escolas")
        or diag("value_domain: " . ($row->value_domain // 'NULL'));

    my $dom = $row->value_domain;
    my $href = ref $dom eq 'HASH' ? $dom : eval { decode_json($dom) };
    if ($href) {
        ok(exists $href->{1} && $href->{1} eq 'Federal', "código 1 = Federal");
        ok(exists $href->{2} && $href->{2} eq 'Estadual', "código 2 = Estadual");
        ok(exists $href->{3} && $href->{3} eq 'Municipal', "código 3 = Municipal");
        ok(exists $href->{4} && $href->{4} eq 'Privada', "código 4 = Privada");
    }
};

subtest 'colunas PK/FK marcadas corretamente' => sub {
    my $rs = $sch->resultset('CensoDataDictionary');

    # censo_escolas: PK é linha_id
    my $row = $rs->find({ table_name => 'clean.censo_escolas', column_name => 'linha_id' });
    ok($row && $row->is_pk, "linha_id é PK em clean.censo_escolas");

    # co_entidade NÃO é PK em censo_escolas (PK é linha_id)
    $row = $rs->find({ table_name => 'clean.censo_escolas', column_name => 'co_entidade' });
    ok($row && !$row->is_pk, "co_entidade NÃO é PK em clean.censo_escolas");

    # nu_ano_censo + co_entidade são PK composta em matriculas/docentes/gestor
    for my $t (qw(clean.censo_matriculas clean.censo_docentes clean.censo_gestor)) {
        my $row1 = $rs->find({ table_name => $t, column_name => 'nu_ano_censo' });
        my $row2 = $rs->find({ table_name => $t, column_name => 'co_entidade' });
        ok($row1 && $row1->is_pk, "nu_ano_censo é PK em $t");
        ok($row2 && $row2->is_pk, "co_entidade é PK em $t");
    }
};

subtest 'year_introduced preenchido (2025 para primeira carga)' => sub {
    my $rs = $sch->resultset('CensoDataDictionary');
    my $sample = $rs->search(
        { table_name => 'clean.censo_escolas' },
        { rows => 10 }
    );
    while (my $r = $sample->next) {
        ok($r->year_introduced && $r->year_introduced >= 2025,
           "year_introduced = " . $r->year_introduced . " para " . $r->column_name);
    }
};

subtest 'notas em colunas tp_*/in_* sem domínio' => sub {
    my $rs = $sch->resultset('CensoDataDictionary');
    my $missing = $rs->search({
        table_name => { -in => [qw(clean.censo_escolas clean.censo_matriculas clean.censo_docentes clean.censo_gestor)] },
        column_name => { -like => 'tp_%' },
        value_domain => { '=' => undef },
    })->count;

    if ($missing > 0) {
        diag("$missing colunas tp_* sem value_domain — esperado até YAML ser completo");
    }
    # Não falha: é warning, o YAML pode não cobrir tudo ainda
    pass("tp_* sem domínio: $missing (informativo)");
};

done_testing;