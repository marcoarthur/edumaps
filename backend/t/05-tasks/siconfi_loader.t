use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);
use Mojo::File qw(path);

# =====================================================================
# Regressão do loader SICONFI (receitas RREO) — issue #165
#
# Sem rede: o UA é mockado com fixtures (o mesmo shape que a API DataLake
# do Tesouro devolve, verificado 2026-10-08). O que se verifica são as
# DECISÕES do loader, que é onde a #165 coloca o risco:
#
#   1. classificacao decidida pela COLUNA, nunca hardcoded: 'PREVISÃO
#      ATUALIZADA (a)' -> estimativa, 'Até o Bimestre (c)' -> realizada;
#      'PREVISÃO INICIAL' e 'No Bimestre (b)' saem (colidiriam na PK);
#   2. só o RREO-Anexo 01 entra — os anexos temáticos (03/06/14/...) repetem
#      receita com rótulos próprios de coluna e o Anexo 04 reusa literalmente
#      'PREVISÃO ATUALIZADA (a)', colidindo na PK; receita vs. despesa
#      separa-se pela coluna;
#   3. totais/subtotais fora (duplicariam qualquer agregação);
#   4. count==0 com HTTP 200 morre, não passa como sucesso;
#   5. paginação por hasMore (o `count` do ORDS é POR PÁGINA);
#   6. /entes cacheado por municípios (esfera M) para a iteração;
#   7. load idempotente: ON CONFLICT na PK exata, dt_snapshot no parâmetro;
#   8. idempotência com BD real: reexecutar não viola a PK (se houver BD).
# =====================================================================

my $JOB = 'EduMaps::Ingestion::Job::SICONFI';
require_ok($JOB);

sub mk_job {
  my ($handler, %extra) = @_;
  return $JOB->new(
    log              => Mojo::Log->new(level => 'fatal'),
    ua               => MockUA->new($handler),
    throttle         => 0,
    max_retries      => 0,
    entes_cache_file => path(tempdir(CLEANUP => 1))->child('entes.json'),
    %extra,
  );
}

