use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);

# =================================================================
# Regressão do loader Transportes (RENAVAM + RENAEST) — issue #169
#
# NÃO baixa os pacotes (RENAEST ~522 MB, RENAVAM ~136 MB). Verifica as
# decisões que o loader TOMA, que é onde os defeitos aparecem:
#
#   1. o grão de clean.renaest_sinistro é localidade/UF/dia: dois
#      acidentes no mesmo município/dia SOMAM numa linha, não se
#      apagam (a chave UNIQUE não inclui o número do acidente);
#   2. o sentinela `codigo_ibge = 0` da RENAEST nunca vira município;
#   3. UF sentinela da RENAVAM ("Não Identificado") nunca vira frota;
#   4. nome divergente vira `fuzzy`, não `exact`;
#   5. coluna obrigatória em falta aborta, não adivinha.
# =================================================================

my $JOB = 'EduMaps::Ingestion::Job::Transportes';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new) }

# Mock mínimo da malha: a mesma interface que o Mojolicious injecta,
# sem DBI nem Postgres.
sub mock_app {
  my $rows = shift;
  my $dbh = bless { rows => $rows }, 'MockDBH';
  my $storage = bless { dbh => $dbh }, 'MockStorage';
  my $schema  = bless { storage => $storage }, 'MockSchema';
  return bless { schema => $schema }, 'MockApp';
}
{
  package MockDBH;
  sub selectall_arrayref { return $_[0]{rows} }
}
{
  package MockStorage; sub dbh { $_[0]{dbh} }
  package MockSchema;  sub storage { $_[0]{storage} }
  package MockApp;     sub schema  { $_[0]{schema} }
}

my @MALHA = (
  { codigo_ibge => '1200328', sigla_uf => 'AC', nome_municipio => 'Jordão' },
  { codigo_ibge => '1200302', sigla_uf => 'AC', nome_municipio => 'Feijó' },
  { codigo_ibge => '5208707', sigla_uf => 'GO', nome_municipio => 'Goiânia' },
);

sub escrever {
  my ($path, $texto) = @_;
  open my $fh, '>:encoding(utf8)', $path or die "não escreveu $path: $!";
  print $fh $texto;
  close $fh or die $!;
  return $path;
}

# -----------------------------------------------------------------
subtest 'normalizar: acento, caixa e pontuação não decidem o match' => sub {
  my $j = job();
  is($j->normalizar("Olho d'Água das Flores"), 'olho d agua das flores', 'apóstrofo e acento somem');
  is($j->normalizar('OLHO D AGUA DAS FLORES'), 'olho d agua das flores', 'caixa e espaço somem');
  is($j->normalizar('  São   Paulo  '), 'sao paulo', 'espaços colapsam');
};

subtest 'similaridade: idêntico = 100, divergente < 100 e > 0' => sub {
  my $j = job();
  is($j->similaridade('Itapajé', 'ITAPAJE'), 100, 'mesmo nome normalizado = 100');
  my $s = $j->similaridade('Dona Euzébia', 'Dona Eusebia');
  cmp_ok($s, '<', 100, 'grafia diferente dá menos de 100');
  cmp_ok($s, '>', 0, 'mas continua parecido');
};

# -----------------------------------------------------------------
subtest 'ler_localidade: deduplica meses e ignora o sentinela 0' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/localidade.csv";
  escrever($csv, <<'CSV');
chv_localidade;ano_referencia;mes_referencia;mes_ano_referencia;regiao;uf;codigo_ibge;municipio;regiao_metropolitana;qtde_habitantes;frota_total;frota_circulante
AC1200328201801;2018;01;012018;NORTE;AC;1200328;JORDÃO;nao;8011;115;83
AC1200328201802;2018;02;022018;NORTE;AC;1200328;JORDÃO;nao;8011;120;85
AC1200302201801;2018;01;012018;NORTE;AC;1200302;FEIJÓ;nao;33688;3729;3032
XX0000000201801;2018;01;012018;NORTE;XX;0;NAO INFORMADO;nao;0;0;0
CSV
  my $loc = job()->ler_localidade($csv);
  is(scalar @{ $loc->{registros} }, 2, 'um registo por município, não por mês');
  is($loc->{estatisticas}{sentinelas}, 1, 'o código 0 é contado como sentinela');
  my %por = map { $_->{localidade} => $_ } @{ $loc->{registros} };
  is($por{'JORDÃO'}{codigo_ibge}, '1200328', 'código do JORDÃO');
  is($loc->{nome_por_codigo}{1200302}{municipio}, 'FEIJÓ', 'índice de nome pelo código');
  ok(!exists $loc->{nome_por_codigo}{'0'}, 'o sentinela não entra no índice');
};

