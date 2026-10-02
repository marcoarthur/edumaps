package EduMaps::Ingestion::Job::SICONFI;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use POSIX qw(strftime);

use utf8;

has job_name => 'SICONFI';
has description => 'Ingestão SICONFI (receitas, RREO) via API DataLake do Tesouro';
has schedule => 'monthly';

# API DataLake do Tesouro (verificado na issue #165)
# Base com prefixo ords/cdwhprd/siconfi/tt/ (Azure Static Web Apps)
has base_url => 'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt';
has ua       => sub { Mojo::UserAgent->new(max_redirects => 5) };

has throttle => 1.0;    # 1 requisição por segundo (limite declarado no spec)

# -----------------------------------------------------------------
# Run
# -----------------------------------------------------------------
sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão SICONFI (receitas)');

  # Fase 1 do escopo mínimo: receita, 1 município de teste (SP)
  my $loaded = $self->ingest_siconfi_receita($args);
  $self->log_info("SICONFI: $loaded registos carregados");

  $self->log_info('SICONFI: ingestão concluída');
  return $loaded;
}

# -----------------------------------------------------------------
# Receita (RREO) — escopo mínimo
# -----------------------------------------------------------------
sub ingest_siconfi_receita ($self, $args = {}) {
  my $exercicio = $args->{exercicio} // (localtime)[5] + 1900;
  my $cod_ibge  = $args->{cod_ibge}  // '3550308';    # São Paulo (teste)
  my $periodo   = $args->{nr_periodo} // 2;            # RREO bimestre

  my $rows = $self->_fetch_rreo(
    exercicio             => $exercicio,
    nr_periodo            => $periodo,
    co_tipo_demonstrativo => 'RREO',
    id_ente               => $cod_ibge,
  );

  return $self->_load_receita($rows);
}

# -----------------------------------------------------------------
# RREO: /rreo
# params: exercicio, nr_periodo, co_tipo_demonstrativo=RREO, id_ente (cod_ibge)
# -----------------------------------------------------------------
sub _fetch_rreo ($self, %args) {
  my $cod_ibge = delete $args{id_ente} // delete $args{cod_ibge};
  die "id_ente (cod_ibge) e obrigatorio\n" unless $cod_ibge;

  my %p = (
    exercicio             => (localtime)[5] + 1900,
    nr_periodo            => 2,
    co_tipo_demonstrativo => 'RREO',
    id_ente               => $cod_ibge,
    limit                 => 1000,
    offset                => 0,
    %args,
  );

  my $url = $self->base_url . '/rreo';
  my @items;
  my $page = 0;
  my $max_pages = 500;

  while ($page++ < $max_pages) {
    my $tx = $self->ua->get($url => form => { %p });
    if ($tx->res->code != 200) {
      die sprintf("SICONFI /rreo falhou: HTTP %d em %s\n", $tx->res->code, $tx->req->url);
    }

    my $json = $tx->res->json;
    last unless $json && ref($json) eq 'HASH';
    last unless $json->{items};
    last unless @{$json->{items}};

    push @items, @{$json->{items}};
    my $count = $json->{count} // scalar @items;

    # paginação: se offset+limit >= count ou sem hasMore, para
    if (defined $json->{hasMore} && !$json->{hasMore}) {
      last;
    }
    $p{offset} += $p{limit};
    if ($p{offset} >= $count && $count >= 0) {
      # se count for 0, vamos dar erro abaixo — mas já paramos
      last if $count > 0;
    }

    # throttle 1 req/s
    select(undef, undef, undef, $self->throttle) if $self->throttle > 0;
  }

  # Armadilha crítica: HTTP 200 com count==0 é um falso sucesso.
  # Se pedimos para um município que devia ter dados, isto tem de falhar.
  if (@items == 0) {
    die sprintf("SICONFI /rreo devolveu 0 itens para cod_ibge=%s (exercicio=%s periodo=%s). API pode estar retornando count==0 com HTTP 200 — verificar parametros\n",
      $cod_ibge, $p{exercicio}, $p{nr_periodo});
  }

  return $self->_map_rreo_receita($cod_ibge, $p{exercicio}, \@items);
}

# Mapeamento mínimo — receita RREO
sub _map_rreo_receita ($self, $cod_ibge, $exercicio, $items) {
  my @out;
  my $hoje = strftime('%Y-%m-%d', localtime);
  for my $it (@$items) {
    next unless defined $it->{coluna} && defined $it->{valor};
    push @out, {
      codigo_ibge       => $cod_ibge,
      exercicio         => $exercicio,
      tipo_receita      => $it->{cod_conta} // $it->{conta} // '',
      coluna_receita    => $it->{coluna} // '',
      descricao_receita => $it->{conta} // undef,
      valor             => $it->{valor} + 0,
      # Classificacao: o ponto crítico. Por enquanto, mapear com cautela.
      # PREVISAO/INICIAL nao e realizada.
      classificacao     => 'realizada',
      dt_snapshot       => $hoje,
    };
  }
  return \@out;
}
