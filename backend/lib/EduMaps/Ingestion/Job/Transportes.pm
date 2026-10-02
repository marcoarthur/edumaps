package EduMaps::Ingestion::Job::Transportes;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(decode_json);
use Text::CSV;
use POSIX qw(strftime);
use utf8;

has job_name => 'Transportes';
has description => 'Ingestão RENAVAM frota + RENAEST sinistros';
has schedule => 'monthly';

# =================================================================
# Fontes medidas em 2026-10-02 (issue #169)
#
# RENAEST  https://dados.transportes.gov.br/dataset/renaest
#   ZIP mensal `renaest_dabertos_<YYYYMMDD>.zip` com 4 CSVs:
#     Acidentes_*.csv, Localidade_*.csv, TipoVeiculo_*.csv, Vitimas_*.csv
#   `Localidade` traz `codigo_ibge` e `municipio` (nome). O campo
#   `chv_localidade` é <uf><codigo_ibge><yyyy><mm>, isto é, uma chave
#   MENSAL — não é um nome de localidade. O nome que a tabela de-para
#   guarda é o campo `municipio`.
#
# RENAVAM  https://dados.transportes.gov.br/dataset/
#          registro-nacional-de-veiculos-automotores-renavam
#   NÃO existe o dataset `frota-por-municipio` referido no COMMENT das
#   migrations. A frota publicada é por marca/modelo/ano-de-fabricação,
#   com o município por NOME e a UF por NOME de estado. Não há a
#   quebra por tipo de veículo. Decisão do developer (#169): carregar
#   só `total_frota`; as 10 colunas de tipo ficam NULL.
# =================================================================

# UF por nome, como a RENAVAM publica (maiúsculas, sem acento).
my %UF_POR_NOME = (
  'ACRE'               => 'AC', 'ALAGOAS'             => 'AL',
  'AMAPA'              => 'AP', 'AMAZONAS'            => 'AM',
  'BAHIA'              => 'BA', 'CEARA'               => 'CE',
  'DISTRITO FEDERAL'   => 'DF', 'ESPIRITO SANTO'      => 'ES',
  'GOIAS'              => 'GO', 'MARANHAO'            => 'MA',
  'MATO GROSSO'        => 'MT', 'MATO GROSSO DO SUL'  => 'MS',
  'MINAS GERAIS'       => 'MG', 'PARA'                => 'PA',
  'PARAIBA'            => 'PB', 'PARANA'              => 'PR',
  'PERNAMBUCO'         => 'PE', 'PIAUI'               => 'PI',
  'RIO DE JANEIRO'     => 'RJ', 'RIO GRANDE DO NORTE' => 'RN',
  'RIO GRANDE DO SUL'  => 'RS', 'RONDONIA'            => 'RO',
  'RORAIMA'            => 'RR', 'SANTA CATARINA'      => 'SC',
  'SAO PAULO'          => 'SP', 'SERGIPE'             => 'SE',
  'TOCANTINS'          => 'TO',
);

# Sentinelas que a fonte usa e que nunca podem virar município. A
# RENAEST publica `codigo_ibge = 0`; a RENAVAM publica UF
# "Não Identificado" / "Não se Aplica" / "Sem Informação". Um
# sentinela que chega à base é o modo exacto do defeito da #164.
my %CODIGO_SENTINELA = ('0' => 1, '0000000' => 1, '' => 1);

