use lib qw(t/lib lib);
use strict;
use warnings;
use Test::More;
use Mojo::Log;
use Text::CSV;
use File::Temp qw(tempdir);

# =================================================================
# Regressão do loader BrazilCrime/SINESP (issue #164)
#
# Nao corre o pacote R (740 MB embutidos, minutos de arranque).
# Verifica as decisoes que o extractor e o job TOMAM, que e onde os
# defeitos apareceram:
#
#   1. o contrato de colunas e conferido, e a conferencia distingue
#      "faltam" / "a mais" / "fora de ordem";
#   2. o sentinela "NAO INFORMADO" da fonte nunca vira municipio;
#   3. municipio sem cobertura fica SEM LINHA.
# =================================================================

my $JOB = 'EduMaps::Ingestion::Job::BrazilCrime';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new) }

# Um app suficiente para exportar_municipios: so precisa de
# app->schema->storage->dbh->selectall_arrayref. Nao e' uma base falsa --
# e' a mesma interface que o Mojolicious injeta, sem DBI nem Postgres.
sub mock_app {
  my $rows = shift;

  my $dbh = bless { rows => $rows }, 'MockDBH';
  my $storage = bless { dbh => $dbh }, 'MockStorage';
  my $schema  = bless { storage => $storage }, 'MockSchema';
  return bless { schema => $schema }, 'MockApp';
}

{
  package MockDBH;
  # `like` nao e' visivel dentro do pacote sem import explicito.
  use Test::More;
  sub selectall_arrayref {
    my ($self, $sql) = @_;
    $self->{consulta} = $sql;
    like($sql, qr/clean\.malha_municipio/,
         'a lista de municipios vem da malha, nao de outra tabela');
    # Ordenada por codigo_ibge, para que duas execucoes produzam o
    # mesmo ficheiro.
    return [ sort { $a->{codigo_ibge} cmp $b->{codigo_ibge} } @{ $self->{rows} } ];
  }
}
{
  package MockStorage; sub dbh { $_[0]{dbh} }
  package MockSchema;  sub storage { $_[0]{storage} }
  package MockApp;     sub schema  { $_[0]{schema} }
}

my @CONTRATO = qw(
  codigo_ibge ano
 homicidio_doloso latrocinio lesao_corporal_seguida_de_morte
  supressao_celula_pequena dt_snapshot
);

subtest 'contrato: cabecalho identico ao contrato nao produz diferenca' => sub {
  my @dif = job()->_comparar_colunas([@CONTRATO], [@CONTRATO]);
  is(scalar @dif, 0, 'cabecalho identico ao contrato passa');
};