# -----------------------------------------------------------------
# O ponto mais importante: o UNIQUE de renaest_sinistro NÃO tem o
# número do acidente. Se não agregássemos, o segundo acidente do dia
# sobrescreveria o primeiro (ON CONFLICT) e as vítimas desapareceriam.
subtest 'agregar_acidentes: localidade/dia soma, não sobrescreve' => sub {
  my $j = job();
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/acidentes.csv";
  escrever($csv, <<'CSV');
num_acidente;chv_localidade;data_acidente;uf_acidente;ano_acidente;mes_acidente;mes_ano_acidente;codigo_ibge;dia_semana;fase_dia;tp_acidente;cond_meteorologica;end_acidente;num_end_acidente;cep_acidente;bairro_acidente;km_via_acidente;latitude_acidente;longitude_acidente;hora_acidente;tp_rodovia;cond_pista;tp_cruzamento;tp_pavimento;tp_curva;lim_velocidade;tp_pista;ind_guardrail;ind_cantcentral;ind_acostamento;qtde_acidente;qtde_acid_com_obitos;qtde_envolvidos;qtde_feridosilesos;qtde_obitos
1;AC1200328201801;2018-01-14;AC;2018;01;012018;1200328;DOMINGO;MADRUGADA;COLISAO;CLARO;RUA;00000;00000000;CONQUISTA;0000;;;002200;NAO INFORMADO;SECA;NAO INFORMADO;ASFALTO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;1;0;2;2;1
2;AC1200328201801;2018-01-14;AC;2018;01;012018;1200328;DOMINGO;MANHA;COLISAO;CLARO;RUA;00000;00000000;CONQUISTA;0000;;;003300;NAO INFORMADO;SECA;NAO INFORMADO;ASFALTO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;1;0;3;3;2
3;AC1200302201802;2018-02-01;AC;2018;02;022018;1200302;QUINTA;TARDE;ATROPELAMENTO;CHUVA;RUA;00000;00000000;CENTRO;0000;;;140000;NAO INFORMADO;SECA;NAO INFORMADO;ASFALTO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;1;0;1;0;0
4;XX0000000201801;2018-01-01;XX;2018;01;012018;0;SEGUNDA;MANHA;COLISAO;CLARO;RUA;00000;00000000;X;0000;;;100000;NAO INFORMADO;SECA;NAO INFORMADO;ASFALTO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;NAO INFORMADO;1;0;1;0;0
CSV

  my $loc = job()->ler_localidade(
    escrever("$tmp/localidade.csv", <<'CSV'));
chv_localidade;ano_referencia;mes_referencia;mes_ano_referencia;regiao;uf;codigo_ibge;municipio;regiao_metropolitana;qtde_habitantes;frota_total;frota_circulante
AC1200328201801;2018;01;012018;NORTE;AC;1200328;JORDÃO;nao;8011;115;83
AC1200302201801;2018;01;012018;NORTE;AC;1200302;FEIJÓ;nao;33688;3729;3032
CSV

  my $res = $j->agregar_acidentes($csv, $loc);
  my $rows = $res->{rows};
  is(scalar @$rows, 2, 'dois acidentes no mesmo dia/município -> uma linha');
  is($res->{estatisticas}{sem_codigo}, 1, 'o acidente com código sentinela é contado');

  my %por = map { $_->{data} => $_ } @$rows;
  my $dia14 = $por{'2018-01-14'};
  ok($dia14, 'existe a linha do dia 14');
  is($dia14->{localidade}, 'JORDÃO', 'localidade vem do nome RENAEST');
  is($dia14->{mortos}, 3, 'mortos dos dois acidentes somam (1+2)');
  is($dia14->{veiculos}, 5, 'veículos dos dois acidentes somam (2+3)');
  is($por{'2018-02-01'}{mortos}, 0, 'acidente sem óbito soma 0, não NULL');
};