# Colunas de que o job precisa. NÃO se exige o contrato exacto: a fonte
# é grande e acrescenta colunas entre versões. O que se exige é que
# estas não faltem — sem elas o job tem de recusar, não adivinhar.
my @ACIDENTES_NEC = qw(
  chv_localidade data_acidente uf_acidente codigo_ibge
  qtde_obitos qtde_envolvidos
);
my @LOCALIDADE_NEC = qw(
  chv_localidade uf codigo_ibge municipio
);
my @RENAVAM_NEC = ("UF", "Município", "Qtd. Veículos");

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão Transportes (RENAVAM + RENAEST)');

  # O de-para vem do mesmo ficheiro Localidade que dá o nome aos
  # sinistros: uma só leitura, uma só verdade sobre o que é uma
  # "localidade" (#169, decisão 3).
  my $localidade = $self->ler_localidade($self->caminho_localidade);

  $self->ingerir_depara($localidade);
  $self->ingerir_sinistros($self->caminho_acidentes, $localidade);
  $self->ingerir_frota($self->caminho_renavam);

  $self->log_info('Transportes: ingestão concluída');
}

# -----------------------------------------------------------------
# Normalização e similaridade
# -----------------------------------------------------------------
# Remove acento, baixa a caixa e reduz pontuação a espaço. É a mesma
# régua para os dois lados de qualquer comparação de nomes, senão
# "Olho d'Água" e "OLHO D AGUA" nunca casariam.
sub normalizar ($self, $texto) {
  return '' unless defined $texto;
  $texto = lc $texto;
  $texto =~ s/[áàâãä]/a/g; $texto =~ s/[éèêë]/e/g;
  $texto =~ s/[íìîï]/i/g;  $texto =~ s/[óòôõö]/o/g;
  $texto =~ s/[úùûü]/u/g;  $texto =~ s/ç/c/g;
  $texto =~ s/[^a-z0-9]+/ /g;
  $texto =~ s/^\s+|\s+$//g;
  $texto =~ s/\s+/ /g;
  return $texto;
}

# Distância de Levenshtein clássica (O(n*m)); os nomes de município
# são curtos e não justificam dependência externa.
sub _levenshtein ($a, $b) {
  my @a = split //, $a;
  my @b = split //, $b;
  my @prev = (0 .. scalar @b);
  for my $i (1 .. scalar @a) {
    my @cur = ($i);
    for my $j (1 .. scalar @b) {
      my $custo = ($a[$i - 1] eq $b[$j - 1]) ? 0 : 1;
      my $menor = $prev[$j] + 1;
      $menor = $cur[ $j - 1 ] + 1 if $cur[ $j - 1 ] + 1 < $menor;
      $menor = $prev[ $j - 1 ] + $custo if $prev[ $j - 1 ] + $custo < $menor;
      $cur[$j] = $menor;
    }
    @prev = @cur;
  }
  return $prev[-1];
}

# Score 0-100 entre dois textos já normalizados. 100 = idênticos.
sub similaridade ($self, $a, $b) {
  my $na = $self->normalizar($a);
  my $nb = $self->normalizar($b);
  return 100 if $na eq $nb;
  my $max = length($na) > length($nb) ? length($na) : length($nb);
  return 0 unless $max;
  my $d = _levenshtein($na, $nb);
  my $score = (1 - $d / $max) * 100;
  $score = 0 if $score < 0;
  return sprintf('%.2f', $score);
}

# -----------------------------------------------------------------
# Índice da malha: é o que dá codigo_ibge a quem só traz nome
# -----------------------------------------------------------------
sub _indice_malha ($self) {
  my $db = $self->app->schema->storage->dbh;
  my $rows = $db->selectall_arrayref(
    'SELECT codigo_ibge, sigla_uf, nome_municipio FROM clean.malha_municipio',
    { Slice => {} }
  );
  my (%por_codigo, %por_nome);
  for my $r (@$rows) {
    $por_codigo{ $r->{codigo_ibge} } = $r;
    my $chave = $self->normalizar($r->{sigla_uf}) . '|'
              . $self->normalizar($r->{nome_municipio});
    $por_nome{$chave} //= $r->{codigo_ibge};
  }
  return { por_codigo => \%por_codigo, por_nome => \%por_nome };
}

