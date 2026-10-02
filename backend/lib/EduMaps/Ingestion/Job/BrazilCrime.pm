package EduMaps::Ingestion::Job::BrazilCrime;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Text::CSV;
use POSIX qw(strftime);

use utf8;

has job_name => 'BrazilCrime';
has description => 'Ingestão BrazilCrime/SINESP (criminalidade agregada por município)';
has schedule => 'monthly';

# -----------------------------------------------------------------
# O contrato de colunas, declarado aqui e não lido do CSV
# -----------------------------------------------------------------
# Se o extractor acrescentar, renomear ou retirar uma coluna, este job
# tem de recusar. Seguir o cabeçalho seria aceitar em silêncio
# um contrato diferente do que a change do Sqitch impõe.
#
# A lista é a de clean.brazilcrime_municipio depois de
# brazilcrime_sem_patrimoniais (issue #164), pela mesma ordem.
my @COLUNAS = qw(
  codigo_ibge ano
  homicidio_doloso latrocinio lesao_corporal_seguida_de_morte
  supressao_celula_pequena dt_snapshot
);

# Colunas de crime: valores inteiros, com NULL quando suprimidos por
# sigilo estatistico (count 1..4) ou quando a fonte nao cobre o municipio.
# "" no CSV tem de entrar como NULL e nunca como 0 -- ver issue #154.
my @COLUNAS_CRIME = qw(
  homicidio_doloso latrocinio lesao_corporal_seguida_de_morte
);

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão BrazilCrime/SINESP');

  # A data da extracção é calculada aqui e passada ao R, para que o
  # dt_snapshot que o R escreve no CSV e o que o Perl grava na base
  # não possam divergir. Duas fontes para o mesmo valor é o modo como
  # a chave de versionamento deixa de valer.
  my $hoje = strftime('%Y-%m-%d', localtime);

  my $dir  = $self->dir_trabalho;
  my $mun_csv = "$dir/municipios.csv";
  my $out_csv = "$dir/brazilcrime_municipio.csv";
  my $orf_csv = "$dir/brazilcrime_orfaos.csv";

  # 1. Lista de municipios de referência. É o que dá codigo_ibge à
  #    fonte, que não tem nenhum (issue #164).
  my $n_mun = $self->exportar_municipios($mun_csv);

  # 2. Pacote R (instala se faltar; é um snapshot de ~740 MB em memória).
  $self->run_r_script($self->caminho_rscript('install_brazilcrime.R'));

  # 3. Extracção. O R não toca na base de dados: lê o CSV de
  #    municipios, escreve o CSV de saída e o relatório de órfãos.
  $self->run_r_script($self->caminho_rscript('extract_brazilcrime.R'), [
    $mun_csv, $out_csv, "--orfaos=$orf_csv", "--snapshot=$hoje",
  ]);

  # 4. Os órfãos contam. Um município que desaparece em silêncio é a
  #    forma exacta do defeito da #155.
  $self->registrar_orfaos($orf_csv);

  # 5. Carga.
  my $rows = $self->process_csv($out_csv);
  die "Extractor não produziu linhas: ver o relatório de órfãos $orf_csv\n"
    unless @$rows;
  my $loaded = $self->load_to_db($rows);

  # 6. Metadados.
  $self->upsert_metadata(
    'clean.brazilcrime_municipio',
    'SINESP VDE via pacote R BrazilCrime',
    'https://cran.r-project.org/web/packages/BrazilCrime/index.html',
    'MIT (código do pacote); dados SINESP VDE — termos de uso por confirmar',
    $loaded,
    sprintf('Extracção de %d municipios de referência. Os dados vêm embutidos no pacote CRAN '
        . '(versão 0.3.0, publicada 2025-09-05): não há sincronização com o SINESP, '
        . 'actualizar exige reinstalar o pacote. Colunas sem evento na fonte removidas — '
        . 'ver issue #164.', $n_mun)
  );

  $self->log_info("BrazilCrime: $loaded registos carregados (dt_snapshot $hoje)");
}