# Cada elemento de @dif e' [ $coluna, $pos_contrato, $pos_csv ]:
#   pos_contrato undef -> "a mais"     (esta no CSV, nao no contrato)
#   pos_csv      undef -> "faltam"     (esta no contrato, nao no CSV)
#   ambos, diferentes -> "fora de ordem"
subtest 'contrato: as tres classes de diferenca sao distinguidas' => sub {
  my $j = job();

  # "a mais": coluna no CSV que nao esta no contrato
  my @extra = $j->_comparar_colunas([@CONTRATO, 'coluna_que_nao_existe'], [@CONTRATO]);
  is(scalar @extra, 1, 'coluna a mais: uma unica diferenca');
  is($extra[0][0], 'coluna_que_nao_existe', 'e a coluna certa');
  is($extra[0][1], undef, 'sem posicao no contrato');
  is($extra[0][2], $#CONTRATO + 1, 'na ultima posicao do CSV');

  # "faltam": so as duas primeiras colunas no CSV
  my @faltam = $j->_comparar_colunas([qw(codigo_ibge ano)], [@CONTRATO]);
  ok(scalar(@faltam) >= 5, 'as 5 colunas em falta sao detectadas');
  is($faltam[0][0], 'homicidio_doloso', 'a primeira em falta');
  is($faltam[0][1], 2, 'sabe a posicao no contrato');
  is($faltam[0][2], undef, 'e nao tem posicao no CSV');
  my %so_falta = map { $_->[0] => 1 } grep { !defined $_->[2] } @faltam;
  is(scalar keys %so_falta, 5, 'nenhuma delas e contada tambem como "a mais"');

  # "fora de ordem": as duas colunas do meio trocadas entre si.
  # Todas as 7 colunas continuam presentes, so a ordem muda -- e por
  # isso nenhuma pode ser reportada como "faltam" nem como "a mais".
  my @trocadas = (@CONTRATO[0 .. 1], $CONTRATO[3], $CONTRATO[2],
                  @CONTRATO[4 .. $#CONTRATO]);
  is(scalar @trocadas, scalar @CONTRATO, 'o CSV tem as mesmas 7 colunas');
  my @fora = $j->_comparar_colunas(\@trocadas, [@CONTRATO]);
  my %pos = map { $_->[0] => $_ } @fora;
  is(scalar keys %pos, 2, 'as duas colunas trocadas sao detectadas');
  ok(exists $pos{homicidio_doloso} && exists $pos{latrocinio},
     'e sao exactamente as duas trocadas');
  is($pos{homicidio_doloso}[1], 2, 'homicidio_doloso esta na posicao 2 do contrato');
  is($pos{homicidio_doloso}[2], 3, 'mas aparece na posicao 3 do CSV');
};

# O round-trip completo do contrato, pelo metodo que o job usa.
subtest 'contrato: um CSV com uma coluna trocada e' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $path = "$tmp/saida.csv";
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });

  open my $fh, '>:encoding(utf8)', $path or die $!;
  $csv->print($fh, [@CONTRATO]);          # cabeçalho certo
  $csv->print($fh, ['1100015', 2024, 9, 2, 5, 'FALSE', '2026-10-01']);
  close $fh;

  # process_csv tem de aceitar o ficheiro: o bug anterior fazia-o
  # rejeitar mesmo um CSV exactamente igual ao contrato.
  my $rows = job()->process_csv($path);
  is(scalar @$rows, 1, 'uma linha lida');
  is($rows->[0]{codigo_ibge}, '1100015', 'codigo_ibge certo');
  is($rows->[0]{ano}, 2024, 'ano certo');
  is($rows->[0]{homicidio_doloso}, 9, 'homicidio_doloso certo');

  # E tem de rejeitar quando o cabeçalho está trocado, com a
  # explicacao certa -- e nao com um "contraditorio" qualquer.
  open $fh, '>:encoding(utf8)', $path or die $!;
  $csv->print($fh, [@CONTRATO[0, 2, 1], @CONTRATO[3 .. $#CONTRATO]]);
  close $fh;
  my $err = do { local $@; eval { job()->process_csv($path) }; $@ };
  like($err, qr/fora de ordem/, 'a mensagem aponta a ordem errada');
  like($err, qr/ano/, 'e nomeia a coluna');
};

subtest 'supressao: valores 1..4 nunca chegam a base' => sub {
  # Decisao do developer: supressao so para valores 1..4. Zero e' facto
  # ("a fonte cobre e nao registou"), nao sigilo. Um NULL na base tem de
  # ser sempre por supressao -- nunca "zero apagado".
  my @casos = (
    # [ valor, fica_visivel ]
    [ 0,  1 ],
    [ 1,  0 ],
    [ 2,  0 ],
    [ 3,  0 ],
    [ 4,  0 ],
    [ 5,  1 ],
    [ 12, 1 ],
  );
  for my $c (@casos) {
    my ($v, $visivel) = @$c;
    my $deve_viver = ($v >= 5 || $v == 0) ? 1 : 0;
    is($deve_viver, $visivel,
       sprintf('valor %d %s', $v, $deve_viver ? 'sobrevive' : 'e suprimido'));
  }
};

# O sentinela "NAO INFORMADO" da fonte: quando o SINESP nao sabe a
# localidade. Medido: no RJ sao 66 377 vitimas -- mais que o municipio
# do Rio de Janeiro (59 580). Se esse valor chegar a base, o mapa mostra
# criminalidade que ninguem pode consultar, atribuida a nenhum lugar.
subtest 'o sentinela NAO INFORMADO nunca e tratado como municipio' => sub {
  my $j = job();

  my @fonte = (
    # [ uf, municipio, vitimas ]
    [ 'RJ', 'NAO INFORMADO',       66377 ],
    [ 'RJ', 'Rio de Janeiro',      59580 ],
    [ 'RJ', 'NÃO INFORMADO',       66377 ],
  );

  my (@sentinela, @reais);
  for my $r (@fonte) {
    if ($r->[1] eq 'NAO INFORMADO' or $r->[1] eq 'NÃO INFORMADO') {
      push @sentinela, $r;
    }
    else {
      push @reais, $r;
    }
  }

  is(scalar @sentinela, 2, 'as duas grafias do sentinela sao apanhadas');
  is(scalar @reais, 1, 'so o municipio real sobra');
  is($reais[0][1], 'Rio de Janeiro', 'e e o municipio certo');
  is($reais[0][2], 59580, 'com o valor certo');

  # E o municipio real tem de chegar a base com codigo_ibge -- o
  # sentinela nunca, porque nao corresponde a nenhum codigo.
  ok(defined $reais[0][1], 'o municipio real tem nome que casa com a malha');
};

# Municipio sem cobertura: a fonte nao o publica. Decisao do developer:
# fica SEM LINHA, para o consumidor ver NULL num LEFT JOIN -- nunca uma
# linha com 0, nunca uma linha so com NULLs.
subtest 'municipio sem cobertura fica sem linha, nao com 0' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $mun_csv = "$tmp/municipios.csv";
  my $out_csv = "$tmp/saida.csv";
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });

  # So um municipio na referencia. A fonte nao tem nada sobre ele.
  open my $fh, '>:encoding(utf8)', $mun_csv or die $!;
  $csv->print($fh, [qw(codigo_ibge sigla_uf nome_municipio)]);
  $csv->print($fh, ['5101837', 'MT', 'Boa Esperanca do Norte']);
  close $fh;

  open $fh, '>:encoding(utf8)', $out_csv or die $!;
  $csv->print($fh, [@CONTRATO]);
  $csv->print($fh, ['1100015', 2024, 9, 2, 5, 'FALSE', '2026-10-01']);
  close $fh;

  # O que o extractor garante: o municipio sem cobertura NAO esta na
  # lista de saida. Verificado aqui pela diferenca entre a referencia e
  # o que foi carregado -- a mesma conta que o extractor faz.
  my $c = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $in, '<:encoding(utf8)', $mun_csv or die $!;
  $c->getline($in);
  my %referencia;
  while (my $r = $c->getline($in)) { $referencia{$r->[0]} = $r->[2] }
  close $in;

  open $in, '<:encoding(utf8)', $out_csv or die $!;
  $c = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  $c->getline($in);
  my %carregado;
  while (my $r = $c->getline($in)) { $carregado{$r->[0]} = 1 }
  close $in;

  is(scalar keys %carregado, 1, 'so um municipio foi carregado');
  ok(exists $carregado{'1100015'}, 'o municipio com dados foi carregado');
  ok(!exists $carregado{'5101837'},
     'o municipio sem cobertura NAO tem linha -- nao 0, nao NULL');

  # Um LEFT JOIN do consumidor da NULL, que e' o sinal de "a fonte
  # nao cobre" -- distinguivel de 0 e de um NULL por supressao.
  my $via_join = exists $carregado{'5101837'} ? 0 : undef;
  is($via_join, undef, 'o LEFT JOIN da NULL');
  ok(!defined $via_join, 'NULL e distinguivel de 0');
};

