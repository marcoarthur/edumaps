package EduMaps::Roles::Business::Pesquisa::Respostas;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw();

# Fase 2: coleta de respostas da comunidade (link público por token) e
# agregações de resultados para o dashboard do gestor (login).

requires qw(schema);

# ---------------------------------------------------------------
# link público (formulário)
# ---------------------------------------------------------------

sub survey_for_public ($self, $token) {
  my $survey = $self->_row(
    'SELECT id, titulo, descricao
     FROM   clean.gestor_pesquisas
     WHERE  token::text = ? AND status = \'publicada\'',
    $token,
  ) or return;

  my $perguntas = $self->_rows(
    'SELECT id, ordem, texto, tipo, obrigatoria, opcoes
     FROM   clean.gestor_pesquisas_perguntas
     WHERE  pesquisa_id = ?
     ORDER  BY ordem',
    $survey->{id} + 0,
  );

  my @out;
  for my $p (@$perguntas) {
    push @out, {
      id          => $p->{id} + 0,
      ordem       => $p->{ordem} + 0,
      texto       => $p->{texto},
      tipo        => $p->{tipo},
      obrigatoria => $p->{obrigatoria} ? Mojo::JSON::true : Mojo::JSON::false,
      opcoes      => $self->_decode_opcoes($p->{opcoes}),
    };
  }

  return {
    id        => $survey->{id} + 0,
    titulo    => $survey->{titulo},
    descricao => $survey->{descricao},
    perguntas => \@out,
  };
}

# ---------------------------------------------------------------
# registro de resposta
# ---------------------------------------------------------------

sub register_answer ($self, $token, $dispositivo, $respostas) {
  my $survey = $self->_row(
    'SELECT id, status FROM clean.gestor_pesquisas WHERE token::text = ?',
    $token,
  );
  return { error => 'not_found' } unless $survey;
  return { error => 'closed' } unless $survey->{status} eq 'publicada';

  my $dup = $self->_row(
    'SELECT id FROM clean.gestor_pesquisas_respostas
     WHERE pesquisa_id = ? AND identificador_dispositivo = ?',
    $survey->{id} + 0, $dispositivo,
  );
  return { error => 'already_answered' } if $dup;

  my $perguntas = $self->_rows(
    'SELECT id, tipo, obrigatoria, opcoes
     FROM   clean.gestor_pesquisas_perguntas
     WHERE  pesquisa_id = ?
     ORDER  BY ordem',
    $survey->{id} + 0,
  );

  my %por_id = map { $_->{id} + 0 => $_ } @$perguntas;
  my %itens;   # pergunta_id => arrayref de {opcao_id, valor_texto}

  for my $r (@$respostas) {
    my $pid = $r->{pergunta_id};
    return { error => 'validation', detalhe => 'pergunta_id inválido' }
      unless defined $pid && exists $por_id{$pid + 0};

    my $p = $por_id{$pid + 0};
    if ($p->{tipo} eq 'texto') {
      my $txt = $r->{valor_texto} // '';
      $txt =~ s/^\s+|\s+$//g;
      return { error => 'validation', detalhe => "Resposta de texto inválida para a pergunta #$pid" }
        unless length($txt) && length($txt) <= 500;
      push @{ $itens{$pid + 0} }, { opcao_id => undef, valor_texto => $txt };
    }
    else {
      my $opcoes = $self->_decode_opcoes($p->{opcoes}) // [];
      my %ok = map { $_->{id} => 1 } @$opcoes;

      my $oids = $r->{opcao_id};
      $oids = [] unless defined $oids;
      $oids = [ $oids ] if ref $oids ne 'ARRAY';

      if ($p->{tipo} eq 'unica' || $p->{tipo} eq 'dropdown') {
        return { error => 'validation', detalhe => "Pergunta #$pid exige exatamente uma opção" }
          unless @$oids == 1;
      }

      my (%seen, @norm);
      for my $oid (@$oids) {
        return { error => 'validation', detalhe => "Opção inválida na pergunta #$pid" } unless $ok{$oid};
        next if $seen{$oid}++;
        push @norm, { opcao_id => "$oid", valor_texto => undef };
      }
      push @{ $itens{$pid + 0} }, @norm;
    }
  }

  # obrigatórias: precisam de pelo menos 1 item
  for my $p (@$perguntas) {
    next unless $p->{obrigatoria};
    return { error => 'validation', detalhe => "Pergunta obrigatória #$p->{id} sem resposta" }
      unless @{ $itens{ $p->{id} } || [] };
  }

  my $resposta_id;
  $self->schema->storage->txn_do(sub {
    my $row = $self->_row(
      'INSERT INTO clean.gestor_pesquisas_respostas (pesquisa_id, identificador_dispositivo)
       VALUES (?, ?)
       RETURNING id',
      $survey->{id} + 0, $dispositivo,
    );
    $resposta_id = $row->{id} + 0;
    for my $pid (keys %itens) {
      for my $it (@{ $itens{$pid} }) {
        $self->_rows(
          'INSERT INTO clean.gestor_pesquisas_respostas_itens (resposta_id, pergunta_id, opcao_id, valor_texto)
           VALUES (?, ?, ?, ?)',
          $resposta_id, $pid, $it->{opcao_id}, $it->{valor_texto},
        );
      }
    }
  });

  return { ok => 1, id => $resposta_id };
}