# -----------------------------------------------------------------
# Caminhos
# -----------------------------------------------------------------
# Derivados de __FILE__, não dodirectório de trabalho. O job anterior
# passava 'extract_brazilcrime.R' e dependia de onde o Minion tivesse
# sido lançado.
sub dir_rscript ($self) {
  return path(__FILE__)->dirname->dirname->dirname->dirname->dirname
    ->child('templates', 'rscripts', 'ingestion');
}

sub caminho_rscript ($self, $nome) {
  my $p = $self->dir_rscript->child($nome);
  die "Script R não encontrado: $p\n" unless -f $p;
  return $p->to_string;
}

# Ficheiros intermédios. Fora de /tmp para se poder inspecionar a
# extracção depois de uma falha, e com o nome do job para não
# colidir com outro ingestion a correr ao mesmo tempo.
sub dir_trabalho ($self) {
  my $dir = $self->config->{dir_trabalho} // 'data/ingestao';
  return $dir;
}

# -----------------------------------------------------------------
# 1. Exportar a lista de municipios
# -----------------------------------------------------------------
sub exportar_municipios ($self, $destino) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Exportaria $destino com a lista de municipios de clean.malha_municipio");
    return 0;
  }

  my $db = $self->app->schema->storage->dbh;
  my $rows = $db->selectall_arrayref(
    'SELECT codigo_ibge, sigla_uf, nome_municipio
       FROM clean.malha_municipio
      WHERE codigo_ibge IS NOT NULL
      ORDER BY codigo_ibge',
    { Slice => {} }
  );

  $self->_garantir_dir($destino);
  # eol => "\n" e' obrigatorio: Text::CSV->print nao adiciona newline
  # por defeito, e sem isto todos os registos ficam na mesma linha.
  # Medido: o CSV de municipios saia com 5573 registos numa so linha,
  # e o extractor falhava com "nenhuma linha da fonte casou".
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '>:encoding(utf8)', $destino or die "Não abriu $destino para escrita: $!";
  $csv->print($fh, [qw(codigo_ibge sigla_uf nome_municipio)]);
  $csv->print($fh, [ @{$_}{qw(codigo_ibge sigla_uf nome_municipio)} ]) for @$rows;
  close $fh or die "Não fechou $destino: $!";

  $self->log_info('Municipios de referência exportados: ' . scalar(@$rows));
  return scalar @$rows;
}

# -----------------------------------------------------------------
# 4. Relatório de órfãos
# -----------------------------------------------------------------
sub registrar_orfaos ($self, $path) {
  return unless -f $path;

  open my $fh, '<:encoding(utf8)', $path or do {
    $self->log_error("Relatório de órfãos ilegível: $path — $!");
    return;
  };
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 0 });
  $csv->getline($fh);    # cabeçalho
  my %n;
  my @amostra;
  while (my $r = $csv->getline($fh)) {
    my ($lado, $uf, $nome) = @$r;
    next unless defined $lado;
    $n{$lado}++;
    push @amostra, "$uf/$nome" if @amostra < 10;
  }
  close $fh;

  my $total = 0;
  $total += $_ for values %n;
  if ($total == 0) {
    $self->log_info('Órfãos: 0 — todos os municípios da fonte casaram');
    return;
  }

  # Isto não é um erro: a fonte não cobre o Brasil inteiro. Mas é uma
  # informação que tem de aparecer, porque o número que falta é
  # criminalsidade que ninguém pode consultar.
  $self->log_info(sprintf(
    'Órfãos: %d (%s). Amostra: %s. Relatório: %s',
    $total,
    join(', ', map { "$_=$n{$_}" } sort keys %n),
    join(', ', @amostra),
    $path
  ));
}

