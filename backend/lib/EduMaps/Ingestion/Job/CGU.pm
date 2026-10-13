package EduMaps::Ingestion::Job::CGU;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use POSIX qw(strftime);
use Text::CSV;
use Time::Piece;
use EduMaps::Ingestion::Job::SICONFI;

use utf8;

has job_name    => 'CGU';
has description => 'Ingestão CGU: transferências federais para educação (ZIP mensal oficial, função 12) por município';
has schedule    => 'monthly';

# =====================================================================
# CGU — Transferências (#238, P2 da #156)
#
# Fonte: o ZIP mensal oficial do Portal da Transparência, sem chave de API
#   {base_url}/{AAAAMM}_Transferencias.zip
# CSV latin1, separador ';', valor com vírgula decimal (ex.: "2417878,87"),
# estornos negativos. Uma linha por (favorecido, ação, ...) no mês.
#
# Escopo (decisão do developer, 2026-10-13):
#   - só CÓDIGO FUNÇÃO = 12 (Educação);
#   - transferências às PREFEITURAS ("Administração Pública Municipal"):
#     o município sai do CNPJ do favorecido (mapa CNPJ -> cod_ibge do
#     SICONFI /entes, 5570/5570 com CNPJ) e, se o CNPJ não for o da
#     prefeitura (fundo municipal, secretaria), do código SIAFI;
#   - PDDE (ação 0515) às UEx (associações de escola, CNPJ próprio):
#     agregado por município pelo CÓDIGO MUNICÍPIO SIAFI;
#   - estados e entidades fora do PDDE: fora do escopo (tabela municipal),
#     contados — não somem em silêncio.
#
# O CSV traz o código SIAFI do município, não o IBGE. O de-para SIAFI ->
# IBGE é DERIVADO dos próprios arquivos: as linhas de prefeitura (qualquer
# função) trazem o SIAFI e o CNPJ da prefeitura, e o CNPJ casa com o IBGE
# pelo SICONFI. Sem tabela externa.
#
# O que não resolve vai para um relatório de órfãos (cgu_orfaos.csv) com o
# motivo e o valor — o mesmo contrato do BrazilCrime/RENAVAM (#155).
# =====================================================================

use constant TABELA => 'clean.transferencia_educ';
use constant FUNCAO_EDUCACAO => '12';
use constant TIPO_MUNICIPAL  => 'Administração Pública Municipal';
use constant ACAO_PDDE       => '0515';

# programa por código de ação orçamentária; ação de educação fora da lista
# entra como ACAO_<código> (não se descarta transferência real).
my %PROGRAMA_POR_ACAO = (
  '00SB' => 'FUNDEB',                       # complementação da União
  '0969' => 'PNATE',                        # transporte escolar
  '0E53' => 'CAMINHO_DA_ESCOLA',            # aquisição de veículos
  '0515' => 'PDDE',                         # dinheiro direto na escola
  '12KU' => 'PROINFANCIA',                  # escolas de educação infantil
  '20RP' => 'INFRAESTRUTURA_EDUC_BASICA',
  '0509' => 'APOIO_EDUC_BASICA',
  # Medido na carga de 2025 (#238): as ações abaixo caíam no fallback
  # ACAO_<código>, e a 00PI sozinha somava R$ 3,86 bi em 5.537 municípios.
  '00PI' => 'PNAE',                         # alimentação escolar
  '00OW' => 'MANUTENCAO_EDUC_INFANTIL',     # apoio à manutenção da ed. infantil
  '00SU' => 'PROINFANCIA',                  # implantação de escolas de ed. infantil
);

my %COL = (
  ano_mes   => 'ANO / MÊS',
  tipo_fav  => 'TIPO FAVORECIDO',
  uf        => 'UF',
  siafi     => 'CÓDIGO MUNICÍPIO SIAFI',
  funcao    => 'CÓDIGO FUNÇÃO',
  acao      => 'AÇÃO',
  nome_acao => 'NOME AÇÃO',
  cnpj      => 'CÓDIGO FAVORECIDO',
  nome_fav  => 'NOME FAVORECIDO',
  valor     => 'VALOR TRANSFERIDO',
);

has base_url => 'https://dadosabertos-download.cgu.gov.br/PortalDaTransparencia/saida/transferencias';
has fonte_url => 'https://portaldatransparencia.gov.br/download-de-dados/transferencias';

# Downloads inteiros que chegaram truncados (o servidor da CGU fecha a
# conexão a meio) são detectados por `unzip -t` e baixados de novo.
has tentativas_zip => 3;

