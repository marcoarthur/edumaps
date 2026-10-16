use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Schema;

# Arealização socioeconômica do entorno da escola (#137, bloco B):
# clean.escola_entorno_socioeconomico + clean.refresh_escola_entorno_socioeconomico().
# Integração real com o banco local (rode com EDUMAPS_DB_HOST=127.0.0.1).
#
# Dados sintéticos são plantados numa área do Atlântico (lon -30, lat -15), onde
# não há setor censitário real (a malha do IBGE cobre só terra) — logo o teste é
# determinístico tanto na base local (sem setores) quanto no produto (com
# setores). Tudo corre dentro de uma transação e é revertido no fim.

my $sch = eval { EduMaps::Schema->go };
skip_all 'sem banco disponível (rode com EDUMAPS_DB_HOST=127.0.0.1)' unless $sch;

my $dbh = $sch->storage->dbh;

my $has_fn = $dbh->selectrow_array(
  "SELECT to_regprocedure('clean.refresh_escola_entorno_socioeconomico(integer[],bigint[])')"
);
skip_all 'clean.refresh_escola_entorno_socioeconomico ausente (migration não aplicada)'
  unless $has_fn;

# Município real só para satisfazer a FK de clean.malha_setor_censitario.
my $codigo_ibge = $dbh->selectrow_array('SELECT codigo_ibge FROM clean.malha_municipio LIMIT 1');
skip_all 'sem município em clean.malha_municipio' unless $codigo_ibge;

my $CO  = 99999999999;
my $ANO = 2025;

# buffer de teste: 0,01° × 0,01° no Atlântico, ~1,23 km².
my $buffer = q{ST_SetSRID(ST_MakeEnvelope(-30.0, -15.0, -29.99, -14.99, 4674), 4674)};

$dbh->begin_work;

$dbh->do("INSERT INTO clean.escola_influencia (co_entidade, nu_ano_censo, tier, raio_m, geom)
          VALUES ($CO, $ANO, 'buffer', 500, $buffer)");

# dois setores que dividem o buffer ao meio (pesos iguais).
$dbh->do(qq{
  INSERT INTO clean.malha_setor_censitario
    (codigo_setor, codigo_ibge, nome_municipio, sigla_uf, situacao_setor, geometry) VALUES
    ('TSTENTORNO01A', '$codigo_ibge', 'Teste', 'RO', 'urbana',
     ST_Multi(ST_SetSRID(ST_MakeEnvelope(-30.0, -15.0, -29.995, -14.99, 4674), 4674))),
    ('TSTENTORNO01B', '$codigo_ibge', 'Teste', 'RO', 'urbana',
     ST_Multi(ST_SetSRID(ST_MakeEnvelope(-29.995, -15.0, -29.99, -14.99, 4674), 4674)))
});

# A: pct_sem_instrucao 0,25 · pct_fund_incomp 0,15 · médio+ 0,50 · preto/pardo 0,50 · renda 1000
# B: pct_sem_instrucao 0,05 · pct_fund_incomp 0,05 · médio+ 0,80 · preto/pardo 0,25 · renda 3000
$dbh->do(q{
  INSERT INTO clean.censo2022_setor
    (codigo_setor, codigo_ibge, pop_total, rend_per_capita,
     esc_sem_instrucao, esc_fund_incomp, esc_fund_comp, esc_med_incomp, esc_med_comp,
     esc_sup_incomp, esc_sup_comp,
     cor_branca, cor_preta, cor_amarela, cor_parda, cor_indigena, cor_sem_decl,
     supressao_celula_pequena) VALUES
    ('TSTENTORNO01A', ?, 400, 1000, 50, 30, 20, 0, 100, 0, 0, 100, 20, 0, 80, 0, 0, false),
    ('TSTENTORNO01B', ?, 1600, 3000, 10, 10, 20, 0, 160, 0, 0, 300, 0, 0, 100, 0, 0, false)
}, {}, $codigo_ibge, $codigo_ibge);

sub refresh {
  $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, @_
  );
}

my $row = sub {
  $dbh->selectrow_hashref(
    'SELECT * FROM clean.escola_entorno_socioeconomico WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500',
    { Slice => {} }, $CO, $ANO
  );
};