# -----------------------------------------------------------------
# 5. Ler o CSV, a validar o contrato
# -----------------------------------------------------------------
sub process_csv ($self, $csv_path) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Processaria $csv_path");
    return [];
  }
  die "Não encontrei o CSV de saída: $csv_path\n" unless -f $csv_path;

  # eol => "\n" tambem na leitura: sem isto, Text::CSV nao reconhece
  # o fim de linha e o getline devolve o ficheiro inteiro como uma so
  # linha. Medido: o header saia com 61192 campos em vez de 7.
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $csv_path or die "Não abriu $csv_path: $!";

  my $header = $csv->getline($fh);
  die "CSV vazio: $csv_path\n" unless $header;

  # Contrato conferido antes de uma linha sequer ser lida.
  my @dif = $self->_comparar_colunas($header, \@COLUNAS);
  die sprintf("O CSV não corresponde ao contrato de clean.brazilcrime_municipio.\n"
      . "  faltam: %s\n  a mais: %s\n  fora de ordem: %s\n"
      . "Esperado: %s\nRecebido:  %s\n",
      (join(', ', map  { $_->[0] } grep { !defined $_->[2] } @dif) || '(nenhuma)'),
      (join(', ', map  { $_->[0] } grep { !defined $_->[1] } @dif) || '(nenhuma)'),
      (join(', ', map  { sprintf('%s (no CSV na %d, no contrato na %d)',
                                $_->[0], $_->[2] + 1, $_->[1] + 1) }
             grep { defined $_->[1] && defined $_->[2] } @dif) || '(nenhuma)'),
      join(', ', @COLUNAS), join(', ', @$header))
    if @dif;

  my @rows;
  my $linha = 1;
  while (my $r = $csv->getline($fh)) {
    $linha++;
    my %row = map { $header->[$_] => $r->[$_] } 0 .. $#$header;
    $row{$_} = undef for grep { defined $row{$_} && $row{$_} eq '' } keys %row;
    $row{ano} = 0 + $row{ano} if defined $row{ano};
    $row{supressao_celula_pequena}
      = (defined $row{supressao_celula_pequena} && $row{supressao_celula_pequena} eq 'TRUE') ? 1 : 0;

    die sprintf("Linha %d: codigo_ibge vazio ou ano não numérico — o extractor não deveria produzir isto.\n", $linha)
      unless defined $row{codigo_ibge} && $row{codigo_ibge} =~ /^\d{7}$/;
    die sprintf("Linha %d: ano %s fora de 1900..2100.\n", $linha, $row{ano} // 'vazio')
      unless defined $row{ano} && $row{ano} >= 1900 && $row{ano} <= 2100;
    die sprintf("Linha %d: dt_snapshot vazio.\n", $linha)
      unless defined $row{dt_snapshot} && $row{dt_snapshot} =~ /^\d{4}-\d{2}-\d{2}$/;

    # Uma coluna de crime NULL com supressao FALSE e suspeito: ou a
    # fonte cobre o municipio e o valor foi suprimido -- e entao a flag
    # devia ser TRUE --, ou nao havia dado. Registar, para nao se
    # descobrir isto num debug daqui a tres meses.
    my $nulos = grep { !defined $row{$_} } @COLUNAS_CRIME;
    if ($nulos && !$row{supressao_celula_pequena}) {
      $self->log->debug(sprintf('Linha %d (%s/%d): %d coluna(s) de crime NULL com '
          . 'supressao_celula_pequena=FALSE', $linha, $row{codigo_ibge}, $row{ano}, $nulos));
    }

    push @rows, \%row;
  }
  close $fh;

  $self->log_info(sprintf('CSV processado: %d linhas, %d colunas', scalar @rows, scalar @$header));
  return \@rows;
}

