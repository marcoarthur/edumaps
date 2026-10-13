use lib qw(t/lib lib);
use strict;
use warnings;
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);

# Teste básico do job IBGE/SIDRA
my $JOB = 'EduMaps::Ingestion::Job::IBGE';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new) }

ok(defined job(), 'instancia job IBGE');
is(job()->job_name, 'IBGE', 'nome do job correto');
is(job()->tabela_pib, '5938', 'tabela SIDRA correta');

# Contrato de clean.dados_ibge (#234): *_percent são fração do PIB e
# serviços é o complemento. O CSV bruto traz o % oficial do SIDRA (0-100,
# do valor adicionado), que NÃO pode chegar à tabela.
subtest 'processar_dados_ibge: percentuais pelo contrato, não os do SIDRA' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/dados_ibge.csv";
  open my $fh, '>:encoding(utf8)', $csv or die $!;
  print $fh "codigo_ibge,ano,pib_total,governo,industria,agro,industria_percent,agro_percent,governo_percent,servicos_percent\n";
  # 1100015/2021, valores reais medidos na P1
  print $fh "1100015,2021,734467,173122,27845,311469,4.07,45.48,25.28,25.18\n";
  print $fh "1100023,2021,,10,20,30,1,2,3,4\n";
  print $fh "1100031,2021,1000,,200,300,1,2,3,4\n";
  close $fh;

  my %r = map { $_->{codigo_ibge} => $_ } @{ job()->processar_dados_ibge($csv) };
  my $a = $r{1100015};
  cmp_ok(abs($a->{industria_percent} - 27845/734467), '<', 1e-12, 'indústria = industria / pib_total');
  cmp_ok(abs($a->{agro_percent} - 311469/734467), '<', 1e-12, 'agro = agro / pib_total');
  cmp_ok(abs($a->{governo_percent} - 173122/734467), '<', 1e-12, 'governo = governo / pib_total');
  cmp_ok(abs($a->{servicos_percent} - (1 - (27845 + 311469 + 173122) / 734467)), '<', 1e-12,
    'serviços = complemento');
  cmp_ok($a->{agro_percent}, '<', 1, 'fração, não percentual 0-100');

  ok(!defined $r{1100023}{industria_percent}, 'sem PIB, sem fração (NULL, não 0)');
  ok(!defined $r{1100023}{servicos_percent}, 'e sem complemento');
  ok(!defined $r{1100031}{governo_percent}, 'setor ausente fica NULL');
  ok(!defined $r{1100031}{servicos_percent}, 'complemento só com os três setores');
  is($r{1100031}{industria_percent}, 0.2, 'os setores presentes seguem calculados');
};

# classificacao é parte da PK de ibge_agregados: vazio vira 'Total'
# (convenção SIDRA), nunca NULL (#234: a carga real abortava).
subtest 'processar_ibge_agregados: sem classificação vira Total' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/ibge_agregados.csv";
  open my $fh, '>:encoding(utf8)', $csv or die $!;
  print $fh qq{codigo_ibge,ano,tabela_id,variavel,classificacao,valor,unidade\n};
  print $fh qq{1100015,2014,5938,37,,377799,"Mil Reais"\n};
  print $fh qq{1100015,2014,9999,1,Agropecuária,10,%\n};
  close $fh;
  my @r = @{ job()->processar_ibge_agregados($csv) };
  is($r[0]{classificacao}, 'Total', 'vazio vira Total');
  is($r[1]{classificacao}, 'Agropecuária', 'classificação real preservada');
};

done_testing();