# -----------------------------------------------------------------
# Localidade: uma leitura que produz o de-para e o índice de nomes
# -----------------------------------------------------------------
# Devolve { nome_por_codigo => { codigo => {uf, municipio} },
#           registros       => [ {localidade, uf, codigo_ibge, municipio}, ... ],
#           estatisticas    => { linhas, sentinelas, sem_codigo } }
sub ler_localidade ($self, $csv_path) {
  die "RENAEST Localidade não encontrado: $csv_path\n"
    unless defined $csv_path && -f $csv_path;

  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $csv_path or die "Não abriu $csv_path: $!\n";
  my $header = $csv->getline($fh);
  die "CSV Localidade vazio: $csv_path\n" unless $header;
  $header->[0] =~ s/^\x{FEFF}//;    # BOM defensivo
  $self->_exigir_colunas($header, \@LOCALIDADE_NEC, 'RENAEST Localidade');

  my %idx_h = map { $header->[$_] => $_ } 0 .. $#$header;
  my (%nome_por_codigo, %visto, @registros);
  my $linhas = 0;
  my $sentinelas = 0;
  my $sem_codigo = 0;

  while (my $r = $csv->getline($fh)) {
    $linhas++;
    my $codigo = $r->[ $idx_h{codigo_ibge} ];
    $codigo =~ s/\s+//g if defined $codigo;
    my $uf     = $r->[ $idx_h{uf} ];
    my $nome   = $r->[ $idx_h{municipio} ];
    $uf   =~ s/\s+//g if defined $uf;
    $nome =~ s/^\s+|\s+$//g if defined $nome;

    if (!defined $codigo || $CODIGO_SENTINELA{$codigo}) { $sentinelas++; next }
    if (!defined $nome || $nome eq '' || !defined $uf || $uf eq '') { $sem_codigo++; next }

    $nome_por_codigo{$codigo} = { uf => $uf, municipio => $nome };

    # O de-para é por (nome, uf): deduplica as 12 linhas mensais.
    my $chave = "$uf|" . $self->normalizar($nome);
    next if $visto{$chave}++;
    push @registros, { localidade => $nome, uf => $uf, codigo_ibge => $codigo };
  }
  close $fh;

  $self->log_info(sprintf(
    'RENAEST Localidade: %d linhas, %d municípios distintos, %d sentinelas (ignorados), %d sem nome/UF',
    $linhas, scalar(keys %nome_por_codigo), $sentinelas, $sem_codigo));

  return {
    nome_por_codigo => \%nome_por_codigo,
    registros       => \@registros,
    estatisticas    => { linhas => $linhas, sentinelas => $sentinelas, sem_codigo => $sem_codigo },
  };
}

