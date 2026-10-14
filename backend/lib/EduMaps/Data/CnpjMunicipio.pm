package EduMaps::Data::CnpjMunicipio;
use Mojo::Base -base, -signatures;
use utf8;

=head1 NAME

EduMaps::Data::CnpjMunicipio - resolve o município de um CNPJ (cache + API)

=head1 SYNOPSIS

    my $p = EduMaps::Data::CnpjMunicipio->new(dbh => $dbh);
    my $mapa = $p->municipio_por_cnpj(['45545636000157']);
    # { '45545636000157' => { codigo_ibge => '3550308', uf => 'SP',
    #                         municipio => 'SAO PAULO', fonte => 'brasilapi' } }

=head1 DESCRIPTION

Resolve o município (código IBGE) de um CNPJ a partir dos dados abertos da
Receita Federal, com cache persistido em C<clean.cnpj_municipio>.

Serve para atribuir as Unidades Executoras (UEx) do PDDE — caixas escolares,
conselhos, APMs, associações — que o arquivo da CGU traz só com o CNPJ, sem o
código SIAFI do município (issue #240).

Consulta primeiro o cache; só os CNPJs ainda não vistos vão à API. Cada CNPJ
resolvido é gravado no cache B<à medida que resolve> — a primeira carga
resolve dezenas de milhares de CNPJs e corre por horas: gravar só no fim
perderia tudo se o job morresse a meio. C<nao_encontrado> é devolvido para
CNPJs que as fontes não reconhecem (mas NÃO é cacheado: uma falha definitiva
pode vir a ser resolvida depois, e reconsultar alguns poucos por carga é
barato).

Fontes, em ordem: BrasilAPI (primária) e Minha Receita (fallback) — APIs
comunitárias sem contrato de volume, por isso o C<throttle> padrão. Uma fonte
que responde 4xx (excepto 429) diz "não está na base"; uma que falha a rede
(5xx/429/timeout) é retentada e, esgotada, passa à fonte seguinte. Há CNPJs
que B<as duas> fontes não respondem (5xx determinístico, medido): um caso
isolado é registrado como órfão sem derrubar a carga. Só uma rajada de falhas
seguidas (C<max_falhas_seguidas>) morre alto — aí as fontes estão fora e
orfanar em massa seria mentir.

=cut

use Mojo::JSON qw(decode_json);
use Mojo::Log;
use Mojo::UserAgent;
use Time::HiRes qw(sleep);

has log => sub { Mojo::Log->new };

has allowlist => sub ($self) {
  require EduMaps::Data::Allowlist;
  return EduMaps::Data::Allowlist->new;
};

has ua => sub ($self) {
  my $ua = Mojo::UserAgent->new;
  $ua->connect_timeout(20)->inactivity_timeout(60);
  return $ua;
};

# Conexão à base do produto para o cache (clean.cnpj_municipio). Sem dbh, o
# provedor consulta a API sempre e não grava cache (usado pelos testes).
has dbh => undef;

# Segundos entre chamadas à API: 0,2s (~5 req/s) foi medido sem HTTP 429.
has throttle => 0.2;
has max_retries => 3;
has backoff_base => 2;
has jitter => 2;   # aleatoriedade somada ao backoff (0 nos testes)

# Nº de CNPJs SEGUIDOS que podem falhar transitória em todas as fontes antes
# de a carga abortar. Separa os dois casos que se parecem: um CNPJ isolado
# que a RFB não responde (as duas fontes devolvem 5xx para ele — medido) passa
# e fica registrado como órfão; uma rajada significa que as fontes estão fora
# e orfanar em massa seria mentir. ~6 chamadas por CNPJ problemático.
has max_falhas_seguidas => 30;

# Fontes em ordem de preferência. Cada uma usa o CNPJ para montar a URL; a
# resposta (mesmos campos do layout da RFB) é interpretada por _tentar.
has fontes => sub ($self) {
  return [
    { id => 'brasilapi',    url => sub ($cnpj) { "https://brasilapi.com.br/api/cnpj/v1/$cnpj" } },
    { id => 'minhareceita', url => sub ($cnpj) { "https://minhareceita.org/$cnpj" } },
  ];
};

# ---------------------------------------------------------------------
# municipio_por_cnpj(\@cnpjs)
#
# Devolve { cnpj => { codigo_ibge, uf, municipio, fonte } } para os
# resolvidos e { cnpj => { nao_encontrado => 1 } } para os demais.
# CNPJs fora do formato (≠ 14 dígitos) são ignorados.
# ---------------------------------------------------------------------
sub municipio_por_cnpj ($self, $cnpjs) {
  my %alvo;
  for my $c (@$cnpjs) {
    my $d = _digitos($c);
    next unless length $d == 14;
    $alvo{$d} = 1;
  }
  return {} unless %alvo;

  my %res = %{ $self->_ler_cache([ sort keys %alvo ]) };
  my @falta = grep { !exists $res{$_} } sort keys %alvo;
  return \%res unless @falta;

  # Grava linha a linha, à medida que resolve: ver a DESCRIPTION (resiliência
  # a interrupção + progresso do watchdog).
  my $sth = $self->dbh ? $self->_sth_cache : undef;
  my $seguidas = 0;   # falhas transitórias consecutivas (guard de indisponibilidade)

  for my $i (0 .. $#falta) {
    my $cnpj = $falta[$i];
    my $info = $self->_resolver_cnpj($cnpj);
    if ($info->{codigo_ibge}) {
      $res{$cnpj} = $info;
      _gravar_linha($sth, $cnpj, $info) if $sth;
      $seguidas = 0;
    }
    elsif ($info->{nao_encontrado}) {
      $self->log->warn("[CNPJ] $cnpj não encontrado nas fontes");
      $res{$cnpj} = { nao_encontrado => 1 };
      $seguidas = 0;
    }
    else {
      # Todas as fontes falharam a rede. Um CNPJ problemático isolado não
      # pode derrubar a carga (fica órfão); uma rajada indica indisponibilidade.
      $seguidas++;
      die sprintf("[CNPJ] %d falhas seguidas nas fontes (última em %s: %s) — "
        . "provável indisponibilidade; abortando para não orfanar em massa\n",
        $seguidas, $cnpj, $info->{erro} // 'sem detalhe') if $seguidas > $self->max_falhas_seguidas;
      $self->log->warn("[CNPJ] $cnpj não resolvido (fontes indisponíveis: " . ($info->{erro} // '?') . ')');
      $res{$cnpj} = { nao_encontrado => 1 };
    }
    sleep $self->throttle if $self->throttle > 0 && $i < $#falta;
  }

  return \%res;
}

# Tenta cada fonte em ordem. Devolve o registo achatado
# { codigo_ibge, uf, municipio, fonte } quando alguma resolve;
# { nao_encontrado => 1 } quando alguma fonte responde 4xx definitivo; ou
# { erro => $msg } quando TODAS falharam a rede.
sub _resolver_cnpj ($self, $cnpj) {
  my ($viu_nao_encontrado, $ultimo_erro);
  for my $fonte (@{ $self->fontes }) {
    my $url = $fonte->{url}->($cnpj);
    $self->_exigir_allowlist($url);
    my $r = $self->_tentar($url, $fonte->{id}, $cnpj);
    return $r->{resolvido} if $r->{resolvido};
    $viu_nao_encontrado = 1 if $r->{nao_encontrado};
    $ultimo_erro = $r->{erro} if $r->{erro};
  }
  return { nao_encontrado => 1 } if $viu_nao_encontrado;
  return { erro => $ultimo_erro };
}

# Uma fonte. Devolve { resolvido => {...} }, { nao_encontrado => 1 } (4xx:
# não está na base) ou { erro => $msg } (rede/5xx/429 após retries).
sub _tentar ($self, $url, $fonte, $cnpj) {
  my $tentativa = 0;
  while (1) {
    $tentativa++;
    my $tx = $self->ua->get($url);
    if (my $err = $tx->error) {
      my $code = $err->{code} // 0;
      # 4xx (excepto 429) é resposta definitiva: o CNPJ não está na base.
      return { nao_encontrado => 1 } if $code >= 400 && $code < 500 && $code != 429;
      return { erro => ($err->{message} // "HTTP $code") } if $tentativa > $self->max_retries;
      my $espera = $self->backoff_base * (2 ** ($tentativa - 1)) + ($self->jitter ? rand($self->jitter) : 0);
      $self->log->warn(sprintf('[CNPJ] %s %s: %s — retry %d/%d em %.1fs',
        $fonte, $cnpj, $err->{message} // "HTTP $code", $tentativa, $self->max_retries, $espera));
      sleep $espera;
      next;
    }
    my $json = eval { decode_json($tx->res->body) };
    return { nao_encontrado => 1 } unless ref $json eq 'HASH';
    my $ibge = $json->{codigo_municipio_ibge};
    return { nao_encontrado => 1 } unless defined $ibge && $ibge =~ /^\d{1,7}\z/ && $ibge > 0;
    return { resolvido => {
      codigo_ibge => sprintf('%07d', $ibge),
      uf          => $json->{uf},
      municipio   => $json->{municipio},
      fonte       => $fonte,
    } };
  }
}

sub _exigir_allowlist ($self, $url) {
  return 1 if $self->allowlist->validate_url("$url");
  die sprintf("[ALLOWLIST] CNPJ recusou %s: %s\n", $url, $self->allowlist->last_error);
}

sub _digitos ($s) {
  $s //= '';
  $s =~ s/\D//g;
  return $s;
}

# ---------------------------------------------------------------------
# Cache (clean.cnpj_municipio)
# ---------------------------------------------------------------------
# Lê em lotes de 2000: evita um IN com dezenas de milhares de placeholders
# (limite de parâmetros do Postgres) e uma query de dezenas de KB.
sub _ler_cache ($self, $cnpjs) {
  my $dbh = $self->dbh or return {};
  my %r;
  for (my $i = 0; $i < @$cnpjs; $i += 2000) {
    my $fim = $i + 1999;
    $fim = $#$cnpjs if $fim > $#$cnpjs;
    my @lote = @$cnpjs[ $i .. $fim ];
    my $in = join ',', ('?') x @lote;
    my $sth = $dbh->prepare(
      "SELECT cnpj, codigo_ibge, uf, municipio, fonte FROM clean.cnpj_municipio WHERE cnpj IN ($in)");
    $sth->execute(@lote);
    while (my ($cnpj, $ibge, $uf, $municipio, $fonte) = $sth->fetchrow_array) {
      $r{$cnpj} = {
        codigo_ibge => $ibge,
        (defined $uf        ? (uf        => $uf)        : ()),
        (defined $municipio ? (municipio => $municipio) : ()),
        fonte => $fonte,
      };
    }
  }
  return \%r;
}

sub _sth_cache ($self) {
  my $dbh = $self->dbh or return undef;
  return $dbh->prepare(q{
    INSERT INTO clean.cnpj_municipio (cnpj, codigo_ibge, uf, municipio, fonte, atualizado_em)
    VALUES (?, ?, ?, ?, ?, NOW())
    ON CONFLICT (cnpj) DO UPDATE SET
      codigo_ibge = EXCLUDED.codigo_ibge,
      uf          = EXCLUDED.uf,
      municipio   = EXCLUDED.municipio,
      fonte       = EXCLUDED.fonte,
      atualizado_em = NOW()
  });
}

sub _gravar_linha ($sth, $cnpj, $info) {
  $sth->execute($cnpj, $info->{codigo_ibge}, $info->{uf}, $info->{municipio}, $info->{fonte} // 'desconhecida');
  return 1;
}

1;
