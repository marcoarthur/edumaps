package EduMaps::Ingestion::Job::IBGEPopulacaoIdade;
use Mojo::Base 'EduMaps::Ingestion::Job::IBGE', -signatures;

use Text::CSV;
use utf8;

# ============================================================================
# População por idade do Censo Demográfico 2022 (#533, QP-01 da P2)
# ============================================================================
#
# SIDRA, tabela 9514 ("População residente, por sexo, idade e forma de
# declaração da idade"), por município: o total, as 21 faixas de 5 anos e as
# idades de 0 a 17 anos, ambos os sexos e todas as formas de declaração.
# Grava em clean.ibge_agregados (tabela_id 9514, variável 93) com a idade do
# SIDRA em `classificacao` ("Menos de 1 ano", "1 ano", "0 a 4 anos",
# "Total"); a visão clean.populacao_idade soma as idades da creche (0 a 3),
# da pré-escola (4 e 5), do fundamental (6 a 14) e do médio (15 a 17).
#
# Cinco requisições (n6/all): o SIDRA limita a resposta a ~50 mil valores,
# e 8 categorias × 5.570 municípios cabem numa. O Censo é decenal, então o
# job é manual.

has job_name    => 'IBGEPopulacaoIdade';
has description => 'Ingestão IBGE/SIDRA (população por idade, Censo 2022 - tabela 9514)';
has schedule    => 'manual';
has fonte_raw   => 'ibge_populacao_idade';

has tabela_idade => '9514';
has ano_censo    => 2022;

# Categorias da classificação 287 (Idade), na ordem do SIDRA. Nome do SIDRA
# conferido contra a resposta: código desconhecido ou nome trocado aborta.
our @CATEGORIAS = (
  [100362, 'Total'],
  [93070, '0 a 4 anos'],  [93084, '5 a 9 anos'],   [93085, '10 a 14 anos'],
  [93086, '15 a 19 anos'], [93087, '20 a 24 anos'], [93088, '25 a 29 anos'],
  [93089, '30 a 34 anos'], [93090, '35 a 39 anos'], [93091, '40 a 44 anos'],
  [93092, '45 a 49 anos'], [93093, '50 a 54 anos'], [93094, '55 a 59 anos'],
  [93095, '60 a 64 anos'], [93096, '65 a 69 anos'], [93097, '70 a 74 anos'],
  [93098, '75 a 79 anos'], [49108, '80 a 84 anos'], [49109, '85 a 89 anos'],
  [60040, '90 a 94 anos'], [60041, '95 a 99 anos'], [6653, '100 anos ou mais'],
  [6557, 'Menos de 1 ano'], [6558, '1 ano'], [6559, '2 anos'], [6560, '3 anos'],
  [6561, '4 anos'],  [6562, '5 anos'],  [6563, '6 anos'],  [6564, '7 anos'],
  [6565, '8 anos'],  [6566, '9 anos'],  [6567, '10 anos'], [6568, '11 anos'],
  [6569, '12 anos'], [6570, '13 anos'], [6571, '14 anos'], [6572, '15 anos'],
  [6573, '16 anos'], [6574, '17 anos'],
);

use constant CATEGORIAS_POR_LOTE => 8;
use constant MINIMO_MUNICIPIOS   => 5500;

sub tabelas ($self, $args = {}) { return ('clean.populacao_idade') }

sub url_lote ($self, @codigos) {
  return sprintf('%s/%s/n6/all/v/93/p/%d/c2/6794/c287/%s/c286/113635/f/a',
    $self->sidra_base, $self->tabela_idade, $self->ano_censo, join(',', @codigos));
}