# -----------------------------------------------------------------
# Acidentes -> sinistros agregados por localidade/UF/dia
# -----------------------------------------------------------------
# O UNIQUE de clean.renaest_sinistro é (localidade, uf, data_sinistro,
# dt_snapshot): o grão é localidade/dia, não acidente. Agregar aqui é o
# que torna a carga idempotente e não deixa um acidente apagar o outro.
#
# Só `mortos` e `veiculos_envolvidos` são avaliáveis a partir de
# Acidentes. O breakdown de feridos exige o CSV Vitimas (1,8 GB) —
# decisão do developer (#169, decisão 2): fica NULL.
sub agregar_acidentes ($self, $csv_path, $localidade) {
  die "RENAEST Acidentes não encontrado: $csv_path\n"
    unless defined $csv_path && -f $csv_path;

  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $csv_path or die "Não abriu $csv_path: $!\n";
  my $header = $csv->getline($fh);
  die "CSV Acidentes vazio: $csv_path\n" unless $header;
  $header->[0] =~ s/^\x{FEFF}//;
  $self->_exigir_colunas($header, \@ACIDENTES_NEC, 'RENAEST Acidentes');

  my %idx = map { $header->[$_] => $_ } 0 .. $#$header;
  my %nome = %{ $localidade->{nome_por_codigo} };

  my %agg;            # "codigo|data" => { ... }
  my $linhas = 0;
  my $sem_codigo = 0;
  my $sem_nome = 0;

  while (my $r = $csv->getline($fh)) {
    $linhas++;
    my $codigo = $r->[ $idx{codigo_ibge} ];
    $codigo =~ s/\s+//g if defined $codigo;
    my $data = $r->[ $idx{data_acidente} ];
    my $uf   = $r->[ $idx{uf_acidente} ];
    $uf =~ s/\s+//g if defined $uf;

    if (!defined $codigo || $CODIGO_SENTINELA{$codigo} || !defined $data || $data eq '') {
      $sem_codigo++;
      next;
    }

    my $ref = $nome{$codigo};
    if (!$ref) {
      # Sem nome no de-para não há como satisfazer localidade NOT NULL.
      # Conta e segue — não é um erro fatal, mas tem de aparecer.
      $sem_nome++;
      next;
    }

    my ($obitos, $envolvidos) = (
      $self->_inteiro($r->[ $idx{qtde_obitos} ]),
      $self->_inteiro($r->[ $idx{qtde_envolvidos} ]),
    );

    my $chave = "$codigo|$data";
    my $a = ($agg{$chave} //= {
      codigo_ibge => $codigo,
      uf          => $ref->{uf},
      localidade  => $ref->{municipio},
      data        => $data,
      mortos      => 0,
      veiculos    => 0,
    });
    $a->{mortos}   += $obitos;
    $a->{veiculos} += $envolvidos;
  }
  close $fh;

  $self->log_info(sprintf(
    'RENAEST Acidentes: %d linhas, %d localidade/dia agregados, %d linhas sem código utilizável, %d sem nome no de-para',
    $linhas, scalar(keys %agg), $sem_codigo, $sem_nome));

  return {
    rows => [ map { +{
      localidade => $agg{$_}{localidade},
      uf         => $agg{$_}{uf},
      data       => $agg{$_}{data},
      mortos     => $agg{$_}{mortos},
      veiculos   => $agg{$_}{veiculos},
      codigo_ibge => $agg{$_}{codigo_ibge},
    } } sort keys %agg ],
    estatisticas => { linhas => $linhas, sem_codigo => $sem_codigo, sem_nome => $sem_nome },
  };
}

sub _inteiro ($self, $valor) {
  return 0 unless defined $valor;
  $valor =~ s/^\s+|\s+$//g;
  return 0 if $valor eq '';
  return 0 unless $valor =~ /^\d+(?:[.,]\d+)?$/;
  $valor =~ s/,/./;
  return int($valor + 0.5);
}