subtest 'arealiza com peso = área (média ponderada dos setores)' => sub {
  my $n = $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', "{$CO}"
  );
  is $n, 1, 'uma linha materializada';

  my $r = $dbh->selectrow_hashref(q{
    SELECT n_setores, n_setores_suprimidos,
           cobertura_pct::float8 AS cobertura_pct,
           pop_total::float8 AS pop_total,
           renda_per_capita::float8 AS renda_per_capita,
           pct_sem_instrucao::float8 AS pct_sem_instrucao,
           pct_fund_incomp::float8 AS pct_fund_incomp,
           pct_medio_mais::float8 AS pct_medio_mais,
           pct_preto_pardo::float8 AS pct_preto_pardo
      FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $CO, $ANO);

  is $r->{n_setores}, 2, 'dois setores intersectam o buffer';
  is $r->{n_setores_suprimidos}, 0, 'nenhum suprimido';
  is $r->{cobertura_pct}, 1, 'cobertura integral do buffer';
  is $r->{renda_per_capita}, 2000, 'renda = média ponderada (pesos iguais)';
  is $r->{pct_sem_instrucao}, 0.15,   'pct sem instrução = média (0,25/0,05)';
  is $r->{pct_fund_incomp}, 0.10,     'pct fundamental incompleto = média';
  is $r->{pct_medio_mais}, 0.65,      'pct médio+ = média (0,50/0,80)';
  is $r->{pct_preto_pardo}, 0.375,    'pct preto/pardo = média (0,50/0,25)';
  is $r->{pop_total}, 2000,           'população estimada (400 + 1600)';
};

subtest 'idempotente: o segundo refresh não duplica (UPSERT)' => sub {
  $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', "{$CO}"
  );
  my $count = $dbh->selectrow_array(q{
    SELECT count(*) FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $CO, $ANO);
  is $count, 1, 'continua com uma linha';
};

subtest '#154 vazio != zero: setor suprimido fica fora do cálculo' => sub {
  $dbh->do("UPDATE clean.censo2022_setor SET supressao_celula_pequena = true
             WHERE codigo_setor = 'TSTENTORNO01B'");

  $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', "{$CO}"
  );

  my $r = $dbh->selectrow_hashref(q{
    SELECT n_setores, n_setores_suprimidos,
           cobertura_pct::float8 AS cobertura_pct,
           renda_per_capita::float8 AS renda_per_capita,
           pct_sem_instrucao::float8 AS pct_sem_instrucao,
           pct_preto_pardo::float8 AS pct_preto_pardo
      FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $CO, $ANO);

  is $r->{n_setores}, 2, 'os dois setores intersectam';
  is $r->{n_setores_suprimidos}, 1, 'um suprimido (registrado, não descartado)';
  is $r->{cobertura_pct}, 0.5, 'cobertura cai para a metade';
  is $r->{renda_per_capita}, 1000, 'renda é só do setor com dado (não virou zero)';
  is $r->{pct_sem_instrucao}, 0.25, 'pct sem instrução só do setor com dado';
  is $r->{pct_preto_pardo}, 0.5, 'pct preto/pardo só do setor com dado';
};

subtest 'sem nenhum setor com dado: componentes NULL, cobertura 0' => sub {
  $dbh->do("UPDATE clean.censo2022_setor SET supressao_celula_pequena = true
             WHERE codigo_setor LIKE 'TSTENTORNO01%'");

  $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', "{$CO}"
  );

  my $r = $dbh->selectrow_hashref(q{
    SELECT n_setores_suprimidos,
           cobertura_pct::float8 AS cobertura_pct,
           renda_per_capita, pct_sem_instrucao, pct_preto_pardo, densidade_pop_km2
      FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $CO, $ANO);

  is $r->{n_setores_suprimidos}, 2, 'todos suprimidos';
  is $r->{cobertura_pct}, 0, 'cobertura zero (sem dado)';
  is $r->{renda_per_capita}, undef, 'renda NULL (não calculada, não 0)';
  is $r->{pct_sem_instrucao}, undef, 'pct sem instrução NULL';
  is $r->{pct_preto_pardo}, undef, 'pct preto/pardo NULL';
  is $r->{densidade_pop_km2}, undef, 'densidade NULL';
};

subtest 'escola sem setor intersectado: nenhuma linha' => sub {
  $dbh->do("INSERT INTO clean.escola_influencia (co_entidade, nu_ano_censo, tier, raio_m, geom)
            VALUES (424242, $ANO, 'buffer', 500,
                    ST_SetSRID(ST_MakeEnvelope(-31.0, -16.0, -30.99, -15.99, 4674), 4674))");
  my $n = $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', '{424242}'
  );
  is $n, 0, 'nada materializado (ausência de setor = sem linha)';
  my $count = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.escola_entorno_socioeconomico WHERE co_entidade = 424242'
  );
  is $count, 0, 'sem linha para a escola';
};

subtest 'filtro por escola limita o refresh' => sub {
  my $n = $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500,1000}', '{' . ($CO + 1) . '}'
  );
  is $n, 0, 'escola inexistente não materializa nada';
};

subtest 'raio inválido é rejeitado' => sub {
  my $ok = eval {
    $dbh->selectrow_array(
      'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
      {}, '{0}', "{$CO}"
    );
    1;
  };
  ok !$ok, 'raio 0 levanta exceção';
};

$dbh->rollback;

done_testing;