sub lotes ($self) {
  my @cod = map { $_->[0] } @CATEGORIAS;
  my @lotes;
  push @lotes, [splice @cod, 0, CATEGORIAS_POR_LOTE] while @cod;
  return @lotes;
}

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão IBGE/SIDRA 9514 (população por idade, Censo 2022)');
  my $dir = $self->dir_trabalho;
  my $csv = "$dir/populacao_idade_censo2022.csv";

  if (my $bruto = $args->{csv}) {
    die "csv não existe: $bruto\n" unless -f $bruto;
    $self->log_info("Relendo o bruto $bruto (sem extração)");
    $csv = $bruto;
  }
  else {
    my @linhas;
    for my $lote ($self->lotes) {
      my $url = $self->url_lote(@$lote);
      my $res = $self->fetch_with_retry($url);
      die sprintf("SIDRA respondeu HTTP %d em %s\n", $res->code, $url) unless $res->code == 200;
      push @linhas, @{ $self->linhas_da_resposta($res->json) };
    }
    $self->escrever_csv($csv, \@linhas);
    $self->preservar_raw($csv, $self->sidra_base . '/' . $self->tabela_idade,
      tabelas => ['clean.populacao_idade']) unless $self->dry_run;
  }

  my $rows = $self->processar_ibge_agregados($csv);
  my $n_mun = $self->conferir($rows);
  my $loaded = $self->carregar_ibge_agregados($rows);

  $self->upsert_metadata(
    'clean.populacao_idade',
    'SIDRA tabela 9514 (Censo Demográfico 2022, população por idade)',
    'https://sidra.ibge.gov.br/tabela/9514',
    'Domínio público (IBGE)',
    $loaded,
    sprintf('Censo 2022, %d municípios: total, faixas de 5 anos e idades de 0 a 17 anos, em clean.ibge_agregados (tabela_id 9514).', $n_mun),
  );
  $self->log_info(sprintf('IBGE/SIDRA 9514: %d registros de %d municípios', $loaded, $n_mun));
  return $loaded;
}

# Resposta /f/a do SIDRA (primeira linha = cabeçalho) → linhas do formato
# longo de clean.ibge_agregados. "-" é zero absoluto na convenção do IBGE;
# "..." e "X" (sigilo) ficam vazios.
sub linhas_da_resposta ($self, $json) {
  die "Resposta do SIDRA sem dados\n" unless ref $json eq 'ARRAY' && @$json > 1;
  my %nome = map { $_->[0] => $_->[1] } @CATEGORIAS;
  my @linhas;
  for my $r (@$json[1 .. $#$json]) {
    my ($cod, $idade, $nome_idade, $v) = @$r{qw(D1C D5C D5N V)};
    die "Categoria de idade inesperada no SIDRA: $idade ($nome_idade)\n"
      unless defined $idade && exists $nome{$idade};
    die "Nome da categoria $idade mudou no SIDRA: '$nome_idade' (esperado '$nome{$idade}')\n"
      unless ($nome_idade // '') eq $nome{$idade};
    my $valor = !defined $v ? undef
              : $v eq '-' ? 0
              : $v =~ /^\d+$/ ? $v
              : undef;
    push @linhas, [$cod, $self->ano_censo, $self->tabela_idade, '93', $nome{$idade}, $valor, 'Pessoas'];
  }
  return \@linhas;
}

sub escrever_csv ($self, $arquivo, $linhas) {
  $self->_garantir_dir($arquivo);
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '>:encoding(utf8)', $arquivo or die "Não abriu $arquivo: $!";
  $csv->print($fh, [qw(codigo_ibge ano tabela_id variavel classificacao valor unidade)]);
  $csv->print($fh, $_) for @$linhas;
  close $fh;
}

# As faixas de 5 anos somam o total e as idades de 0 a 4 somam a faixa de 0
# a 4, em todo município; menos municípios que o esperado ou uma soma que
# não bate abortam antes de gravar.
sub conferir ($self, $rows) {
  my %m;
  $m{ $_->{codigo_ibge} }{ $_->{classificacao} } = $_->{valor} // 0 for @$rows;
  my @faixas = map { $_->[1] } grep { $_->[1] =~ / a \d+ anos$|ou mais$/ } @CATEGORIAS;
  my @zero_a_quatro = ('Menos de 1 ano', '1 ano', '2 anos', '3 anos', '4 anos');
  for my $cod (sort keys %m) {
    my $d = $m{$cod};
    my $soma = 0; $soma += $d->{$_} // 0 for @faixas;
    die "Município $cod: faixas somam $soma, total $d->{Total}\n"
      unless defined $d->{Total} && $soma == $d->{Total};
    my $s04 = 0; $s04 += $d->{$_} // 0 for @zero_a_quatro;
    die "Município $cod: idades de 0 a 4 somam $s04, faixa ${\ ($d->{'0 a 4 anos'} // 'vazia')}\n"
      unless defined $d->{'0 a 4 anos'} && $s04 == $d->{'0 a 4 anos'};
  }
  my $n = keys %m;
  die "Só $n municípios na resposta do SIDRA (mínimo ${\ MINIMO_MUNICIPIOS})\n"
    if $n < MINIMO_MUNICIPIOS && !$self->config->{aceitar_parcial};
  return $n;
}

1;