subtest 'agregar_acidentes: linha sem nome no de-para é contada' => sub {
  my $j = job();
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/acidentes.csv";
  escrever($csv, <<'CSV');
num_acidente;chv_localidade;data_acidente;uf_acidente;codigo_ibge;qtde_obitos;qtde_envolvidos
1;GO5208707201801;2018-01-01;GO;5208707;1;1
CSV
  # de-para vazio de propósito: o município não está lá.
  my $res = $j->agregar_acidentes($csv, { nome_por_codigo => {} });
  is(scalar @{ $res->{rows} }, 0, 'sem nome não há linha');
  is($res->{estatisticas}{sem_nome}, 1, 'e a linha não desaparece em silêncio');
};

# -----------------------------------------------------------------
subtest 'agregar_renavam: sentinela de UF e nome sem casa são contados' => sub {
  my $j = job();
  $j->{app} = mock_app(\@MALHA);
  my $tmp = tempdir(CLEANUP => 1);
  my $txt = "$tmp/renavam.TXT";
  escrever($txt, <<'TXT');
UF;Município;Marca Modelo;Ano Fabricação Veículo CRV;Qtd. Veículos
ACRE;JORDÃO;AGRALE/13000;2009; 1.0
ACRE;JORDÃO;AGRALE/1800;1989; 2.0
ACRE;FEIJÓ;FIAT/UNO;2010; 3.0
Não Identificado;SEM INFO;X;2000; 5.0
ACRE;MUNICÍPIO QUE NÃO EXISTE;X;2000; 4.0
TXT

  my $res = $j->agregar_renavam($txt);
  my %por = map { $_->{codigo_ibge} => $_->{total_frota} } @{ $res->{rows} };
  is(scalar @{ $res->{rows} }, 2, 'só os dois municípios que casam na malha');
  is($por{'1200328'}, 3, 'JORDÃO soma 1+2');
  is($por{'1200302'}, 3, 'FEIJÓ soma 3');
  is($res->{estatisticas}{uf_sentinela}, 1, 'a UF "Não Identificado" é contada');
  is($res->{estatisticas}{sem_municipio}, 1, 'o município inexistente é contado');
  is($res->{estatisticas}{pares_sem_casa}, 1, 'e o par (UF, município) fica nomeado');
  is($res->{orfaos}{'AC/MUNICÍPIO QUE NÃO EXISTE'}, 1, 'o órfão é identificado por nome');
};

# A contagem sozinha não é accionável: ninguém sabe o que corrigir.
subtest 'órfãos RENAVAM: relatório nomeia o par (UF, município)' => sub {
  my $j = job();
  my $tmp = tempdir(CLEANUP => 1);
  $j->{config} = { dir_trabalho => $tmp };

  my $orfaos = {
    'RS/SANTANA DO LIVRAMENTO' => 14563,
    'PR/MUNHOZ DE MELLO'        => 1909,
    'PA/SANTA ISABEL DO PARA'   => 6537,
  };
  my $total = $j->registrar_orfaos_renavam($orfaos);
  is($total, 14563 + 1909 + 6537, 'o total é a soma das linhas');

  my $destino = "$tmp/renavam_orfaos.csv";
  ok(-f $destino, 'o relatório foi escrito');

  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $destino or die $!;
  is_deeply($csv->getline($fh), [qw(uf_municipio linhas)], 'cabeçalho');
  my @lidas;
  while (my $r = $csv->getline($fh)) { push @lidas, $r }
  close $fh;

  is(scalar @lidas, 3, 'um registo por par órfão');
  is($lidas[0][0], 'RS/SANTANA DO LIVRAMENTO', 'ordenado pelo que pesa mais');
  is($lidas[0][1], 14563, 'com o número de linhas');
  is($lidas[2][0], 'PR/MUNHOZ DE MELLO', 'o mais pequeno no fim');

  is($j->registrar_orfaos_renavam({}), 0, 'sem órfãos não escreve ficheiro vazio');
  ok(!-f "$tmp/vazio.csv", 'e não inventa relatório');
};

subtest 'UF da RENAVAM é nome de estado; normalizar não basta' => sub {
  my $j = job();
  $j->{app} = mock_app(\@MALHA);
  my $tmp = tempdir(CLEANUP => 1);
  my $txt = "$tmp/renavam.TXT";
  escrever($txt, "UF;Município;Marca Modelo;Ano Fabricação Veículo CRV;Qtd. Veículos\nSÃO PAULO;GOIÂNIA;X;2000; 7.0\n");

  # GOIÂNIA está em GO, não em SP: o par (UF, município) é que decide,
  # e não o nome do município isolado.
  my $res = $j->agregar_renavam($txt);
  is(scalar @{ $res->{rows} }, 0, 'município de outra UF não casa');
  is($res->{estatisticas}{sem_municipio}, 1, 'e é contado');
};

