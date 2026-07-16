use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Utils qw(run_similarity_job cleanup_job);

my $t   = Test::Mojo->new('EduMaps');
my $sch = $t->app->schema;
my $tag = '[integration] inject_similarity_relation_from_job';

# --------------------------------------------------------------------------
# Fixture: mesma ideia de inject_test.t (Campinas, dataset menor e mais
# rapido que Rio de Janeiro), mas para similaridade. De proposito NAO
# incluimos a coluna 'escola' (nome, texto livre) - ver aviso identico em
# similarity.t sobre select_mixed_features() tratar qualquer coluna
# character como feature categorica.
# --------------------------------------------------------------------------
my $table_name = 'test_similarity_campinas';
my $params     = { no_municipio => 'Campinas' };

my $source_rs = $sch->resultset('CensoEscolas')->search_rs($params)
  ->join('docente')->join('matricula')
  ->columns(
    [
      {codigo => 'me.co_entidade'},
      {total_docentes_basico => 'docente.qt_doc_bas'},
      {total_docentes_medio => 'docente.qt_doc_med'},
      {matriculas_fundamental => 'matricula.qt_mat_bas'},
      {matriculas_ensino_medio => 'matricula.qt_mat_med'},
    ]
  )->order_by({ -desc => 'docente.qt_doc_bas' });

my $expected_schools_count = $source_rs->count;

subtest qq/
$tag <preparando a tabela de staging>
  - garante que ha escolas suficientes em Campinas para o teste fazer sentido
/ => sub {
  ok $expected_schools_count >= 3,
    "encontrou pelo menos 3 escolas em Campinas ($expected_schools_count encontradas)";
};

$source_rs->save_in_table(
  tbl_name  => $table_name,
  schema    => 'staging',
  temporary => 0,
);

# Um co_entidade de referencia, usado nas consultas abaixo
my ($sample_id) = $sch->storage->dbh->selectrow_array(
  "SELECT co_entidade FROM staging.$table_name ORDER BY co_entidade LIMIT 1"
);

# --------------------------------------------------------------------------
# Aplica a similaridade (gower, mesmo caminho testado em similarity.t)
# --------------------------------------------------------------------------
my $job = run_similarity_job($t, {
  id_column  => 'co_entidade',
  table_name => $table_name,
  schema     => 'staging',
  metric     => 'gower',
});

subtest qq/
$tag <similaridade>
  - job de similaridade finaliza com sucesso para a tabela de Campinas
