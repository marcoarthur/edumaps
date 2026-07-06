use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use Mojo::Util qw(url_escape);
use Mojo::JSON qw(decode_json);

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

subtest 'analytics: código existente retorna dados completos' => sub {
  my $cod = 1100015;

  my $tx = $t->get_ok("/api/analytics/city/$cod/details")->status_is(200)->tx;
  my $json = eval { decode_json($tx->res->body) } || {};
  diag "Failed to decode JSON: $@" if $@;

  # Verifica campos principais
  ok exists $json->{co_municipio}, 'co_municipio existe';
  is $json->{co_municipio}, $cod, 'co_municipio corresponde ao código';

  ok exists $json->{no_municipio}, 'no_municipio existe';
  ok exists $json->{sg_uf}, 'sg_uf existe';
  ok exists $json->{no_regiao}, 'no_regiao existe';

  # Verifica campos de escolas
  ok exists $json->{total_escolas}, 'total_escolas existe';
  ok exists $json->{escolas_publicas}, 'escolas_publicas existe';
  ok exists $json->{escolas_privadas}, 'escolas_privadas existe';
  ok exists $json->{escolas_urbanas}, 'escolas_urbanas existe';
  ok exists $json->{escolas_rurais}, 'escolas_rurais existe';

  # Verifica alunos
  ok exists $json->{total_alunos}, 'total_alunos existe';
  ok exists $json->{alunos_infantil}, 'alunos_infantil existe';
  ok exists $json->{alunos_fundamental}, 'alunos_fundamental existe';
  ok exists $json->{alunos_medio}, 'alunos_medio existe';
  ok exists $json->{alunos_eja}, 'alunos_eja existe';

  # Verifica docentes
  ok exists $json->{total_docentes}, 'total_docentes existe';
  ok exists $json->{perc_docentes_superior}, 'perc_docentes_superior existe';
  ok exists $json->{perc_docentes_concursados}, 'perc_docentes_concursados existe';

  # Verifica scores
  ok exists $json->{score_infra_medio}, 'score_infra_medio existe';
  ok exists $json->{score_tecnologia_medio}, 'score_tecnologia_medio existe';
  ok exists $json->{score_acessibilidade_medio}, 'score_acessibilidade_medio existe';
  ok exists $json->{score_gestao_medio}, 'score_gestao_medio existe';

  # Verifica IDEB
  ok exists $json->{ideb_fund_i}, 'ideb_fund_i existe';
  ok exists $json->{ideb_fund_ii}, 'ideb_fund_ii existe';
  ok exists $json->{ideb_medio}, 'ideb_medio existe';
  ok exists $json->{ano_ideb}, 'ano_ideb existe';

  # Verifica população e PIB
  ok exists $json->{populacao_estimada}, 'populacao_estimada existe';
  ok exists $json->{pop_0_a_14}, 'pop_0_a_14 existe';
  ok exists $json->{pop_15_a_24}, 'pop_15_a_24 existe';
  ok exists $json->{pop_25_a_59}, 'pop_25_a_59 existe';
  ok exists $json->{pop_60_mais}, 'pop_60_mais existe';
  ok exists $json->{pib_total}, 'pib_total existe';
  ok exists $json->{pib_per_capita}, 'pib_per_capita existe';
  ok exists $json->{ano_pib}, 'ano_pib existe';

  # Verifica percentuais econômicos
  ok exists $json->{agro_percent}, 'agro_percent existe';
  ok exists $json->{industria_percent}, 'industria_percent existe';
  ok exists $json->{servicos_percent}, 'servicos_percent existe';
  ok exists $json->{governo_percent}, 'governo_percent existe';

  # Verifica indicadores derivados
  ok exists $json->{alunos_por_1000_hab}, 'alunos_por_1000_hab existe';
  ok exists $json->{alunos_por_docente}, 'alunos_por_docente existe';
  ok exists $json->{alunos_por_escola}, 'alunos_por_escola existe';

  # Verifica alguns valores conhecidos do exemplo
  is $json->{no_municipio}, 'Alta Floresta D\'Oeste', 'nome do município correto';
  is $json->{sg_uf}, 'RO', 'UF correta';
  ok $json->{total_escolas} > 0, 'total_escolas > 0';
};

subtest 'analytics: código existente sem dados (retorna 404?)' => sub {
  # Escolha um código que existe em municipios_sp mas não em analytics
  # Por exemplo, um código que não está na view analítica.
  # Se não houver, podemos testar um código inexistente.
  my $cod = 9999999;  # não existe em lugar nenhum

  $t->get_ok("/api/analytics/city/$cod/details")->status_is(404);
};

subtest 'analytics: código com formato inválido (rota não casa)' => sub {
  $t->get_ok("/api/analytics/city/123/details")->status_is(404);      # menos de 7 dígitos
  $t->get_ok("/api/analytics/city/12345678/details")->status_is(404); # mais de 7 dígitos
  $t->get_ok("/api/analytics/city/abc/details")->status_is(404);      # não numérico
};

done_testing;
