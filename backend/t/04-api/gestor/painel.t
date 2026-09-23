# t/04-api/gestor/painel.t
# Testes da API do painel do gestor escolar:
#   GET /api/gestor/:cod_inep/painel
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $INEP = '11000040';

sub panel {
  return $t->get_ok("/api/gestor/$INEP/painel")->status_is(200)->tx->res->json;
}

sub find_item {
  my ($items, $key) = @_;
  return (grep { $_->{key} eq $key } @$items)[0];
}

subtest 'GET /api/gestor/:inep/painel: 200 com todas as seções' => sub {
  my $json = panel();

  is $json->{escola}{id_escola}, $INEP, 'id da escola';
  ok defined $json->{escola}{nome}, 'nome presente';
  is $json->{escola}{rede}, 'Municipal', 'rede traduzida';
  ok defined $json->{escola}{municipio}, 'município presente';
  ok defined $json->{escola}{uf}, 'uf presente';
  ok defined $json->{escola}{cod_municipio}, 'cod_municipio presente (contexto do chat)';

  ok ref($json->{resumo}) eq 'HASH', 'resumo';
  ok ref($json->{matriculas}{por_etapa}) eq 'ARRAY', 'matriculas.por_etapa';
  ok ref($json->{matriculas}{por_turno}) eq 'ARRAY', 'matriculas.por_turno';
  ok ref($json->{matriculas}{por_modalidade}) eq 'ARRAY', 'matriculas.por_modalidade';
  ok ref($json->{matriculas}{por_faixa_etaria}) eq 'ARRAY', 'matriculas.por_faixa_etaria';
  ok ref($json->{turmas}) eq 'HASH', 'turmas';
  ok ref($json->{docentes}{por_formacao}) eq 'ARRAY', 'docentes.por_formacao';
  ok ref($json->{docentes}{por_vinculo}) eq 'ARRAY', 'docentes.por_vinculo';
  ok ref($json->{docentes}{por_disciplina}) eq 'ARRAY', 'docentes.por_disciplina';
  ok ref($json->{infraestrutura}{basica}) eq 'ARRAY', 'infraestrutura.basica';
  ok ref($json->{infraestrutura}{espacos}) eq 'ARRAY', 'infraestrutura.espacos';
  ok ref($json->{equipamentos}{itens}) eq 'ARRAY', 'equipamentos.itens';
  ok ref($json->{equipamentos}{dispositivos}) eq 'ARRAY', 'equipamentos.dispositivos';
  ok ref($json->{equipamentos}{conectividade}) eq 'ARRAY', 'equipamentos.conectividade';
  ok ref($json->{acessibilidade}) eq 'ARRAY', 'acessibilidade';
};

subtest 'resumo e turmas (salas)' => sub {
  my $json = panel();
  my $resumo = $json->{resumo};

  is $resumo->{matriculas}, 211, 'total de matrículas';
  is $resumo->{docentes}, 9, 'total de docentes';
  is $resumo->{salas_utilizadas}, 6, 'salas utilizadas';
  is $resumo->{alunos_por_sala}, 35.2, 'média de alunos por sala (211/6)';
  is $json->{turmas}{salas_utilizadas}, 6, 'turmas.salas_utilizadas';
  ok length $json->{turmas}{nota} > 0, 'nota sobre a ausência de "turmas" no Censo';
};

subtest 'matrículas por etapa, turno, modalidade e faixa etária' => sub {
  my $m = panel()->{matriculas};

  is $m->{total}, 211, 'total';
  is find_item($m->{por_etapa}, 'pre_escola')->{value}, 211, 'pré-escola';
  is find_item($m->{por_etapa}, 'creche')->{value}, 0, 'creche';
  is find_item($m->{por_turno}, 'matutino')->{value}, 211, 'matutino';
  is find_item($m->{por_turno}, 'noturno')->{value}, 0, 'noturno';
  is find_item($m->{por_modalidade}, 'especial')->{value}, 27, 'educação especial';
  is find_item($m->{por_modalidade}, 'regular')->{value}, 184, 'regular (211-27)';
  is find_item($m->{por_faixa_etaria}, '4-5')->{value}, 195, 'faixa 4-5';
  is $m->{inclusao}{educacao_especial}, 27, 'inclusão: total especial';
  is $m->{inclusao}{classes_comuns}, 27, 'inclusão: classes comuns';
};

subtest 'docentes: formação, vínculo e disciplina' => sub {
  my $d = panel()->{docentes};

  is $d->{total}, 9, 'total de docentes';
  is find_item($d->{por_vinculo}, 'concurso')->{value}, 9, 'concursados';
  is find_item($d->{por_formacao}, 'superior')->{value}, 9, 'superior';
  is find_item($d->{por_formacao}, 'superior_licenciatura')->{value}, 9, 'licenciatura';
  ok ref($d->{por_disciplina}) eq 'ARRAY', 'disciplinas é array';
};

subtest 'infraestrutura, equipamentos e acessibilidade (booleanos)' => sub {
  my $json = panel();

  my $agua = find_item($json->{infraestrutura}{basica}, 'agua_potavel');
  is $agua->{present}, 1, 'água potável presente';
  is $agua->{key}, 'agua_potavel', 'key preservada';

  my $internet = find_item($json->{equipamentos}{conectividade}, 'internet');
  ok defined $internet->{present}, 'conectividade tem present';

  my $rampas = find_item($json->{acessibilidade}, 'rampas');
  is $rampas->{present}, 1, 'rampas presentes';

  ok scalar(@{ $json->{equipamentos}{dispositivos} }) == 3, '3 dispositivos de aluno';
};

subtest 'erros' => sub {
  $t->get_ok('/api/gestor/99999999/painel')->status_is(404);
  $t->get_ok('/api/gestor/123/painel')->status_is(404);
};

done_testing();
