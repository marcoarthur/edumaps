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

# Todas as colunas-fonte da arealização. "Célula suprimida" no Censo = NULL na
# coluna da variável (o loader grava NULL), com supressao_celula_pequena = true
# no setor só como proveniência — a ausência é decidida por coluna, não pelo
# flag do setor.
my @COLS_FONTE = qw(
  pop_total rend_per_capita
  esc_sem_instrucao esc_fund_incomp esc_fund_comp
  esc_med_incomp esc_med_comp esc_sup_incomp esc_sup_comp
  cor_branca cor_preta cor_amarela cor_parda cor_indigena
  alf_sabe_15mais alf_nao_sabe_15mais
  dom_agua_rede dom_agua_poco_profundo dom_agua_poco_raso dom_agua_nascente
  dom_agua_carro_pipa dom_agua_chuva dom_agua_rio dom_agua_outra
  dom_esgoto_rede dom_esgoto_fossa_septica_rede dom_esgoto_fossa_septica
  dom_esgoto_fossa_rudimentar dom_esgoto_vala dom_esgoto_rio
  dom_esgoto_outra dom_esgoto_inexistente
  dom_lixo_coletado dom_lixo_cacamba dom_lixo_queimado dom_lixo_enterrado
  dom_lixo_jogado dom_lixo_outro
  dom_banheiro_exclusivo dom_sem_banheiro
);
my $SET_NULL = join ', ', map { "$_ = NULL" } @COLS_FONTE;

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
#
# Bloco B v1.1 (instrução + saneamento), proporções por setor:
#   A: analfabeto 5/75 · água sem rede 20/100 · esgoto inadequado 50/100
#      lixo inadequado 10/100 · sem banheiro 10/100
#   B: analfabeto 1/91 · água sem rede 0 · esgoto inadequado 10/100
#      lixo inadequado 0 · sem banheiro 0
$dbh->do(q{
  INSERT INTO clean.censo2022_setor
    (codigo_setor, codigo_ibge, pop_total, rend_per_capita,
     esc_sem_instrucao, esc_fund_incomp, esc_fund_comp, esc_med_incomp, esc_med_comp,
     esc_sup_incomp, esc_sup_comp,
     cor_branca, cor_preta, cor_amarela, cor_parda, cor_indigena, cor_sem_decl,
     alf_sabe_15mais, alf_nao_sabe_15mais,
     dom_agua_rede, dom_agua_poco_profundo, dom_agua_poco_raso, dom_agua_nascente,
     dom_agua_carro_pipa, dom_agua_chuva, dom_agua_rio, dom_agua_outra,
     dom_esgoto_rede, dom_esgoto_fossa_septica_rede, dom_esgoto_fossa_septica,
     dom_esgoto_fossa_rudimentar, dom_esgoto_vala, dom_esgoto_rio,
     dom_esgoto_outra, dom_esgoto_inexistente,
     dom_lixo_coletado, dom_lixo_cacamba, dom_lixo_queimado, dom_lixo_enterrado,
     dom_lixo_jogado, dom_lixo_outro,
     dom_banheiro_exclusivo, dom_sem_banheiro,
     supressao_celula_pequena) VALUES
    ('TSTENTORNO01A', ?, 400, 1000, 50, 30, 20, 0, 100, 0, 0, 100, 20, 0, 80, 0, 0,
     70, 5,
     80, 0, 0, 20, 0, 0, 0, 0,
     50, 0, 0, 30, 20, 0, 0, 0,
     90, 0, 10, 0, 0, 0,
     90, 10,
     false),
    ('TSTENTORNO01B', ?, 1600, 3000, 10, 10, 20, 0, 160, 0, 0, 300, 0, 0, 100, 0, 0,
     90, 1,
     100, 0, 0, 0, 0, 0, 0, 0,
     90, 0, 0, 10, 0, 0, 0, 0,
     100, 0, 0, 0, 0, 0,
     100, 0,
     false)
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
           pct_preto_pardo::float8 AS pct_preto_pardo,
           pct_analfabeto::float8 AS pct_analfabeto,
           pct_agua_sem_rede::float8 AS pct_agua_sem_rede,
           pct_esgoto_inadequado::float8 AS pct_esgoto_inadequado,
           pct_lixo_inadequado::float8 AS pct_lixo_inadequado,
           pct_sem_banheiro::float8 AS pct_sem_banheiro,
           versao
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

  # bloco B v1.1: instrução (analfabetismo) + saneamento (esgoto/água/lixo/banheiro)
  is $r->{pct_analfabeto}, 0.0388,    'pct analfabeto = média (5/75 e 1/91)';
  is $r->{pct_agua_sem_rede}, 0.1,    'pct água sem rede = média (0,20 e 0)';
  is $r->{pct_esgoto_inadequado}, 0.3, 'pct esgoto inadequado = média (0,50 e 0,10)';
  is $r->{pct_lixo_inadequado}, 0.05, 'pct lixo inadequado = média (0,10 e 0)';
  is $r->{pct_sem_banheiro}, 0.05,    'pct sem banheiro = média (0,10 e 0)';
  is $r->{versao}, 'ivet-v1.1',       'versão da fórmula carimbada';
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

subtest '#154 vazio != zero: célula suprimida (NULL) fica fora do cálculo' => sub {
  # B vira célula suprimida: colunas-fonte NULL + flag do setor (proveniência).
  $dbh->do(qq{UPDATE clean.censo2022_setor
                 SET supressao_celula_pequena = true, $SET_NULL
               WHERE codigo_setor = 'TSTENTORNO01B'});

  $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', "{$CO}"
  );

  my $r = $dbh->selectrow_hashref(q{
    SELECT n_setores, n_setores_suprimidos,
           cobertura_pct::float8 AS cobertura_pct,
           renda_per_capita::float8 AS renda_per_capita,
           pct_sem_instrucao::float8 AS pct_sem_instrucao,
           pct_preto_pardo::float8 AS pct_preto_pardo,
           pct_analfabeto::float8 AS pct_analfabeto,
           pct_agua_sem_rede::float8 AS pct_agua_sem_rede,
           pct_esgoto_inadequado::float8 AS pct_esgoto_inadequado
      FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $CO, $ANO);

  is $r->{n_setores}, 2, 'os dois setores intersectam';
  is $r->{n_setores_suprimidos}, 1, 'um suprimido (registrado, não descartado)';
  is $r->{cobertura_pct}, 0.5, 'cobertura cai para a metade';
  is $r->{renda_per_capita}, 1000, 'renda é só do setor com dado (não virou zero)';
  is $r->{pct_sem_instrucao}, 0.25, 'pct sem instrução só do setor com dado';
  is $r->{pct_preto_pardo}, 0.5, 'pct preto/pardo só do setor com dado';
  is $r->{pct_analfabeto}, 0.0667, 'analfabetismo só do setor com dado (5/75)';
  is $r->{pct_agua_sem_rede}, 0.2, 'água sem rede só do setor com dado (20/100)';
  is $r->{pct_esgoto_inadequado}, 0.5, 'esgoto inadequado só do setor com dado (50/100)';
};

subtest 'sem nenhum setor com dado: componentes NULL, cobertura 0' => sub {
  $dbh->do(qq{UPDATE clean.censo2022_setor
                 SET supressao_celula_pequena = true, $SET_NULL
               WHERE codigo_setor LIKE 'TSTENTORNO01%'});

  $dbh->selectrow_array(
    'SELECT clean.refresh_escola_entorno_socioeconomico(?::integer[], ?::bigint[])',
    {}, '{500}', "{$CO}"
  );

  my $r = $dbh->selectrow_hashref(q{
    SELECT n_setores_suprimidos,
           cobertura_pct::float8 AS cobertura_pct,
           renda_per_capita, pct_sem_instrucao, pct_preto_pardo, densidade_pop_km2,
           pct_analfabeto, pct_agua_sem_rede, pct_esgoto_inadequado,
           pct_lixo_inadequado, pct_sem_banheiro
      FROM clean.escola_entorno_socioeconomico
     WHERE co_entidade = ? AND nu_ano_censo = ? AND raio_m = 500
  }, {}, $CO, $ANO);

  is $r->{n_setores_suprimidos}, 2, 'todos suprimidos';
  is $r->{cobertura_pct}, 0, 'cobertura zero (sem dado)';
  is $r->{renda_per_capita}, undef, 'renda NULL (não calculada, não 0)';
  is $r->{pct_sem_instrucao}, undef, 'pct sem instrução NULL';
  is $r->{pct_preto_pardo}, undef, 'pct preto/pardo NULL';
  is $r->{densidade_pop_km2}, undef, 'densidade NULL';
  is $r->{pct_analfabeto}, undef, 'pct analfabeto NULL (sem extração, não 0)';
  is $r->{pct_agua_sem_rede}, undef, 'pct água sem rede NULL';
  is $r->{pct_esgoto_inadequado}, undef, 'pct esgoto inadequado NULL';
  is $r->{pct_lixo_inadequado}, undef, 'pct lixo inadequado NULL';
  is $r->{pct_sem_banheiro}, undef, 'pct sem banheiro NULL';
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