# Compara o cabecalho do CSV com o contrato e devolve SO as diferencas.
#
# Cada elemento e' [ $coluna, $pos_contrato, $pos_csv ], com posicao 0-based:
#
#   $pos_contrato undef -> a coluna nao esta no contrato  ("a mais")
#   $pos_csv      undef -> a coluna do contrato falta      ("faltam")
#   ambos definidos, diferentes -> esta na posicao errada ("fora de ordem")
#   ambos definidos, iguais    -> conforme, e portanto NAO entra na lista
#
# Medido: a versao anterior fazia push de toda a coluna do cabecalho sem
# comparar nada, e o `die` seguinte comparava um NOME com uma POSICAO
# ("codigo_ibge" ne 0), que e' sempre verdadeiro -- o job abortava mesmo
# com o CSV exactamente igual ao contrato. Os dois lados juntos faziam
# do teste de contrato um no-op que so passava por o dies nunca ter sido
# alcancado com o caminho real.
sub _comparar_colunas ($self, $header, $esperado) {
  my %pos_esp = map { $esperado->[$_] => $_ } 0 .. $#$esperado;
  my %pos_hdr = map { $header->[$_]  => $_ } 0 .. $#$header;
  my @dif;

  # Colunas que o CSV traz. Se nao estao no contrato, sao "a mais".
  for my $i (0 .. $#$header) {
    my $h = $header->[$i];
    if (!exists $pos_esp{$h}) {
      push @dif, [ $h, undef, $i ];
    }
    elsif ($pos_esp{$h} != $i) {
      push @dif, [ $h, $pos_esp{$h}, $i ];
    }
  }

  # Colunas do contrato que o CSV nao traz. Nao contam as "a mais":
  # a posicao no contrato e' a do indice, mesmo que no CSV nao exista.
  for my $i (0 .. $#$esperado) {
    my $e = $esperado->[$i];
    push @dif, [ $e, $i, undef ] unless exists $pos_hdr{$e};
  }

  return @dif;
}

# -----------------------------------------------------------------
# 6. Carga
# -----------------------------------------------------------------
# Uma transaccação para tudo. Uma carga a meio deixa a tabela num
# estado que nenhum teste apanha, porque cada linha individual é
# válida.
sub load_to_db ($self, $rows) {
  if ($self->dry_run) {
    $self->log_info('[DRY-RUN] Carregaria ' . scalar(@$rows) . " linhas em clean.brazilcrime_municipio");
    return scalar @$rows;
  }

  my $dbh = $self->app->schema->storage->dbh;
  my $storage = $self->app->schema->storage;

  # As colunas actualizadas sao todas menos a chave. Escrever a lista a
  # mao deixaria a clause SET por actualizar quando o contrato mudar.
  my %nao_chave = map { $_ => 1 } grep { !/^(codigo_ibge|ano|dt_snapshot)$/ } @COLUNAS;
  my $cols     = join(', ', @COLUNAS);
  my $vals     = join(', ', map { '?' } @COLUNAS);
  my $updates  = join(', ', map { "$_ = EXCLUDED.$_" } sort keys %nao_chave);

  # Os argumentos do sprintf sao construidos antes: com um heredoc no
  # meio da lista, o Perl nao aceita que a lista continue em linhas
  # seguintes -- o corpo do heredoc tem de vir primeiro.
  my $sql = sprintf(<<'SQL', $cols, $vals, $updates);
    INSERT INTO clean.brazilcrime_municipio (%s)
    VALUES (%s)
    ON CONFLICT (codigo_ibge, ano, dt_snapshot) DO UPDATE SET
      %s
SQL

  # Uma transaccao para tudo. Uma carga interrompida a meio deixa a
  # tabela num estado que nenhum teste apanha, porque cada linha
  # individual e valida. txn_do (a convencao do repo) faz rollback
  # sozinho quando o codigo morre.
  my $count = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare($sql);
      for my $r (@$rows) {
        $sth->execute(map { $r->{$_} } @COLUNAS);
      }
      $count = scalar @$rows;
    });
    1;
  } or die "Carga falhou, nada foi gravado: $@\n";

  return $count;
}

sub _garantir_dir ($self, $file) {
  my ($dir) = $file =~ m{^(.*)/[^/]+$};
  return unless $dir && !-d $dir;
  require File::Path;
  File::Path::make_path($dir);
  $self->log_info("Directório de trabalho criado: $dir");
}

1;