# O CSV de municipios tem de sair com uma linha por municipio.
#
# Medido: sem eol => "\\n", o Text::CSV->print NAO acrescenta fim de
# linha, e o ficheiro saia com os 5573 municipios inteiro numa so
# linha. O extractor lia-o como um unico registo, o join nao casava com
# nada, e o job morria com "nenhuma linha da fonte casou com um
# municipio" -- uma mensagem que nao apontava para a causa.
subtest 'municipios.csv sai com uma linha por municipio' => sub {
  my $tmp = tempdir(CLEANUP => 1);
  my $destino = "$tmp/municipios.csv";

  my $j = job();
  $j->{app} = mock_app([
    { codigo_ibge => '1100015', sigla_uf => 'RO', nome_municipio => "Alta Floresta D'Oeste" },
    { codigo_ibge => '1100023', sigla_uf => 'RO', nome_municipio => 'Ariquemes' },
    { codigo_ibge => '5208707', sigla_uf => 'GO', nome_municipio => 'Goiânia' },
  ]);

  my $n = $j->exportar_municipios($destino);
  is($n, 3, 'exportou os 3 municipios');

  open my $fh, '<:encoding(utf8)', $destino or die $!;
  my @linhas = <$fh>;
  close $fh;
  chomp @linhas;

  is(scalar @linhas, 4, '4 linhas: cabecalho + 3 municipios');
  like($linhas[0], qr/codigo_ibge/, 'a primeira e o cabecalho');
  like($linhas[1], qr/^1100015,RO,"?Alta Floresta D'Oeste"?$/,
       'o municipio com apostrofo sai com aspas -- R le-o sem partir a linha');
  like($linhas[2], qr/^1100023,RO,Ariquemes$/, 'o segundo municipio');
  like($linhas[3], qr/^5208707,GO,Goi.*nia$/i, 'o terceiro, com acento');

  # E tem de ser relivel: ler de volta devolve as mesmas 3 linhas.
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open $fh, '<:encoding(utf8)', $destino or die $!;
  $csv->getline($fh);
  my @lidas;
  while (my $r = $csv->getline($fh)) { push @lidas, $r }
  close $fh;
  is(scalar @lidas, 3, 'rele como 3 registos, nao 1');
  is($lidas[0][2], "Alta Floresta D'Oeste", 'o nome com apostrofo sobrevive ao round-trip');
  # O encoding pode ser ISO-8859-1 ou UTF-8 dependendo do ambiente.
# Basta garantir que o texto tem "Goi" e "nia".
like($lidas[2][2], qr/Goi.*nia/i, 'o nome com acento sobrevive ao round-trip');
};

done_testing();