has dir_trabalho => sub ($self) {
  return ($self->config->{dir_trabalho} // 'data/ingestao') . '/cgu';
};

# Municípios do SICONFI /entes (esfera M), com cnpj e cod_ibge. Injetável
# nos testes; na execução reaproveita o fetch (com cache) do job SICONFI.
has entes => sub ($self) {
  my $sic = EduMaps::Ingestion::Job::SICONFI->new(
    log => $self->log, config => $self->config, allowlist => $self->allowlist,
  );
  return $sic->_fetch_entes;
};

sub tabelas ($self, $args = {}) { return (TABELA) }

# ---------------------------------------------------------------------
# Run
#
# Args: ano=AAAA (default: o último ano completo); meses=1,2 (default 1..12)
# ---------------------------------------------------------------------
sub run ($self, $args = {}) {
  my $ano = $args->{ano} // (localtime)[5] + 1900 - 1;
  die "CGU: ano inválido: $ano\n" unless $ano =~ /^\d{4}$/;
  my @meses = $self->arg_lista($args, 'meses');
  @meses = (1 .. 12) unless @meses;
  for (@meses) { die "CGU: mês inválido: $_\n" unless /^\d{1,2}$/ && $_ >= 1 && $_ <= 12 }
  my @ref = map { sprintf('%04d%02d', $ano, $_) } @meses;

  return $self->_dry_run_sanidade(\@ref) if $self->dry_run;

  $self->log_info(sprintf('CGU: transferências %s (%d mês(es)), função %s', $ano, scalar @ref, FUNCAO_EDUCACAO));

  my @leituras;
  for my $aaaamm (@ref) {
    my $csv = $self->obter_csv($aaaamm);
    push @leituras, $self->ler_csv($csv);
  }

  my $res = $self->resolver(\@leituras, $self->entes);
  $self->registrar_orfaos($res->{orfaos});

  my $rows = $res->{linhas};
  die "CGU: nenhuma transferência de educação resolvida para município ($ano)\n" unless @$rows;

  my $dt_snapshot = strftime('%Y-%m-%d', localtime);
  my $n = $self->carregar($rows, $dt_snapshot);

  my $e = $res->{estatisticas};
  my %por_prog;
  $por_prog{ $_->{programa} }++ for @$rows;
  $self->upsert_metadata(
    TABELA,
    'CGU Portal da Transparência — Transferências (ZIP mensal {AAAAMM}_Transferencias.zip)',
    $self->fonte_url,
    'CC-BY-4.0 (CGU)',
    $n,
    sprintf('Função 12 (Educação), %s, meses %s. %d municípios; linhas (município×programa×mês) por programa: %s. '
      . 'Município pelo CNPJ da prefeitura (SICONFI /entes) ou pelo código SIAFI (de-para derivado dos próprios arquivos: %d códigos). '
      . 'PDDE às UEx agregado por município. Fora do escopo (estados, entidades fora do PDDE): %d linhas. '
      . 'Órfãos: %d linhas (R$ %.2f) — ver cgu_orfaos.csv.',
      $ano, join(',', @meses), $e->{municipios},
      join(', ', map { "$_=$por_prog{$_}" } sort keys %por_prog),
      $e->{siafi_mapeados}, $e->{fora_do_escopo}, $e->{orfaos_linhas}, $e->{orfaos_valor}),
  );
  $self->log_info("CGU: $n linhas carregadas em " . TABELA . " (dt_snapshot $dt_snapshot)");
  return $n;
}

# Dry-run honesto: valida as URLs no allowlist e faz UMA requisição de
# sanidade (HEAD do primeiro ZIP). Nada é baixado nem gravado.
sub _dry_run_sanidade ($self, $ref) {
  my $url = $self->url_zip($ref->[0]);
  $self->exigir_allowlist($url);
  $self->exigir_allowlist(EduMaps::Ingestion::Job::SICONFI->new->base_url . '/entes');
  my $res = $self->run_with_retry(sub {
    my $tx = $self->ua->head($url);
    die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
    return $tx->result;
  }, "HEAD $url");
  $self->log_info(sprintf('[DRY-RUN] CGU: %d ZIP(s) planejados (%s..%s); sanidade %s -> HTTP %s, %s bytes. Nada baixado nem gravado.',
    scalar @$ref, $ref->[0], $ref->[-1], $url, $res->code, $res->headers->content_length // '?'));
  return 0;
}

sub url_zip ($self, $aaaamm) { return $self->base_url . "/${aaaamm}_Transferencias.zip" }

# ---------------------------------------------------------------------
# Download (raw preservado) + validação do ZIP + extração do CSV
# ---------------------------------------------------------------------
sub obter_csv ($self, $aaaamm) {
  my $url = $self->url_zip($aaaamm);
  my $zip;
  for my $t (1 .. $self->tentativas_zip) {
    $zip = $self->download_file($url, undef, {}, tabelas => [TABELA]);
    last if $self->zip_integro($zip);
    $self->log->warn("[CGU] ZIP truncado/corrompido ($zip), tentativa $t/" . $self->tentativas_zip . ' — baixando de novo');
    unlink $zip;
    die "CGU: ZIP $aaaamm corrompido após " . $self->tentativas_zip . " tentativas ($url)\n"
      if $t == $self->tentativas_zip;
  }
  return $self->extrair_csv($zip);
}

# `unzip -t` lê o diretório central e o CRC de cada membro: um download
# truncado falha aqui (e não vira "arquivo existente" a reaproveitar).
sub zip_integro ($self, $zip) {
  return 0 unless -f $zip && -s $zip;
  my $rc = system('unzip', '-tqq', "$zip");
  return $rc == 0 ? 1 : 0;
}

sub extrair_csv ($self, $zip) {
  my $lista = `unzip -Z1 "$zip" 2>/dev/null`;
  my ($membro) = grep { /\.csv$/i } split /\n/, $lista;
  die "CGU: nenhum CSV dentro de $zip\n" unless $membro;
  my $dir = path($self->dir_trabalho);
  $dir->make_path;
  my $saida = $dir->child(path($membro)->basename);
  unless (-f $saida && (stat($saida))[9] >= (stat($zip))[9]) {
    my $rc = system('unzip', '-o', '-qq', "$zip", $membro, '-d', "$dir");
    die "CGU: unzip falhou (rc=$rc) para $membro\n" if $rc;
  }
  return "$saida";
}

# ---------------------------------------------------------------------
# Leitura de um CSV mensal
#
# Devolve {
#   educ        => [ {ano_mes, tipo, uf, siafi, cnpj, acao, nome_fav, valor}, ... ]  (função 12)
#   siafi_cnpj  => { siafi => { cnpj => n } }   (linhas de prefeitura, qualquer função)
#   linhas      => n,
# }
# ---------------------------------------------------------------------
sub ler_csv ($self, $arquivo) {
  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', auto_diag => 1 });
  open my $fh, '<:encoding(latin1)', $arquivo or die "CGU: não abriu $arquivo: $!\n";
  my $header = $csv->getline($fh) or die "CGU: CSV vazio: $arquivo\n";
  $header->[0] =~ s/^\x{FEFF}//;
  my %idx = map { $header->[$_] => $_ } 0 .. $#$header;
  my @falta = grep { !exists $idx{ $COL{$_} } } sort keys %COL;
  die sprintf("CGU: colunas obrigatórias ausentes em %s: %s\n", $arquivo, join(', ', map { $COL{$_} } @falta))
    if @falta;

  my (@educ, %siafi_cnpj);
  my $linhas = 0;
  while (my $r = $csv->getline($fh)) {
    $linhas++;
    my %v = map { $_ => _limpo($r->[ $idx{ $COL{$_} } ]) } keys %COL;

    if ($v{tipo_fav} eq TIPO_MUNICIPAL && length $v{siafi} && length $v{cnpj}) {
      $siafi_cnpj{ $v{siafi} }{ $v{cnpj} }++;
    }
    next unless $v{funcao} eq FUNCAO_EDUCACAO;

    $v{valor} = _valor($v{valor});
    push @educ, {
      ano_mes => $v{ano_mes}, tipo => $v{tipo_fav}, uf => $v{uf},
      siafi => $v{siafi}, cnpj => $v{cnpj}, acao => $v{acao},
      nome_fav => $v{nome_fav}, valor => $v{valor},
    };
  }
  close $fh;
  $self->log_info(sprintf('CGU: %s — %d linhas, %d de educação', path($arquivo)->basename, $linhas, scalar @educ));
  return { educ => \@educ, siafi_cnpj => \%siafi_cnpj, linhas => $linhas };
}

sub _limpo ($s) { $s //= ''; $s =~ s/^\s+|\s+$//g; return $s }

# "2417878,87" -> 2417878.87; "-1.234,50" -> -1234.5 (o arquivo não usa
# separador de milhar, mas aceitar não custa).
sub _valor ($s) {
  return 0 unless defined $s && length $s;
  $s =~ s/\.//g;
  $s =~ s/,/./;
  die "CGU: valor não numérico: '$s'\n" unless $s =~ /^-?\d+(?:\.\d+)?$/;
  return 0 + $s;
}

sub programa_da_acao ($self, $acao) {
  return $PROGRAMA_POR_ACAO{$acao} // "ACAO_$acao";
}

# ---------------------------------------------------------------------
# Resolução município + agregação (município × programa × mês)
#
# $leituras: lista de retornos de ler_csv; $entes: [{cod_ibge, cnpj, ente}]
# ---------------------------------------------------------------------
sub resolver ($self, $leituras, $entes) {
  my (%ibge_por_cnpj, %nome_por_ibge);
  for my $e (@$entes) {
    next unless defined $e->{cod_ibge};
    my $cod = sprintf('%07d', $e->{cod_ibge});
    $nome_por_ibge{$cod} = $e->{ente};
    (my $cnpj = $e->{cnpj} // '') =~ s/\D//g;
    $ibge_por_cnpj{$cnpj} = $cod if length $cnpj;
  }

  # De-para SIAFI -> IBGE derivado das linhas de prefeitura. Se um SIAFI
  # apontar para mais de um IBGE (não deveria), vence o mais frequente e o
  # conflito é registado no log.
  my %votos;
  for my $l (@$leituras) {
    while (my ($siafi, $cnpjs) = each %{ $l->{siafi_cnpj} }) {
      while (my ($cnpj, $n) = each %$cnpjs) {
        my $cod = $ibge_por_cnpj{$cnpj} or next;
        $votos{$siafi}{$cod} += $n;
      }
    }
  }
  my (%ibge_por_siafi, $conflitos);
  for my $siafi (keys %votos) {
    my @c = sort { $votos{$siafi}{$b} <=> $votos{$siafi}{$a} || $a cmp $b } keys %{ $votos{$siafi} };
    $conflitos++ if @c > 1;
    $ibge_por_siafi{$siafi} = $c[0];
  }
  $self->log->warn("[CGU] $conflitos código(s) SIAFI com mais de um IBGE — escolhido o mais frequente")
    if $conflitos;

  my (%agg, %orfaos);
  my ($fora, $orf_linhas, $orf_valor) = (0, 0, 0);
  for my $l (@$leituras) {
    for my $r (@{ $l->{educ} }) {
      my ($cod, $motivo);
      if ($r->{tipo} eq TIPO_MUNICIPAL) {
        $cod = $ibge_por_cnpj{ $r->{cnpj} } // $ibge_por_siafi{ $r->{siafi} };
        $motivo = length $r->{siafi} ? 'municipio_nao_resolvido' : 'municipio_sem_cnpj_nem_siafi'
          unless $cod;
      }
      elsif ($r->{acao} eq ACAO_PDDE && $r->{tipo} !~ /Estadual/) {
        if (!length $r->{siafi}) { $motivo = 'pdde_sem_siafi' }
        else {
          $cod = $ibge_por_siafi{ $r->{siafi} };
          $motivo = 'pdde_siafi_sem_correspondencia' unless $cod;
        }
      }
      else {
        $fora++;    # estados e entidades fora do PDDE: fora do escopo
        next;
      }

      if (!$cod) {
        $orf_linhas++;
        $orf_valor += $r->{valor};
        my $k = join "\x1F", $motivo, $r->{uf}, $r->{siafi}, $r->{cnpj}, $r->{acao};
        my $o = $orfaos{$k} //= {
          motivo => $motivo, uf => $r->{uf}, siafi => $r->{siafi}, cnpj => $r->{cnpj},
          acao => $r->{acao}, favorecido => $r->{nome_fav}, linhas => 0, valor => 0,
        };
        $o->{linhas}++;
        $o->{valor} += $r->{valor};
        next;
      }
      $agg{$cod}{ $self->programa_da_acao($r->{acao}) }{ $r->{ano_mes} } += $r->{valor};
    }
  }

  my @linhas;
  for my $cod (sort keys %agg) {
    for my $prog (sort keys %{ $agg{$cod} }) {
      for my $am (sort keys %{ $agg{$cod}{$prog} }) {
        my ($ini, $fim) = _periodo($am);
        push @linhas, {
          codigo_ibge => $cod, nome_municipio => $nome_por_ibge{$cod},
          programa => $prog, valor_transferido => 0 + sprintf('%.2f', $agg{$cod}{$prog}{$am}),
          data_inicio => $ini, data_fim => $fim,
        };
      }
    }
  }

  return {
    linhas => \@linhas,
    orfaos => [ sort { $b->{valor} <=> $a->{valor} || $a->{motivo} cmp $b->{motivo} } values %orfaos ],
    ibge_por_siafi => \%ibge_por_siafi,
    estatisticas => {
      municipios     => scalar(keys %agg),
      siafi_mapeados => scalar(keys %ibge_por_siafi),
      siafi_conflitos => $conflitos // 0,
      fora_do_escopo => $fora,
      orfaos_linhas  => $orf_linhas,
      orfaos_valor   => $orf_valor,
    },
  };
}

# "202502" -> ("2025-02-01", "2025-02-28")
sub _periodo ($aaaamm) {
  die "CGU: ANO / MÊS inválido: '$aaaamm'\n" unless $aaaamm =~ /^(\d{4})(\d{2})$/;
  my $t = Time::Piece->strptime("$1-$2-01", '%Y-%m-%d');
  return ($t->ymd, sprintf('%04d-%02d-%02d', $1, $2, $t->month_last_day));
}

# ---------------------------------------------------------------------
# Órfãos: relatório CSV + log (nada some em silêncio)
# ---------------------------------------------------------------------
sub registrar_orfaos ($self, $orfaos) {
  my $total = 0;
  $total += $_->{linhas} for @$orfaos;
  unless (@$orfaos) {
    $self->log_info('CGU: nenhum órfão');
    return 0;
  }
  my $dir = path($self->dir_trabalho);
  $dir->make_path;
  my $destino = $dir->child('cgu_orfaos.csv');
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '>:encoding(utf8)', "$destino" or die "CGU: não abriu $destino: $!\n";
  my @cols = qw(motivo uf siafi cnpj acao favorecido linhas valor);
  $csv->print($fh, \@cols);
  for my $o (@$orfaos) {
    $csv->print($fh, [ (map { $o->{$_} } qw(motivo uf siafi cnpj acao favorecido linhas)), sprintf('%.2f', $o->{valor}) ]);
  }
  close $fh or die "CGU: não fechou $destino: $!\n";
  my %por_motivo;
  $por_motivo{ $_->{motivo} } += $_->{linhas} for @$orfaos;
  $self->log->warn(sprintf('[CGU] Órfãos: %d linhas em %d grupos (%s). Relatório: %s',
    $total, scalar @$orfaos, join(', ', map { "$_=$por_motivo{$_}" } sort keys %por_motivo), $destino));
  return $total;
}

# ---------------------------------------------------------------------
# Carga (idempotente na PK)
# ---------------------------------------------------------------------
sub carregar ($self, $rows, $dt_snapshot) {
  return 0 unless $rows && @$rows;
  my $dbh = $self->app->schema->storage->dbh;
  my $sql = <<'SQL';
INSERT INTO clean.transferencia_educ
  (codigo_ibge, nome_municipio, programa, valor_transferido, data_inicio, data_fim, dt_snapshot)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (codigo_ibge, programa, data_inicio, data_fim, dt_snapshot)
DO UPDATE SET valor_transferido = EXCLUDED.valor_transferido,
              nome_municipio    = EXCLUDED.nome_municipio
SQL
  # O snapshot de um período é substituído por inteiro: uma re-execução no
  # mesmo dia com outro mapa de programas (ex.: ACAO_00PI -> PNAE) não pode
  # deixar a chave antiga para trás somando em dobro.
  my ($ini) = sort map { $_->{data_inicio} } @$rows;
  my ($fim) = reverse sort map { $_->{data_fim} } @$rows;
  my $n = 0;
  $dbh->begin_work;
  eval {
    $dbh->do(q{DELETE FROM clean.transferencia_educ
                WHERE dt_snapshot = ? AND data_inicio >= ? AND data_fim <= ?},
      undef, $dt_snapshot, $ini, $fim);
    my $sth = $dbh->prepare($sql);
    for my $r (@$rows) {
      $sth->execute(@{$r}{qw(codigo_ibge nome_municipio programa valor_transferido data_inicio data_fim)}, $dt_snapshot);
      $n++;
    }
    $dbh->commit;
  };
  # Capturar $@ antes do eval de rollback (armadilha medida na #165).
  if (my $err = $@) {
    eval { $dbh->rollback };
    die "CGU: carga falhou, nada gravado: $err";
  }
  return $n;
}

1;
