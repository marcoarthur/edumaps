package EduMaps::Roles::Business::Pesquisa::Gestores;
use Mojo::Base -role, -signatures;
use utf8;

# Gestores escolares: cadastro/upsert por e-mail (sem login no projeto ainda).
# LGPD: o CPF é armazenado, mas NUNCA é devolvido completo — apenas mascarado.

requires qw(schema);

sub upsert_gestor ($self, $params = {}) {
  my $sql = <<~'SQL';
    INSERT INTO clean.gestores (cod_inep, nome, email, telefone, cargo, cpf)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT (email) DO UPDATE SET
      cod_inep   = EXCLUDED.cod_inep,
      nome       = EXCLUDED.nome,
      telefone   = EXCLUDED.telefone,
      cargo      = EXCLUDED.cargo,
      cpf        = COALESCE(EXCLUDED.cpf, clean.gestores.cpf),
      updated_at = NOW()
    RETURNING id, cod_inep, nome, email, telefone, cargo, cpf
  SQL

  my $row = $self->_row(
    $sql,
    $params->{cod_inep} + 0,
    $params->{nome},
    $params->{email},
    $params->{telefone} // undef,
    $params->{cargo}    // undef,
    $params->{cpf}      // undef,
  ) or return;

  return {
    id         => $row->{id} + 0,
    cod_inep   => $row->{cod_inep} + 0,
    nome       => $row->{nome},
    email      => $row->{email},
    telefone   => $row->{telefone},
    cargo      => $row->{cargo},
    cpf_masc   => $self->_mask_cpf($row->{cpf}),
    created_at => $row->{created_at},
    updated_at => $row->{updated_at},
  };
}

sub gestor_for_id ($self, $id) {
  return $self->_row(
    'SELECT id, cod_inep, nome, email FROM clean.gestores WHERE id = ?',
    $id + 0,
  );
}

sub _mask_cpf ($self, $cpf) {
  return undef unless defined $cpf && $cpf =~ /^\d{11}$/;
  return '***.***.***-' . substr($cpf, -3);
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