# -----------------------------------------------------------------
# RENAVAM -> frota total por município
# -----------------------------------------------------------------
# Só o total é derivável; a quebra por tipo não existe na fonte. As
# colunas de tipo entram NULL. Município cuja UF é sentinela ou cujo
# nome não casa com a malha é CONTADO e registado, nunca descartado em
# silêncio.
sub agregar_renavam ($self, $txt_path) {
  die "RENAVAM frota não encontrado: $txt_path\n"
    unless defined $txt_path && -f $txt_path;

  my $malha = $self->_indice_malha;

  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $txt_path or die "Não abriu $txt_path: $!\n";
  my $header = $csv->getline($fh);
  die "RENAVAM TXT vazio: $txt_path\n" unless $header;
  $header->[0] =~ s/^\x{FEFF}//;
  $self->_exigir_colunas($header, \@RENAVAM_NEC, 'RENAVAM frota');

  my %idx = map { $header->[$_] => $_ } 0 .. $#$header;
  my %total;        # codigo_ibge => soma
  my $linhas = 0;
  my $uf_sentinela = 0;
  my $sem_municipio = 0;
  my %ufs_sem_casa;
  my %orfaos;       # "UF/Nome" => linhas

  while (my $r = $csv->getline($fh)) {
    $linhas++;
    my $uf_nome = $r->[ $idx{'UF'} ];
    my $municipio = $r->[ $idx{"Município"} ];
    my $qtd = $r->[ $idx{"Qtd. Veículos"} ];
    $uf_nome  =~ s/^\s+|\s+$//g if defined $uf_nome;
    $municipio =~ s/^\s+|\s+$//g if defined $municipio;

    my $uf = $UF_POR_NOME{ uc($self->normalizar($uf_nome // '')) };
    if (!$uf) {
      $uf_sentinela++;
      $ufs_sem_casa{$uf_nome // '?'}++;
      next;
    }

    my $chave = $self->normalizar($uf) . '|' . $self->normalizar($municipio);
    my $codigo = $malha->{por_nome}{$chave};
    if (!$codigo) {
      $sem_municipio++;
      # Um par (UF, município) que não casa é a unidade accionável. Só
      # o total de linhas não diz QUAL município desapareceu, e é o
      # nome que alguém tem de corrigir.
      $orfaos{"$uf/$municipio"}++;
      next;
    }

    $total{$codigo} += $self->_inteiro($qtd);
  }
  close $fh;

  $self->log_info(sprintf(
    'RENAVAM: %d linhas, %d municípios com frota, %d linhas de UF sentinela (%s), %d linhas (%d pares) sem município na malha',
    $linhas, scalar(keys %total), $uf_sentinela,
    join(', ', map { "$_=$ufs_sem_casa{$_}" } sort { $ufs_sem_casa{$b} <=> $ufs_sem_casa{$a} } keys %ufs_sem_casa),
    $sem_municipio, scalar(keys %orfaos)));

  return {
    rows => [ map { { codigo_ibge => $_, total_frota => $total{$_} } }
              sort { $total{$b} <=> $total{$a} } keys %total ],
    orfaos => \%orfaos,
    estatisticas => {
      linhas => $linhas,
      uf_sentinela => $uf_sentinela,
      sem_municipio => $sem_municipio,
      pares_sem_casa => scalar(keys %orfaos),
      municipios => scalar(keys %total),
    },
  };
}

# Relatório de municípios que a fonte publica e a malha não reconhece.
#
# Medido em 2026-08: 111 173 linhas de 22 690 877 caem em 33 pares
# (UF, município). A causa não é a fonte estar errada em bloco — são
# grafias que divergem dos dois lados ("MUNHOZ DE MELLO" vs "Munhoz de
# Melo", "BARAO D0 MONTE ALTO" com zero no lugar do "O", e a malha que
# guarda "Sant'Ana do Livramento" para o município que a RENAVAM
# escreve "SANTANA DO LIVRAMENTO"). Sem este ficheiro, o número "0,5%
# descartado" não diz a ninguém o que fazer.
sub registrar_orfaos_renavam ($self, $orfaos) {
  my $total = 0;
  $total += $_ for values %$orfaos;

  if (!$total) {
    $self->log_info('Órfãos RENAVAM: 0 — todos os municípios da fonte casaram com a malha');
    return 0;
  }

  my @top = sort { $orfaos->{$b} <=> $orfaos->{$a} } keys %$orfaos;
  $self->log_info(sprintf(
    'Órfãos RENAVAM: %d linhas em %d pares (UF/município). Top %d: %s',
    $total, scalar @top, (scalar(@top) < 10 ? scalar(@top) : 10),
    join(', ', map { "$_=$orfaos->{$_}" } @top[0 .. (scalar(@top) < 10 ? $#top : 9)])));

  if ($self->dry_run) { return $total }

  my $dir = $self->config->{dir_trabalho} // 'data/ingestao';
  require File::Path; File::Path::make_path($dir);
  my $destino = "$dir/renavam_orfaos.csv";
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '>:encoding(utf8)', $destino or do {
    $self->log_error("Não abriu $destino para escrita: $! — contagens só no log");
    return $total;
  };
  $csv->print($fh, [qw(uf_municipio linhas)]);
  $csv->print($fh, [$_, $orfaos->{$_}]) for @top;
  close $fh;
  $self->log_info("Relatório de órfãos RENAVAM: $destino");
  return $total;
}

# -----------------------------------------------------------------
# Carga: de-para
# -----------------------------------------------------------------
sub ingerir_depara ($self, $localidade) {
  my $snapshot = $self->_snapshot('renaest_snapshot');
  my $malha = $self->_indice_malha;
  my $dbh = $self->app->schema->storage->dbh;

  my (@linhas, %contagem);
  for my $reg (@{ $localidade->{registros} }) {
    my $codigo = $reg->{codigo_ibge};
    my $ibge = $malha->{por_codigo}{$codigo};
    if (!$ibge) { $contagem{sem_malha}++; next }

    my $score = $self->similaridade($reg->{localidade}, $ibge->{nome_municipio});
    my $tipo = $score == 100 ? 'exact' : 'fuzzy';
    $contagem{$tipo}++;
    push @linhas, [
      $reg->{localidade}, $reg->{uf}, $codigo, $ibge->{nome_municipio},
      $tipo, $score, $snapshot,
    ];
  }

  if ($self->dry_run) {
    $self->log_info('[DRY-RUN] de-para: ' . scalar(@linhas) . " linhas");
    return scalar @linhas;
  }

  my $storage = $self->app->schema->storage;
  my $count = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare(
        q{INSERT INTO clean.renaest_localidade_municipio
            (localidade, uf, codigo_ibge, nome_municipio, match_type, match_score,
             validated_by, dt_snapshot)
          VALUES (?, ?, ?, ?, ?, ?, 'fonte_renaest', ?)
          ON CONFLICT (localidade, uf, dt_snapshot) DO UPDATE SET
            codigo_ibge   = EXCLUDED.codigo_ibge,
            nome_municipio = EXCLUDED.nome_municipio,
            match_type    = EXCLUDED.match_type,
            match_score   = EXCLUDED.match_score,
            validated_by  = EXCLUDED.validated_by,
            dt_carga      = NOW()});
      $sth->execute(@$_) for @linhas;
      $count = scalar @linhas;
    });
    1;
  } or die "Carga do de-para falhou, nada gravado: $@\n";

  # A semente anterior era uma auto-junção do IBGE (validated_by =
  # 'auto_seed') que nunca viu RENAEST. Depois de haver de-para real,
  # mantê-la seria prometer um cruzamento que não existe. Apaga-se e
  # regista-se quantas saíram (#169).
  my $removidas = $dbh->do(
    q{DELETE FROM clean.renaest_localidade_municipio WHERE validated_by = 'auto_seed'});

  $self->upsert_metadata(
    'clean.renaest_localidade_municipio',
    'RENAEST Localidade_DadosAbertos (CSV)',
    'https://dados.transportes.gov.br/dataset/renaest',
    'CC-BY-4.0 (Ministério dos Transportes)',
    $count,
    sprintf('De-para derivado do ficheiro Localidade real (snapshot %s). match_type=%s; %d sem malha; semente auto_seed removida: %s. %s',
      $snapshot,
      join(', ', map { "$_=$contagem{$_}" } sort keys %contagem),
      $contagem{sem_malha} // 0,
      $removidas,
      'As colunas localidade/nome_municipio distinguem a grafia da fonte da grafia IBGE.'),
  );
  $self->log_info(sprintf('De-para: %d linhas (%s), %s semente(s) auto_seed removida(s)',
    $count, join(', ', map { "$_=$contagem{$_}" } sort keys %contagem), $removidas));
  return $count;
}

# -----------------------------------------------------------------
# Carga: sinistros
# -----------------------------------------------------------------
sub ingerir_sinistros ($self, $acidentes_path, $localidade) {
  my $snapshot = $self->_snapshot('renaest_snapshot');
  my $agregado = $self->agregar_acidentes($acidentes_path, $localidade);
  my $rows = $agregado->{rows};

  if ($self->dry_run) {
    $self->log_info('[DRY-RUN] sinistros: ' . scalar(@$rows) . " linhas");
    return scalar @$rows;
  }

  my $dbh = $self->app->schema->storage->dbh;
  my $storage = $self->app->schema->storage;
  # feridos_graves/feridos_leves/ilesos entram a NULL explícito e não por
  # omissão: a coluna tem DEFAULT 0, e deixar o default trabalhar
  # transforma "não avaliável" em "zero vítimas" — o defeito exacto
  # apontado na #154. Avaliá-los exige o CSV Vitimas (1,8 GB), fora do
  # escopo por decisão do developer (#169, decisão 2).
  my $count = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare(
        q{INSERT INTO clean.renaest_sinistro
            (localidade, uf, data_sinistro, mortos, veiculos_envolvidos,
             feridos_graves, feridos_leves, ilesos, codigo_ibge, dt_snapshot)
          VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?)
          ON CONFLICT (localidade, uf, data_sinistro, dt_snapshot) DO UPDATE SET
            mortos              = EXCLUDED.mortos,
            veiculos_envolvidos = EXCLUDED.veiculos_envolvidos,
            feridos_graves      = NULL,
            feridos_leves       = NULL,
            ilesos              = NULL,
            codigo_ibge         = EXCLUDED.codigo_ibge,
            dt_carga            = NOW()});
      $sth->execute(
        $_->{localidade}, $_->{uf}, $_->{data},
        $_->{mortos}, $_->{veiculos}, $_->{codigo_ibge}, $snapshot,
      ) for @$rows;
      $count = scalar @$rows;
    });
    1;
  } or die "Carga de sinistros falhou, nada gravado: $@\n";

  $self->upsert_metadata(
    'clean.renaest_sinistro',
    'RENAEST Acidentes_DadosAbertos (CSV)',
    'https://dados.transportes.gov.br/dataset/renaest',
    'CC-BY-4.0 (Ministério dos Transportes)',
    $count,
    sprintf('Agregado por localidade/UF/dia (snapshot %s): %d acidentes -> %d linhas. mortos e veiculos_envolvidos de Acidentes. feridos_graves/feridos_leves/ilesos NULL: exigem o CSV Vitimas (1,8 GB), fora do escopo por decisão #169. tipo_sinistro/classificacao NULL: o grão localidade/dia colapsa vários tipos.',
      $snapshot, $agregado->{estatisticas}{linhas}, $count),
  );
  $self->log_info("Sinistros: $count linhas carregadas (dt_snapshot $snapshot)");
  return $count;
}

# -----------------------------------------------------------------
# Carga: frota (só total)
# -----------------------------------------------------------------
sub ingerir_frota ($self, $renavam_path) {
  my $snapshot = $self->_snapshot('renavam_snapshot');
  my $agregado = $self->agregar_renavam($renavam_path);
  my $rows = $agregado->{rows};

  # Antes da carga: o que não entra tem de estar escrito, não contido.
  $self->registrar_orfaos_renavam($agregado->{orfaos});

  # ano/mes derivam do snapshot: o ficheiro é uma fotografia mensal.
  my ($ano, $mes) = $snapshot =~ /^(\d{4})-(\d{2})-/;
  die "renavam_snapshot inválido: $snapshot\n" unless $ano && $mes;
  $ano += 0; $mes += 0;

  if ($self->dry_run) {
    $self->log_info('[DRY-RUN] frota: ' . scalar(@$rows) . " linhas");
    return scalar @$rows;
  }

  my $dbh = $self->app->schema->storage->dbh;
  my $storage = $self->app->schema->storage;
  my $count = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare(
        q{INSERT INTO clean.renavam_frota_municipio
            (codigo_ibge, ano, mes, total_frota, dt_snapshot)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT (codigo_ibge, ano, mes, dt_snapshot) DO UPDATE SET
            total_frota = EXCLUDED.total_frota});
      $sth->execute($_->{codigo_ibge}, $ano, $mes, $_->{total_frota}, $snapshot) for @$rows;
      $count = scalar @$rows;
    });
    1;
  } or die "Carga de frota falhou, nada gravado: $@\n";

  $self->upsert_metadata(
    'clean.renavam_frota_municipio',
    'RENAVAM I_Frota_por_UF_Municipio_Marca_e_Modelo_Ano (TXT)',
    'https://dados.transportes.gov.br/dataset/registro-nacional-de-veiculos-automotores-renavam',
    'Domínio público (Ministério dos Transportes)',
    $count,
    sprintf('Frota total por município (%04d-%02d, snapshot %s), somando Qtd. Veículos por município. Só total_frota: a fonte não publica a quebra por tipo de veículo (o dataset "frota-por-municipio" do COMMENT não existe). Colunas de tipo NULL. %d linhas de UF sentinela; %d linhas em %d pares (UF/município) sem casa na malha — ver renavam_orfaos.csv.',
      $ano, $mes, $snapshot,
      $agregado->{estatisticas}{uf_sentinela},
      $agregado->{estatisticas}{sem_municipio},
      $agregado->{estatisticas}{pares_sem_casa}),
  );
  $self->log_info("Frota: $count municípios carregados ($ano/$mes, dt_snapshot $snapshot)");
  return $count;
}