# ---------------------------------------------------------------
# resultados (dashboard do gestor)
# ---------------------------------------------------------------

sub survey_results ($self, $id) {
  my $n = $self->_row(
    'SELECT COUNT(*) AS c FROM clean.gestor_pesquisas_respostas WHERE pesquisa_id = ?',
    $id + 0,
  );
  $n = ($n ? $n->{c} : 0) + 0;

  my $perguntas = $self->_rows(
    'SELECT id, ordem, texto, tipo, opcoes
     FROM   clean.gestor_pesquisas_perguntas
     WHERE  pesquisa_id = ?
     ORDER  BY ordem',
    $id + 0,
  );

  my @out;
  for my $p (@$perguntas) {
    my $entry = {
      id        => $p->{id} + 0,
      ordem     => $p->{ordem} + 0,
      texto     => $p->{texto},
      tipo      => $p->{tipo},
      n_respondidas => 0,
      pct       => 0,
    };

    if ($p->{tipo} eq 'texto') {
      my $rows = $self->_rows(
        'SELECT i.valor_texto, r.respondida_em
         FROM   clean.gestor_pesquisas_respostas_itens i
         JOIN   clean.gestor_pesquisas_respostas r ON r.id = i.resposta_id
         WHERE  i.pergunta_id = ?
         ORDER  BY r.respondida_em DESC',
        $p->{id} + 0,
      );
      my @textos = map { { texto => $_->{valor_texto}, respondida_em => $_->{respondida_em} } } @$rows;
      $entry->{respostas_texto} = \@textos;
      $entry->{n_respondidas}   = scalar @textos;
      $entry->{pct}             = $n ? int(100 * @textos / $n) : 0;
    }
    else {
      my $opcoes = $self->_decode_opcoes($p->{opcoes}) // [];
      my $contagens = $self->_rows(
        'SELECT opcao_id, COUNT(*) AS c
         FROM   clean.gestor_pesquisas_respostas_itens
         WHERE  pergunta_id = ?
         GROUP  BY opcao_id',
        $p->{id} + 0,
      );
      my %count = map { $_->{opcao_id} => $_->{c} + 0 } @$contagens;
      my $total = 0;
      $total += $_ for values %count;

      $entry->{opcoes} = [
        map {
          my $c = $count{ $_->{id} } || 0;
          {
            id    => $_->{id},
            label => $_->{label},
            count => $c,
            pct   => $total ? int(100 * $c / $total) : 0,
          }
        } @$opcoes
      ];
      $entry->{n_respondidas} = $total;
      $entry->{pct}           = $n ? int(100 * $total / $n) : 0;
    }

    push @out, $entry;
  }

  return { n_respostas => $n, perguntas => \@out };
}

# ---------------------------------------------------------------
# helpers (duplicados das roles irmãs; "última composição vence")
# ---------------------------------------------------------------

sub _decode_opcoes ($self, $json) {
  return undef unless defined $json;
  my $decoded = eval { Mojo::JSON::decode_json($json) };
  return $decoded;
}

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0];
}

1;