/ => sub {
  is $job->info->{state}, 'finished', 'job finalizado com sucesso'
    or diag "resultado: " . ($job->info->{result} // '');
};

# --------------------------------------------------------------------------
# Injeta as relacoes dinamicas direto a partir do resultado do job
# --------------------------------------------------------------------------
subtest qq/
$tag <injecao da relacao>
  - inject_similarity_relation_from_job registra a classe e as duas
    relacoes (as_1 \/ as_2) sem erro
/ => sub {
  my $pairs_class = $sch->inject_similarity_relation_from_job(
    $job->info->{result},
    'CensoEscolas',
  );

  ok $pairs_class, 'inject_similarity_relation_from_job retornou uma classe';
  is $pairs_class, 'EduMaps::Schema::Result::SimilarityPair',
    'nome da classe de similarity_pairs e o esperado';
  ok( (grep { $_ eq 'SimilarityPair' } $sch->sources),
    'a classe SimilarityPair aparece entre os sources do schema' );

  my @rels = $sch->source('CensoEscolas')->relationships;
  ok( (grep { $_ eq 'similarity_pairs_as_1' } @rels),
    'relacao similarity_pairs_as_1 foi injetada em CensoEscolas' );
  ok( (grep { $_ eq 'similarity_pairs_as_2' } @rels),
    'relacao similarity_pairs_as_2 foi injetada em CensoEscolas' );

  # idempotencia: chamar de novo nao deve duplicar nem falhar
  my $pairs_class_again = $sch->inject_similarity_relation_from_job(
    $job->info->{result},
    'CensoEscolas',
  );
  is $pairs_class_again, $pairs_class, 'segunda chamada e idempotente';
};

# --------------------------------------------------------------------------
# Confirma que, para uma escola de referencia, a soma dos dois lados da
# relacao (as_1 + as_2) bate com o total esperado: em um grafo completo de
# n entidades, cada uma aparece em exatamente n-1 pares (kmeans/gower gera
# TODOS os pares, ver pairs_from_distance em similarity_utils.R).
# --------------------------------------------------------------------------
subtest qq/
$tag <consulta via relacao injetada - acesso direto a uma linha>
  - a escola de referencia tem exatamente n-1 pares, somando os dois lados
/ => sub {
  my $row = $sch->resultset('CensoEscolas')
    ->search({ 'me.co_entidade' => $sample_id })
    ->first;

  ok $row, "encontrou a escola de referencia (co_entidade=$sample_id)";

  # acesso direto numa linha ja carregada - deve usar a forma "join-free"
  # do coderef (self_result_object), sem precisar de JOIN
  my $count_as_1 = $row->similarity_pairs_as_1->count;
  my $count_as_2 = $row->similarity_pairs_as_2->count;

  is $count_as_1 + $count_as_2, $expected_schools_count - 1,
    "soma dos dois lados bate com n-1 ($expected_schools_count - 1 escolas)";
};

# --------------------------------------------------------------------------
# Confirma que o filtro por target_table realmente restringe os resultados
# (regressao: se o coderef ignorasse target_table/metric, qualquer relacao
# injetada para qualquer tabela devolveria TODOS os pares do schema inteiro)
# --------------------------------------------------------------------------
subtest qq/
$tag <regressao: filtro de target_table e respeitado>
  - uma relacao injetada para uma tabela inexistente nao traz nenhum par
/ => sub {
  $sch->inject_similarity_relation({
    target_source => 'CensoEscolas',
    id_column     => 'co_entidade',
    target_table  => 'staging.tabela_que_nao_existe_para_este_teste',
    metric        => 'gower',
    relation_name => 'similarity_pairs_fake',
    # este subteste so quer verificar o filtro nas relacoes as_1/as_2 -
    # nao precisa (e nao deve) tentar instalar top_similars de novo, ja
    # que isso colidiria com o method_name default 'top_similars' ja
    # registrado no subteste anterior para staging.$table_name (ver
    # subteste de regressao de colisao mais abaixo, que testa isso de
    # proposito)
    install_top_similars => 0,
  });

  my $row = $sch->resultset('CensoEscolas')
    ->search({ 'me.co_entidade' => $sample_id })
    ->first;

  is $row->similarity_pairs_fake_as_1->count, 0,
    'relacao para target_table inexistente nao traz pares (lado 1)';
  is $row->similarity_pairs_fake_as_2->count, 0,
    'relacao para target_table inexistente nao traz pares (lado 2)';
};

# --------------------------------------------------------------------------
# Metodo de conveniencia similar_entities(): junta os dois lados do par e
# resolve qual e a "outra" entidade, ordenado por similaridade decrescente
# --------------------------------------------------------------------------
subtest qq/
$tag <similar_entities>
  - devolve as escolas mais similares a escola de referencia
/ => sub {
  my $target_table = "staging.$table_name";

  my $similar = $sch->similar_entities(
    target_table => $target_table,
    metric       => 'gower',
    entity_id    => $sample_id,
    limit        => 3,
  );

  ok scalar(@$similar) > 0, 'similar_entities devolveu pelo menos um resultado';
  ok scalar(@$similar) <= 3, 'similar_entities respeita o limit pedido';

  ok( (! grep { $_->{entity_id} eq $sample_id } @$similar),
    'a propria escola de referencia nao aparece na lista de similares' );

  # ordenado por similaridade decrescente
  my @similarities = map { $_->{similarity} } @$similar;
  my @sorted = sort { $b <=> $a } @similarities;
  is \@similarities, \@sorted, 'resultados vem ordenados por similaridade decrescente';

  for my $entry (@$similar) {
    ok exists $entry->{entity_id}, 'cada resultado tem entity_id';
    ok exists $entry->{similarity}, 'cada resultado tem similarity';
    ok exists $entry->{distance}, 'cada resultado tem distance';
    ok $entry->{similarity} > 0 && $entry->{similarity} <= 1,
      'similarity esta no intervalo (0, 1]';
  }
};

# --------------------------------------------------------------------------
# top_similars(): metodo de conveniencia instalado direto na classe Result
# de CensoEscolas por inject_similarity_relation_from_job. Deve ser
# equivalente a chamar $sch->similar_entities(...) manualmente, so que sem
# o chamador precisar saber target_table/metric/id_column.
# --------------------------------------------------------------------------
subtest qq/
$tag <top_similars>
  - \$escola->top_similars(\$n) e equivalente a similar_entities(...)
/ => sub {
  my $escola = $sch->resultset('CensoEscolas')
    ->search({ 'me.co_entidade' => $sample_id })
    ->first;

  ok $escola, 'encontrou a escola de referencia via resultset';

  my $top3 = $escola->top_similars(3);

  ok scalar(@$top3) > 0, 'top_similars devolveu pelo menos um resultado';
  ok scalar(@$top3) <= 3, 'top_similars respeita o limit pedido';

  ok( (! grep { $_->{entity_id} eq $sample_id } @$top3),
    'a propria escola de referencia nao aparece em top_similars' );

  my @similarities = map { $_->{similarity} } @$top3;
  my @sorted = sort { $b <=> $a } @similarities;
  is \@similarities, \@sorted, 'top_similars vem ordenado por similaridade decrescente';

  # top_similars($n) deve ser equivalente a chamar similar_entities(...) na
  # mao com os mesmos target_table/metric/entity_id/limit
  my $via_schema = $sch->similar_entities(
    target_table => "staging.$table_name",
    metric       => 'gower',
    entity_id    => $sample_id,
    limit        => 3,
  );
  is $top3, $via_schema,
    'top_similars(3) e equivalente a similar_entities(...) chamado manualmente';

  # sem argumento, usa o default (10)
  my $default_top = $escola->top_similars;
  ok scalar(@$default_top) <= 10, 'sem argumento, top_similars usa o default (10)';
};

# --------------------------------------------------------------------------
# Regressao: reinjetar o mesmo method_name ('top_similars', o default) para
# um target_table diferente deve falhar de forma clara, em vez de
# silenciosamente sobrescrever o metodo ja instalado (o que faria
# $escola->top_similars(10) mudar de comportamento sem aviso para quem ja
# estava usando o metodo anterior).
# --------------------------------------------------------------------------
subtest qq/
$tag <regressao: colisao de method_name e detectada>
  - reinjetar top_similars para um target_table diferente sem trocar
    method_name falha com mensagem clara, sem sobrescrever o metodo original
/ => sub {
  my $ok = eval {
    $sch->inject_similarity_relation({
      target_source => 'CensoEscolas',
      id_column     => 'co_entidade',
      target_table  => 'staging.outra_tabela_qualquer',
      metric        => 'gower',
      relation_name => 'similarity_pairs_outra',
      # method_name omitido de proposito - cai no default 'top_similars',
      # que ja esta registrado para staging.$table_name
    });
    1;
  };
  my $error = $@;

  ok !$ok, 'a segunda injecao com o mesmo method_name (default) falha';
  like $error, qr/ja foi instalado/, 'mensagem de erro explica a colisao de method_name';

  # confirma que o metodo original nao foi sobrescrito nem quebrado
  my $escola = $sch->resultset('CensoEscolas')
    ->search({ 'me.co_entidade' => $sample_id })
    ->first;
  my $still_working = $escola->top_similars(1);
  is scalar(@$still_working), 1,
    'top_similars original continua funcionando normalmente apos a tentativa de colisao';
};

# --------------------------------------------------------------------------
# Limpeza
# --------------------------------------------------------------------------
cleanup_job($t, $job);

$sch->storage->dbh->do(
  'DELETE FROM analytics.similarity_pairs WHERE target_table = ?',
  undef, "staging.$table_name"
);
$sch->storage->dbh->do("DROP TABLE IF EXISTS staging.$table_name");

done_testing;