# -----------------------------------------------------------------
# Descoberta de ficheiros
# -----------------------------------------------------------------
# Config (testes e execução local):
#   renaest_localidade_csv / renaest_acidentes_csv / renavam_txt
#   -> caminhos directos, sem rede.
# Config (execução real):
#   renaest_zip / renavam_zip -> extrai o membro.
sub caminho_localidade ($self) { return $self->_fonte('renaest_localidade_csv', qr/^Localidade_.*\.csv$/i) }
sub caminho_acidentes ($self)  { return $self->_fonte('renaest_acidentes_csv',  qr/^Acidentes_.*\.csv$/i) }
sub caminho_renavam ($self)    { return $self->_fonte('renavam_txt', qr/\.(?:txt|csv)$/i, 1) }

sub _fonte ($self, $chave, $padrao, $renavam = 0) {
  if (my $p = $self->config->{$chave}) {
    die "Ficheiro configurado em $chave não existe: $p\n" unless -f $p;
    return $p;
  }
  my $zip = $renavam ? $self->config->{renavam_zip} : $self->config->{renaest_zip};
  die "Sem $chave nem " . ($renavam ? 'renavam_zip' : 'renaest_zip') . " na config\n"
    unless $zip && -f $zip;
  return $self->_extrair_membro($zip, $padrao);
}

