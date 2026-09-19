package EduMaps::Roles::Business::Pesquisa::Surveys;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw();

# Pesquisas do gestor: CRUD de pesquisas (rascunho -> publicada) com perguntas
# e opções. Autosave = PUT substitui todas as perguntas em uma transação.

requires qw(schema);

our @TIPOS = qw(unica multipla dropdown texto);

sub create_survey ($self, $params = {}) {
  my $gestor = $self->gestor_for_id($params->{gestor_id} || 0) or return;

  my $survey_id;
  $self->schema->storage->txn_do(sub {
    my $row = $self->_row(
      'INSERT INTO clean.gestor_pesquisas (cod_inep, gestor_id, titulo, descricao)
       VALUES (?, ?, ?, ?)
       RETURNING id',
      $gestor->{cod_inep}, $gestor->{id}, $params->{titulo}, $params->{descricao} // undef,
    );
    $survey_id = $row->{id};
    $self->_replace_perguntas($survey_id, $params->{perguntas} // []);
  });

  return $self->survey_detail($survey_id);
}

sub survey_detail ($self, $id) {
  my $survey = $self->_row(
    'SELECT s.id, s.cod_inep, s.gestor_id, s.titulo, s.descricao, s.status, s.token,
            s.created_at, s.updated_at,
            g.nome AS gestor_nome, g.email AS gestor_email
     FROM clean.gestor_pesquisas s
     JOIN clean.gestores g ON g.id = s.gestor_id
     WHERE s.id = ?',
    $id + 0,
  ) or return;

  my $perguntas = $self->_rows(
    'SELECT id, ordem, texto, tipo, obrigatoria, opcoes
     FROM   clean.gestor_pesquisas_perguntas
     WHERE  pesquisa_id = ?
     ORDER  BY ordem',
    $id + 0,
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

  $survey->{id}        = $survey->{id} + 0;
  $survey->{cod_inep}  = $survey->{cod_inep} + 0;
  $survey->{gestor_id} = $survey->{gestor_id} + 0;
  $survey->{token}     = $survey->{token};
  $survey->{perguntas} = \@out;
  $survey->{gestor} = {
    nome  => $survey->{gestor_nome},
    email => $survey->{gestor_email},
  };
  delete @$survey{qw(gestor_nome gestor_email)};
  return $survey;
}

sub list_surveys ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT s.id, s.cod_inep, s.gestor_id, s.titulo, s.status, s.token,
            s.created_at, s.updated_at, g.nome AS gestor_nome,
            COUNT(p.id) AS n_perguntas
     FROM   clean.gestor_pesquisas s
     JOIN   clean.gestores g ON g.id = s.gestor_id
     LEFT JOIN clean.gestor_pesquisas_perguntas p ON p.pesquisa_id = s.id
     WHERE  s.cod_inep = ?
     GROUP  BY s.id, g.nome
     ORDER  BY s.updated_at DESC',
    $cod_inep + 0,
  );

  my @out;
  for my $r (@$rows) {
    push @out, {
      id         => $r->{id} + 0,
      cod_inep   => $r->{cod_inep} + 0,
      gestor_id  => $r->{gestor_id} + 0,
      titulo     => $r->{titulo},
      status     => $r->{status},
      token      => $r->{token},
      gestor     => { nome => $r->{gestor_nome} },
      n_perguntas => $r->{n_perguntas} + 0,
      created_at => $r->{created_at},
      updated_at => $r->{updated_at},
    };
  }

  return \@out;
}

sub update_survey ($self, $id, $params = {}) {
  my $found;
  $self->schema->storage->txn_do(sub {
    my $row = $self->_row(
      'UPDATE clean.gestor_pesquisas
       SET    titulo = ?, descricao = ?, updated_at = NOW()
       WHERE  id = ? AND status = \'rascunho\'
       RETURNING id',
      $params->{titulo}, $params->{descricao} // undef, $id + 0,
    );
    $found = $row;
    $self->_replace_perguntas($id + 0, $params->{perguntas} // []) if $row;
  });
  return $found ? $self->survey_detail($id + 0) : undef;
}

sub finalize_survey ($self, $id) {
  my $row = $self->_row(
    'UPDATE clean.gestor_pesquisas
     SET    status = \'publicada\', updated_at = NOW()
     WHERE  id = ? AND status = \'rascunho\'
     RETURNING id',
    $id + 0,
  );
  return $row ? $self->survey_detail($id + 0) : undef;
}

sub delete_survey ($self, $id) {
  my $row = $self->_row(
    'DELETE FROM clean.gestor_pesquisas WHERE id = ? AND status = \'rascunho\' RETURNING id',
    $id + 0,
  );
  return $row ? 1 : undef;
}

sub survey_state ($self, $id) {
  return $self->_row(
    'SELECT id, cod_inep, gestor_id, status FROM clean.gestor_pesquisas WHERE id = ?',
    $id + 0,
  );
}

sub _replace_perguntas ($self, $pesquisa_id, $perguntas) {
  $self->_rows(
    'DELETE FROM clean.gestor_pesquisas_perguntas WHERE pesquisa_id = ?',
    $pesquisa_id,
  );

  my $sql = 'INSERT INTO clean.gestor_pesquisas_perguntas
             (pesquisa_id, ordem, texto, tipo, obrigatoria, opcoes)
             VALUES (?, ?, ?, ?, ?, ?)';
  my $ordem = 1;
  for my $p (@$perguntas) {
    $self->_rows(
      $sql,
      $pesquisa_id,
      $ordem++,
      $p->{texto},
      $p->{tipo},
      $p->{obrigatoria} ? 1 : 0,
      $p->{opcoes} ? Mojo::JSON::encode_json($p->{opcoes}) : undef,
    );
  }
}

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