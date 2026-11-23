use lib qw(t/lib lib);
use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use utf8;
use open ':std', ':encoding(UTF-8)';
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);

# #533 (QP-01 da P2): população por idade do Censo 2022 (SIDRA 9514).
my $JOB = 'EduMaps::Ingestion::Job::IBGEPopulacaoIdade';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new(level => 'fatal'), @_) }

no warnings 'once';
my %NOME = map { $_->[0] => $_->[1] } @EduMaps::Ingestion::Job::IBGEPopulacaoIdade::CATEGORIAS;

# Resposta /f/a do SIDRA: cabeçalho e uma linha por município × categoria.
sub resposta (@linhas) {
  return [
    { D1C => 'Município (Código)', D5C => 'Idade (Código)', D5N => 'Idade', V => 'Valor' },
    map { { D1C => $_->[0], D5C => $_->[1], D5N => $_->[2] // $NOME{ $_->[1] }, V => $_->[3] } } @linhas,
  ];
}

subtest 'identidade e lotes' => sub {
  my $j = job();
  is $j->job_name, 'IBGEPopulacaoIdade', 'nome';
  is $j->schedule, 'manual', 'manual: o Censo é decenal';
  is_deeply [$j->tabelas], ['clean.populacao_idade'], 'tabela registrada';
  my @lotes = $j->lotes;
  is scalar(@lotes), 5, 'cinco requisições';
  is scalar(map { @$_ } @lotes), 40, 'total, 21 faixas e 18 idades';
  ok !(grep { @$_ > 8 } @lotes), 'no máximo 8 categorias por lote (limite do SIDRA)';
  my $url = $j->url_lote(@{ $lotes[0] });
  like $url, qr{^https://apisidra\.ibge\.gov\.br/values/t/9514/n6/all/v/93/p/2022/c2/6794/c287/100362,93070,}, 'URL do lote';
  like $url, qr{/c286/113635/f/a$}, 'todas as formas de declaração, códigos e nomes';
  ok $j->allowlist->validate_url($url), 'URL no allowlist';
};

subtest 'linhas_da_resposta: "-" é zero, sigilo fica vazio' => sub {
  my $l = job()->linhas_da_resposta(resposta(
    ['3516200', 6558, undef, '3966'],
    ['3516200', 6653, undef, '-'],
    ['3516200', 60040, undef, '...'],
  ));
  is_deeply $l->[0], ['3516200', 2022, '9514', '93', '1 ano', '3966', 'Pessoas'], 'linha no formato longo';
  is $l->[1][5], 0, '"-" é zero (convenção do IBGE)';
  ok !defined $l->[2][5], '"..." fica vazio';
};

subtest 'linhas_da_resposta: categoria desconhecida ou renomeada aborta' => sub {
  eval { job()->linhas_da_resposta(resposta(['3516200', 99999, 'Outra', '1'])) };
  like $@, qr/Categoria de idade inesperada/, 'código fora da lista';
  eval { job()->linhas_da_resposta(resposta(['3516200', 6558, '1 ano de idade', '1'])) };
  like $@, qr/Nome da categoria 6558 mudou/, 'nome trocado';
  eval { job()->linhas_da_resposta([{}]) };
  like $@, qr/sem dados/, 'resposta vazia';
};

# Um município coerente: faixas somam o total e as idades somam 0 a 4.
sub municipio ($cod, %ajuste) {
  my %v = map { $_ => 0 } values %NOME;
  @v{ 'Menos de 1 ano', '1 ano', '2 anos', '3 anos', '4 anos' } = (1, 2, 3, 4, 5);
  $v{'0 a 4 anos'} = 15;
  $v{'5 a 9 anos'} = 20;
  $v{Total} = 35;
  %v = (%v, %ajuste);
  return map { +{ codigo_ibge => $cod, classificacao => $_, valor => $v{$_} } } keys %v;
}

subtest 'conferir: somas e número de municípios' => sub {
  my $j = job(config => { aceitar_parcial => 1 });
  is $j->conferir([ municipio('3516200'), municipio('3550308') ]), 2, 'coerente';

  eval { $j->conferir([ municipio('3516200', Total => 36) ]) };
  like $@, qr/3516200: faixas somam 35, total 36/, 'faixas que não somam o total';
  eval { $j->conferir([ municipio('3516200', '3 anos' => 9) ]) };
  like $@, qr/idades de 0 a 4 somam 20, faixa 15/, 'idades que não somam a faixa';

  eval { job()->conferir([ municipio('3516200') ]) };
  like $@, qr/Só 1 municípios .*mínimo 5500/, 'resposta parcial aborta';
};

subtest 'run com o bruto preservado: relê, confere e carrega (dry-run)' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/bruto.csv";
  my $j = job(dry_run => 1, config => { aceitar_parcial => 1, dir_trabalho => $tmp });
  $j->escrever_csv($csv, [ map { [ $_->{codigo_ibge}, 2022, '9514', '93', $_->{classificacao}, $_->{valor}, 'Pessoas' ] } municipio('3516200') ]);
  is $j->run({ csv => $csv }), 40, '40 linhas de um município (sem gravar)';
};

done_testing();