sub _extrair_membro ($self, $zip, $padrao) {
  my $lista = `unzip -Z1 "$zip" 2>/dev/null`;
  my ($membro) = grep { $_ =~ $padrao } split /\n/, $lista;
  die "Nenhum membro casa $padrao em $zip\n" unless $membro;
  my $dir = $self->config->{dir_trabalho} // 'data/ingestao';
  require File::Path; File::Path::make_path($dir);
  my $saida = "$dir/" . (split m{/}, $membro)[-1];
  unless (-f $saida && (stat($saida))[9] >= (stat($zip))[9]) {
    my $rc = system('unzip', '-o', '-q', $zip, $membro, '-d', $dir);
    die "unzip falhou (rc=$rc) para $membro\n" if $rc;
  }
  return $saida;
}

sub _exigir_colunas ($self, $header, $necessarias, $origem) {
  my %tem = map { $_ => 1 } @$header;
  my @falta = grep { !$tem{$_} } @$necessarias;
  die sprintf("%s: faltam colunas obrigatórias: %s\nRecebido: %s\n",
    $origem, join(', ', @falta), join(', ', @$header)) if @falta;
  return 1;
}

sub _snapshot ($self, $chave) {
  return $self->config->{$chave} if $self->config->{$chave};
  return strftime('%Y-%m-%d', localtime);
}

1;