subtest 'contrato: coluna obrigatória em falta aborta' => sub {
  my $j = job();
  my $err = do { local $@; eval { $j->_exigir_colunas([qw(a b)], [qw(a b c)], 'Fonte X') }; $@ };
  like($err, qr/faltam colunas obrigatórias: c/, 'nomeia a coluna em falta');
  like($err, qr/Fonte X/, 'diz de que fonte se trata');
  ok($j->_exigir_colunas([qw(a b c)], [qw(a c)], 'Fonte X'), 'coluna a mais não é erro fatal');
};

# -----------------------------------------------------------------
# #155: o de-para resolve pelo codigo_ibge da fonte; o que não resolve
# tem destino explícito em vez de desaparecer num `next`.
subtest 'classificar_depara: exact, fuzzy e o que fica de fora com motivo' => sub {
  my $j = job();
  $j->{app} = mock_app(\@MALHA);
  my $loc = {
    registros => [
      { localidade => 'JORDÃO',             uf => 'AC', codigo_ibge => '1200328' },
      { localidade => 'FEIJO GRANDE',       uf => 'AC', codigo_ibge => '1200302' },
      { localidade => 'MUNICIPIO FANTASMA', uf => 'AC', codigo_ibge => '9999999' },
    ],
    nao_resolvidas => [
      { localidade => 'NAO INFORMADO', uf => 'XX', codigo_ibge_fonte => '0',       motivo => 'codigo_sentinela' },
      { localidade => '',              uf => '',   codigo_ibge_fonte => '5208707', motivo => 'sem_nome_ou_uf' },
    ],
  };
  my $c = $j->classificar_depara($loc);
  is(scalar @{ $c->{linhas} }, 2, 'só as duas localidades que casam viram de-para');
  is($c->{contagem}{exact}, 1, 'JORDÃO vs Jordão é exact');
  is($c->{contagem}{fuzzy}, 1, 'grafia divergente com código válido é fuzzy');
  is($c->{contagem}{codigo_fora_da_malha}, 1, 'código inexistente na malha é contado');
  is($c->{contagem}{codigo_sentinela}, 1, 'o sentinela conta');
  is($c->{contagem}{sem_nome_ou_uf}, 1, 'a linha sem nome/UF conta');
  is(scalar @{ $c->{nao_resolvidas} }, 3, 'três destinos: sentinela, sem nome/UF e fora da malha');
  my ($fora) = grep { $_->{motivo} eq 'codigo_fora_da_malha' } @{ $c->{nao_resolvidas} };
  is($fora->{codigo_ibge_fonte}, '9999999', 'o código da fonte é preservado');
  is($fora->{localidade}, 'MUNICIPIO FANTASMA', 'e o nome também');
};

subtest 'ler_localidade: o que é descartado sai nomeado, não só contado' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $csv = "$tmp/localidade.csv";
  escrever($csv, <<'CSV');
chv_localidade;ano_referencia;mes_referencia;mes_ano_referencia;regiao;uf;codigo_ibge;municipio;regiao_metropolitana;qtde_habitantes;frota_total;frota_circulante
AC1200328201801;2018;01;012018;NORTE;AC;1200328;JORDÃO;nao;8011;115;83
XX0000000201801;2018;01;012018;NORTE;XX;0;NAO INFORMADO;nao;0;0;0
AC1200302201801;2018;01;012018;NORTE;AC;1200302;;nao;33688;3729;3032
CSV
  my $loc = job()->ler_localidade($csv);
  is(scalar @{ $loc->{registros} }, 1, 'só o município completo entra no de-para');
  is(scalar @{ $loc->{nao_resolvidas} }, 2, 'sentinela e sem nome/UF têm destino');
  my %m = map { $_->{motivo} => $_ } @{ $loc->{nao_resolvidas} };
  is($m{codigo_sentinela}{codigo_ibge_fonte}, '0', 'o sentinela preserva o código 0');
  is($m{codigo_sentinela}{localidade}, 'NAO INFORMADO', 'e o nome que a fonte deu');
  is($m{sem_nome_ou_uf}{localidade}, '', 'a linha sem nome tem localidade vazia');
  is($m{sem_nome_ou_uf}{codigo_ibge_fonte}, '1200302', 'mas preserva o código que trazia');
};

done_testing();