# --- Mocks (UA, resposta, app, dbh) -------------------------------------
{
  package MockRes;
  sub new { my ($c, $json, $code) = @_; bless { json => $json, code => $code // 200 }, $c }
  sub code { $_[0]{code} }
  sub json { $_[0]{json} }
}
{
  package MockTx;
  sub new { my ($c, $res) = @_; bless { res => $res }, $c }
  sub res { $_[0]{res} }
}
{
  package MockUA;
  # handler: sub ($url, $form) -> ($json) ou ($json, $code)
  sub new { my ($c, $handler) = @_; bless { handler => $handler, calls => [] }, $c }
  sub get {
    my ($self, $url, %args) = @_;
    my $form = $args{form} // {};
    push @{$self->{calls}}, [ $url, { %$form } ];
    my @r = $self->{handler}->($url, $form);
    my ($json, $code) = @r == 2 ? @r : ($r[0], 200);
    return MockTx->new(MockRes->new($json, $code));
  }
}
{
  package MockDBH;
  # fail_execute => 1 faz o execute explodir (regressão do erro engolido)
  sub new { my ($c, %o) = @_; bless { stmts => [], inserts => [], dos => [], rolled => 0, commits => [], %o }, $c }
  sub begin_work { }
  sub commit     { push @{$_[0]{commits}}, 1; return 1 }
  sub rollback   { $_[0]{rolled}++; return 1 }
  sub prepare    { my ($self, $sql) = @_; push @{$self->{stmts}}, $sql; bless { dbh => $self }, 'MockSTH' }
  sub do         { my ($self, $sql, @p) = @_; push @{$self->{dos}}, [ $sql, @p ]; return 1 }
}
{
  package MockSTH;
  sub execute {
    my ($self, @p) = @_;
    die "exec exploded: erro original do banco\n" if $self->{dbh}{fail_execute};
    push @{$self->{dbh}{inserts}}, \@p;
    return 1;
  }
  sub finish  { }
}
{
  package MockStorage; sub new { my ($c, %a) = @_; bless { %a }, $c } sub dbh { $_[0]{dbh} }
  package MockSchema;  sub new { my ($c, %a) = @_; bless { %a }, $c } sub storage { $_[0]{storage} }
  package MockApp;     sub new { my ($c, %a) = @_; bless { %a }, $c } sub schema { $_[0]{schema} }
}
sub mock_app {
  my $dbh = MockDBH->new;
  my $app = MockApp->new(schema => MockSchema->new(storage => MockStorage->new(dbh => $dbh)));
  return ($app, $dbh);
}

# --- fixture comum: itens no shape real da API --------------------------
sub item {
  my (%p) = @_;
  return {
    exercicio => 2025, demonstrativo => 'RREO', periodo => 2, periodicidade => 'B',
    instituicao => 'Prefeitura Municipal de São Paulo - SP', cod_ibge => 3550308,
    uf => 'SP', anexo => $p{anexo} // 'RREO-Anexo 01', rotulo => 'Padrão', esfera => 'M',
    cod_conta => $p{cod_conta} // 'Impostos',
    conta     => $p{conta}     // 'Impostos',
    coluna    => $p{coluna},
    valor     => $p{valor},
    (defined $p{cod_ibge} ? (cod_ibge => $p{cod_ibge}) : ()),
  };
}

my @FIXTURE = (
  item(cod_conta => 'Impostos', coluna => 'PREVISÃO INICIAL',       valor => 1000),
  item(cod_conta => 'Impostos', coluna => 'PREVISÃO ATUALIZADA (a)', valor => 1200),
  item(cod_conta => 'Impostos', coluna => 'No Bimestre (b)',         valor => 300),
  item(cod_conta => 'Impostos', coluna => 'Até o Bimestre (c)',      valor => 900),
  item(cod_conta => 'Impostos', coluna => '% (b/a)',                 valor => 25),
  item(cod_conta => 'Impostos', coluna => 'SALDO (a-c)',             valor => 300),
  item(cod_conta => 'TransferenciasCorrentesDaUniaoEDeSuasEntidades',
       conta => 'Transferências da União e de suas Entidades',
       coluna => 'PREVISÃO ATUALIZADA (a)', valor => 8000),
  item(cod_conta => 'TransferenciasCorrentesDaUniaoEDeSuasEntidades',
       conta => 'Transferências da União e de suas Entidades',
       coluna => 'Até o Bimestre (c)', valor => 7500),
  # linha de DESPESA no mesmo retorno: sai pela coluna
  item(cod_conta => 'DespesasCorrentes', coluna => 'DOTAÇÃO ATUALIZADA (a)', valor => 5000),
  # linha de TOTAL: sai por não ser folha
  item(cod_conta => 'ReceitasExcetoIntraOrcamentarias',
       conta => 'RECEITAS (EXCETO INTRA-ORÇAMENTÁRIAS) (I)',
       coluna => 'Até o Bimestre (c)', valor => 999999),
  # MESMO cod_conta/coluna do Anexo 01, mas vindo do Anexo 04 (RPPS): sem o
  # filtro de anexo colidiria na PK e o ON CONFLICT ficaria à mercê da ordem.
  item(anexo => 'RREO-Anexo 04', cod_conta => 'Impostos',
       coluna => 'PREVISÃO ATUALIZADA (a)', valor => 777777),
);

# ---------------------------------------------------------------- 1-3
subtest 'mapeamento: coluna decide classificacao, folhas entram, totais nao' => sub {
  my $j = mk_job(sub { return {} });
  my $rows = $j->_map_receitas('3550308', 2025, \@FIXTURE, '2025-06-30');

  is(scalar @$rows, 4, '4 linhas (2 cod_conta x 2 classificações)');
  my %by = map { ($_->{coluna_receita} . '/' . $_->{classificacao}) => $_ } @$rows;

  my $imp_est = $by{'Impostos/estimativa'};
  ok($imp_est, 'Impostos/estimativa existe');
  is($imp_est->{valor}, 1200, 'estimativa vem da PREVISÃO ATUALIZADA (a), não da inicial');
  is($imp_est->{tipo_receita}, 'propria', 'Impostos -> propria');
  is($imp_est->{dt_snapshot}, '2025-06-30', 'dt_snapshot propagado');
  is($imp_est->{exercicio}, 2025, 'exercicio numérico');

  my $imp_real = $by{'Impostos/realizada'};
  ok($imp_real, 'Impostos/realizada existe');
  is($imp_real->{valor}, 900, 'realizada vem da coluna Até o Bimestre (c)');

  my $tra_est = $by{'TransferenciasCorrentesDaUniaoEDeSuasEntidades/estimativa'};
  is($tra_est->{tipo_receita}, 'transferencia', 'transferência da União -> transferencia');
  is($tra_est->{descricao_receita}, 'Transferências da União e de suas Entidades', 'descricao da conta');

  my $todos_valores = join ',', sort map { $_->{valor} } @$rows;
  unlike($todos_valores, qr/\b1000\b/, 'PREVISÃO INICIAL fora (colidiria na PK com a atualizada)');
  unlike($todos_valores, qr/\b300\b/,  'No Bimestre (b) fora (idem)');
  unlike($todos_valores, qr/\b25\b/,   'percentual fora');
  unlike($todos_valores, qr/\b5000\b/, 'linha de despesa fora');
  unlike($todos_valores, qr/999999/,   'total (ReceitasExcetoIntraOrcamentarias) fora');
  unlike($todos_valores, qr/777777/,   'linha do Anexo 04 fora (mesmo cod_conta/coluna — colidiria na PK)');
};

# ---------------------------------------------------------------- 4
subtest 'count==0 com HTTP 200 NAO e sucesso (armadilha #165)' => sub {
  my $j = mk_job(sub {
    my ($url, $form) = @_;
    return { items => [], count => 0, hasMore => 0, limit => $form->{limit}, offset => $form->{offset} };
  });
  my $err = eval { $j->_fetch_rreo(id_ente => '3550308', exercicio => 2025, nr_periodo => 2); 1 };
  ok(!$err, '0 itens morre');
  like($@ // '', qr/0 itens/, 'mensagem denuncia o falso sucesso');
};

# ---------------------------------------------------------------- 5
subtest 'paginação por hasMore: count e pagina (limit=2 => count=2)' => sub {
  my $j = mk_job(sub {
    my ($url, $form) = @_;
    my $off = $form->{offset} // 0;
    if ($off == 0) {
      return { items => [ item(cod_conta => 'Impostos', coluna => 'PREVISÃO ATUALIZADA (a)', valor => 10) ],
               count => 1, hasMore => 1, limit => 1000, offset => 0 };
    }
    return { items => [ item(cod_conta => 'Taxas', coluna => 'Até o Bimestre (c)', valor => 20) ],
             count => 1, hasMore => 0, limit => 1000, offset => 1000 };
  });
  my $rows = $j->_fetch_rreo(id_ente => '3550308', exercicio => 2025, nr_periodo => 2);
  is(scalar @$rows, 2, 'duas páginas consumidas');
  my @offsets = map { $_->[1]{offset} } @{$j->ua->{calls}};
  is_deeply(\@offsets, [0, 1000], 'offset avança 0 -> 1000 (mesmo com count por página)');
};

# ---------------------------------------------------------------- 6
subtest 'HTTP != 200 morre (após retries, max_retries=0 no teste)' => sub {
  my $j = mk_job(sub { return ({}, 500) });
  my $err = eval { $j->_fetch_rreo(id_ente => '3550308', exercicio => 2025, nr_periodo => 2); 1 };
  ok(!$err, 'HTTP 500 morre');
  like($@ // '', qr/HTTP 500/, 'mensagem com o código');
};

# ---------------------------------------------------------------- 7
subtest '/entes: cache local, so esfera M, filtro por uf no run' => sub {
  my $call_count = 0;
  my $j = mk_job(sub {
    $call_count++;
    return {
      items => [
        { cod_ibge => 1111111, ente => 'A-SP', esfera => 'M', uf => 'SP' },
        { cod_ibge => 2222222, ente => 'B-SP-estado', esfera => 'E', uf => 'SP' },
        { cod_ibge => 3333333, ente => 'C-RJ', esfera => 'M', uf => 'RJ' },
        { cod_ibge => 4444444, ente => 'D-SP', esfera => 'M', uf => 'SP' },
      ],
      count => 4, hasMore => 0, limit => 1000, offset => 0,
    };
  });

  my $entes = $j->_fetch_entes;
  is(scalar @$entes, 3, 'só esfera M entra no cache');
  is($call_count, 1, 'primeira chamada vai à rede');
  ok(-f $j->entes_cache_file, 'cache gravado');

  $j->_fetch_entes;
  is($call_count, 1, 'segunda chamada vem do cache (sem rede)');

  # o run() com uf filtra o cache e itera
  my ($app, $dbh) = mock_app;
  my $j2 = mk_job(sub {
    my ($url, $form) = @_;
    if ($url =~ m{/entes$}) {
      return { items => [
        { cod_ibge => 1111111, esfera => 'M', uf => 'SP' },
        { cod_ibge => 3333333, esfera => 'M', uf => 'RJ' },
      ], count => 2, hasMore => 0, limit => 1000, offset => 0 };
    }
    # /rreo
    return { items => [ item(cod_ibge => $form->{id_ente}, cod_conta => 'Impostos',
                             coluna => 'Até o Bimestre (c)', valor => 7) ],
             count => 1, hasMore => 0, limit => 1000, offset => 0 };
  }, app => $app, entes_cache_file => path(tempdir(CLEANUP => 1))->child('entes.json'));

  my $total = $j2->run({ uf => 'SP', max_municipios => 5 });
  is($total, 1, '1 município de SP carregado (RJ filtrado)');
  is(scalar @{$dbh->{inserts}}, 1, '1 INSERT emitido');
  is($dbh->{inserts}[0][0], '1111111', 'codigo_ibge do município iterado');
};

# ---------------------------------------------------------------- 8
subtest 'load: SQL com ON CONFLICT na PK exata e dt_snapshot nos params' => sub {
  my ($app, $dbh) = mock_app;
  my $j = $JOB->new(log => Mojo::Log->new(level => 'fatal'), app => $app);

  my $rows = $j->_map_receitas('3550308', 2025, \@FIXTURE, '2025-06-30');
  my $loaded = $j->_load_receita($rows);
  is($loaded, 4, '4 linhas carregadas');
  my $sql = $dbh->{stmts}[0];
  like($sql, qr/ON CONFLICT/, 'upsert idempotente');
  like($sql, qr/classificacao, dt_snapshot/, 'PK exata no ON CONFLICT');
  like($sql, qr/DO UPDATE SET valor/, 'reexecução auto-corrige o valor');
  is(scalar @{$dbh->{inserts}}, 4, '4 executes');
  is($dbh->{inserts}[0][7], '2025-06-30', 'dt_snapshot no último parâmetro');
  is($dbh->{inserts}[0][6], 'estimativa', 'classificacao no penúltimo');
};

# ---------------------------------------------------------------- 8b
subtest 'load: erro real do banco sobrevive ao rollback (não some)' => sub {
  # Regressão: `eval { $dbh->rollback }` limpa o $@, e um `die "...$@"`
  # logo a seguir emitiria mensagem VAZIA — medido no ambiente produto,
  # onde a falha saiu como "falhou:  at line 357" e era indiagnosticável.
  my $dbh = MockDBH->new(fail_execute => 1);
  my $app = MockApp->new(schema => MockSchema->new(storage => MockStorage->new(dbh => $dbh)));
  my $j  = $JOB->new(log => Mojo::Log->new(level => 'fatal'), app => $app);
  my $rows = $j->_map_receitas('3550308', 2025, \@FIXTURE, '2025-06-30');

  my $died = !eval { $j->_load_receita($rows); 1 };
  ok($died, 'a falha propaga como exceção');
  like($@, qr/exec exploded/, 'a MENSAGEM ORIGINAL chega ao chamador');
  ok($dbh->{rolled}, 'rollback executado antes do die');
  is($dbh->{commits} ? scalar @{$dbh->{commits}} : 0, 0, 'sem commit parcial');
};

# ---------------------------------------------------------------- 9
subtest 'idempotência com BD real: reexecutar não viola a PK' => sub {
  plan skip_all => 'sem EDUMAPS_DB_HOST: subteste exige base intencional (nunca o default ubatexu.lan do edu_maps.conf — armadilha dos dois contentores)'
    unless $ENV{EDUMAPS_DB_HOST};
  my $has_table = eval {
    require EduMaps::Ingestion::App;
    my $app  = EduMaps::Ingestion::App->new;
    my $dbh  = $app->schema->storage->dbh;
    $dbh->selectrow_array("SELECT to_regclass('clean.malha_municipio')")
      && $dbh->selectrow_array("SELECT to_regclass('clean.siconfi_receita')");
  };
  plan skip_all => 'sem BD disponível (EDUMAPS_DB_* apontando para um Postgres com o schema)' unless $has_table;

  my $app = EduMaps::Ingestion::App->new;
  my $dbh = $app->schema->storage->dbh;
  my $cod = $dbh->selectrow_array('SELECT codigo_ibge FROM clean.malha_municipio LIMIT 1');
  plan skip_all => 'malha vazia' unless $cod;

  my $DT = '2099-01-01';
  my $j = $JOB->new(log => Mojo::Log->new(level => 'fatal'), app => $app);
  my $rows = [
    { codigo_ibge => $cod, exercicio => 2025, tipo_receita => 'propria',
      coluna_receita => 'Impostos', descricao_receita => 'TESTE', valor => 1,
      classificacao => 'estimativa', dt_snapshot => $DT },
    { codigo_ibge => $cod, exercicio => 2025, tipo_receita => 'propria',
      coluna_receita => 'Impostos', descricao_receita => 'TESTE', valor => 2,
      classificacao => 'realizada', dt_snapshot => $DT },
  ];

  my $warn = '';
  local $SIG{__WARN__} = sub { $warn .= $_[0] };
  my $first  = $j->_load_receita($rows);
  my $second = $j->_load_receita($rows);
  my $count  = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.siconfi_receita WHERE dt_snapshot = ?', {}, $DT);

  is($first, 2, 'primeira carga insere 2');
  is($second, 2, 'reexecução processa 2 sem violar a PK');
  is($count, 2, 'mesma PK após reexecutar (ON CONFLICT, sem duplicar)');
  unlike($warn, qr/duplicate/i, 'sem erro de PK');

  $dbh->do('DELETE FROM clean.siconfi_receita WHERE dt_snapshot = ?', {}, $DT);
};

# ---------------------------------------------------------------- 0
subtest 'instância: metadados do job' => sub {
  my $j = $JOB->new(log => Mojo::Log->new);
  is($j->job_name, 'SICONFI', 'job_name');
  is($j->schedule, 'monthly', 'schedule mensal');
  like($j->description, qr/RREO/, 'descrição menciona RREO');
};

done_testing();