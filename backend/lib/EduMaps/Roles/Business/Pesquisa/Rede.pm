package EduMaps::Roles::Business::Pesquisa::Rede;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(sha256_hex);
use Crypt::URandom qw(urandom);
use MIME::Base64 qw(encode_base64url);
use Mojo::JSON ();

# Papel da secretaria (#394, visão da rede #375).
#
# Conta de rede: linha em clean.gestores com access_role = 'rede' e cod_inep
# reservado 0 (como o admin). Nasce SEM senha; a pessoa define a senha por um
# convite de uso único (32 bytes em base64url, só o SHA-256 no banco, 7 dias,
# um convite novo invalida o anterior — mesmo padrão do "esqueci minha senha").
#
# Vínculo: dependência (2 estadual, 3 municipal) + município, concedido e
# revogado pelo admin. Uma escola é da rede quando a linha MAIS RECENTE dela no
# Censo bate dependência e município com um vínculo ativo; a aplicação confere
# isso a cada pedido (revogar corta o acesso na hora).

requires qw(schema _row _rows _hash_senha);

use constant CONVITE_DIAS => 7;
our %DEPENDENCIA = (2 => 'Estadual', 3 => 'Municipal');

package EduMaps::Roles::Business::Pesquisa::Rede::Erro {
  use Mojo::Base -base, -signatures;
  has [qw(status mensagem)];
  use overload '""' => sub ($s, @) { $s->mensagem }, fallback => 1;
}

sub _rd_falha ($self, $status, $mensagem) {
  die EduMaps::Roles::Business::Pesquisa::Rede::Erro->new(status => $status, mensagem => $mensagem);
}

sub _rd_token_hash ($self, $token) { sha256_hex($token // '') }

sub _rd_auditar ($self, $gestor_id, $ator_id, $acao, $detalhes = {}) {
  $self->_rows(
    'INSERT INTO clean.rede_auditoria (gestor_id, ator_id, acao, detalhes) VALUES (?, ?, ?, ?::jsonb)',
    $gestor_id, $ator_id, $acao, Mojo::JSON::encode_json($detalhes));
}

sub _rd_conta_ou_404 ($self, $gestor_id) {
  my $g = $self->_row(
    q{SELECT id, nome, email, cargo, senha_hash IS NOT NULL AS senha_definida, created_at
        FROM clean.gestores WHERE id = ? AND access_role = 'rede'}, ($gestor_id // 0) + 0);
  $self->_rd_falha(404, 'Conta de rede não encontrada.') unless $g;
  return $g;
}

# ---------------------------------------------------------------------------
# contas e convites (admin)
# ---------------------------------------------------------------------------

# { nome, email, cargo } -> { conta, convite => { token, expira_em } }
sub rede_conta_criar ($self, $ator_id, $p) {
  my $email = lc($p->{email} // '');
  $self->_rd_falha(409, 'Este e-mail já tem conta na plataforma.')
    if $self->_row('SELECT 1 FROM clean.gestores WHERE lower(email) = ?', $email);
  my ($id, $convite);
  $self->schema->storage->txn_do(sub {
    my $g = $self->_row(
      q{INSERT INTO clean.gestores (cod_inep, nome, email, cargo, access_role)
        VALUES (0, ?, ?, ?, 'rede') RETURNING id},
      $p->{nome}, $email, $p->{cargo});
    $id = $g->{id} + 0;
    $self->_rd_auditar($id, $ator_id, 'conta_criada', { email => $email });
    $convite = $self->_rd_convite_novo($ator_id, $id);
  });
  return { conta => $self->rede_conta($id), convite => $convite };
}

sub rede_convite_gerar ($self, $ator_id, $gestor_id) {
  $self->_rd_conta_ou_404($gestor_id);
  my $convite;
  $self->schema->storage->txn_do(sub { $convite = $self->_rd_convite_novo($ator_id, $gestor_id) });
  return $convite;
}

sub _rd_convite_novo ($self, $ator_id, $gestor_id) {
  $self->_rows(
    'UPDATE clean.rede_convites SET invalidado_em = NOW()
      WHERE gestor_id = ? AND usado_em IS NULL AND invalidado_em IS NULL', $gestor_id + 0);
  my $token = encode_base64url(urandom(32));
  my $r = $self->_row(
    'INSERT INTO clean.rede_convites (gestor_id, token_hash, expira_em, criado_por)
     VALUES (?, ?, NOW() + make_interval(days => ?), ?) RETURNING expira_em',
    $gestor_id + 0, $self->_rd_token_hash($token), CONVITE_DIAS, $ator_id);
  $self->_rd_auditar($gestor_id + 0, $ator_id, 'convite_gerado', { expira_em => $r->{expira_em} });
  return { token => $token, expira_em => $r->{expira_em} };
}

# Situação do convite para a página pública: { situacao, nome, email } ou undef
# (token inexistente). situacao: valido | usado | vencido | substituido.
sub rede_convite_info ($self, $token) {
  return unless defined $token && $token =~ /^[A-Za-z0-9_-]{43}$/;
  my $c = $self->_row(
    q{SELECT g.nome, g.email,
             CASE WHEN c.usado_em IS NOT NULL THEN 'usado'
                  WHEN c.invalidado_em IS NOT NULL THEN 'substituido'
                  WHEN c.expira_em <= NOW() THEN 'vencido'
                  ELSE 'valido' END AS situacao
        FROM clean.rede_convites c JOIN clean.gestores g ON g.id = c.gestor_id
       WHERE c.token_hash = ?}, $self->_rd_token_hash($token));
  return $c;
}

# Usa o convite: grava a senha e encerra sessões. Devolve { id, email } ou
# undef (inexistente, vencido, usado ou substituído).
sub rede_convite_aceitar ($self, $token, $senha) {
  return unless defined $token && $token =~ /^[A-Za-z0-9_-]{43}$/;
  my $gestor;
  $self->schema->storage->txn_do(sub {
    my $r = $self->_row(
      'UPDATE clean.rede_convites SET usado_em = NOW()
        WHERE token_hash = ? AND usado_em IS NULL AND invalidado_em IS NULL AND expira_em > NOW()
        RETURNING gestor_id', $self->_rd_token_hash($token)) or return;
    $gestor = $self->_row(
      q{UPDATE clean.gestores SET senha_hash = ?, updated_at = NOW()
         WHERE id = ? AND access_role = 'rede' RETURNING id, email},
      $self->_hash_senha($senha), $r->{gestor_id} + 0) or return;
    $self->_rows('DELETE FROM clean.sessoes WHERE gestor_id = ?', $gestor->{id} + 0);
    $self->_rd_auditar($gestor->{id} + 0, $gestor->{id} + 0, 'convite_aceito');
  });
  return $gestor;
}

# ---------------------------------------------------------------------------
# vínculos (admin)
# ---------------------------------------------------------------------------

sub rede_vinculo_conceder ($self, $ator_id, $gestor_id, $tp, $co_municipio) {
  $self->_rd_conta_ou_404($gestor_id);
  $self->_rd_falha(400, 'Rede concedível: dependência 2 (estadual) ou 3 (municipal).')
    unless defined $tp && exists $DEPENDENCIA{$tp};
  my $mun = $self->_rd_municipio($co_municipio)
    or $self->_rd_falha(400, 'Município não encontrado no Censo.');
  $self->_rd_falha(409, 'Esta conta já tem esta rede.')
    if $self->_row(
      'SELECT 1 FROM clean.rede_vinculos
        WHERE gestor_id = ? AND tp_dependencia = ? AND co_municipio = ? AND revogado_em IS NULL',
      $gestor_id + 0, $tp + 0, $co_municipio + 0);
  my $v;
  $self->schema->storage->txn_do(sub {
    $v = $self->_row(
      'INSERT INTO clean.rede_vinculos (gestor_id, tp_dependencia, co_municipio, concedido_por)
       VALUES (?, ?, ?, ?) RETURNING id',
      $gestor_id + 0, $tp + 0, $co_municipio + 0, $ator_id);
    $self->_rd_auditar($gestor_id + 0, $ator_id, 'vinculo_concedido',
      { vinculo_id => $v->{id} + 0, tp_dependencia => $tp + 0, co_municipio => $co_municipio + 0 });
  });
  return (grep { $_->{id} == $v->{id} } @{ $self->rede_vinculos_ativos($gestor_id) })[0];
}

sub rede_vinculo_revogar ($self, $ator_id, $vinculo_id) {
  my $v;
  $self->schema->storage->txn_do(sub {
    $v = $self->_row(
      'UPDATE clean.rede_vinculos SET revogado_em = NOW(), revogado_por = ?
        WHERE id = ? AND revogado_em IS NULL
        RETURNING gestor_id, tp_dependencia, co_municipio',
      $ator_id, ($vinculo_id // 0) + 0) or return;
    $self->_rd_auditar($v->{gestor_id} + 0, $ator_id, 'vinculo_revogado',
      { vinculo_id => $vinculo_id + 0, tp_dependencia => $v->{tp_dependencia} + 0,
        co_municipio => $v->{co_municipio} + 0 });
  });
  $self->_rd_falha(404, 'Vínculo não encontrado ou já revogado.') unless $v;
  return 1;
}

sub _rd_municipio ($self, $co_municipio) {
  return unless defined $co_municipio && $co_municipio =~ /^\d{7}$/;
  return $self->_row(
    'SELECT co_municipio, no_municipio, sg_uf FROM clean.censo_escolas
      WHERE co_municipio = ? ORDER BY nu_ano_censo DESC LIMIT 1', $co_municipio + 0);
}

# ---------------------------------------------------------------------------
# leitura (admin e a própria conta)
# ---------------------------------------------------------------------------

sub rede_contas ($self) {
  my $contas = $self->_rows(
    q{SELECT g.id FROM clean.gestores g WHERE g.access_role = 'rede' ORDER BY g.nome, g.id});
  return [ map { $self->rede_conta($_->{id}) } @$contas ];
}

sub rede_conta ($self, $gestor_id) {
  my $g = $self->_rd_conta_ou_404($gestor_id);
  my $convite = $self->_row(
    'SELECT expira_em FROM clean.rede_convites
      WHERE gestor_id = ? AND usado_em IS NULL AND invalidado_em IS NULL AND expira_em > NOW()
      ORDER BY id DESC LIMIT 1', $gestor_id + 0);
  return {
    id               => $g->{id} + 0,
    nome             => $g->{nome},
    email            => $g->{email},
    cargo            => $g->{cargo},
    senha_definida   => $g->{senha_definida} ? Mojo::JSON::true : Mojo::JSON::false,
    convite_pendente => $convite ? { expira_em => $convite->{expira_em} } : undef,
    vinculos         => $self->rede_vinculos_ativos($gestor_id),
    criada_em        => $g->{created_at},
  };
}

sub rede_vinculos_ativos ($self, $gestor_id) {
  my $rows = $self->_rows(
    q{SELECT v.id, v.tp_dependencia, v.co_municipio, v.concedido_em,
             (SELECT c.no_municipio FROM clean.censo_escolas c WHERE c.co_municipio = v.co_municipio
               ORDER BY c.nu_ano_censo DESC LIMIT 1) AS no_municipio,
             (SELECT c.sg_uf FROM clean.censo_escolas c WHERE c.co_municipio = v.co_municipio
               ORDER BY c.nu_ano_censo DESC LIMIT 1) AS sg_uf
        FROM clean.rede_vinculos v
       WHERE v.gestor_id = ? AND v.revogado_em IS NULL
       ORDER BY v.co_municipio, v.tp_dependencia}, ($gestor_id // 0) + 0);
  return [ map { {
    id             => $_->{id} + 0,
    tp_dependencia => $_->{tp_dependencia} + 0,
    dependencia    => $DEPENDENCIA{ $_->{tp_dependencia} },
    co_municipio   => $_->{co_municipio} + 0,
    municipio      => $_->{no_municipio},
    uf             => $_->{sg_uf},
    concedido_em   => $_->{concedido_em},
  } } @$rows ];
}

sub rede_auditoria ($self, $gestor_id) {
  $self->_rd_conta_ou_404($gestor_id);
  my $rows = $self->_rows(
    'SELECT a.id, a.acao, a.detalhes::text AS detalhes, a.criado_em, g.nome AS ator
       FROM clean.rede_auditoria a LEFT JOIN clean.gestores g ON g.id = a.ator_id
      WHERE a.gestor_id = ? ORDER BY a.criado_em DESC, a.id DESC LIMIT 200', $gestor_id + 0);
  return [ map { { id => $_->{id} + 0, acao => $_->{acao}, ator => $_->{ator},
                   detalhes => Mojo::JSON::decode_json($_->{detalhes}), criado_em => $_->{criado_em} } } @$rows ];
}

# ---------------------------------------------------------------------------
# escolas da rede (autorização)
# ---------------------------------------------------------------------------

# A linha mais recente da escola no Censo, se ela estiver num vínculo ativo da
# conta; undef se não estiver (fora da rede, vínculo revogado ou escola
# inexistente). Usada pela autorização de toda rota da rede.
sub rede_escola ($self, $gestor_id, $cod_inep) {
  return unless defined $cod_inep && $cod_inep =~ /^\d{8}$/;
  return $self->_row(
    q{SELECT u.co_entidade, u.no_entidade, u.tp_dependencia, u.co_municipio, u.no_municipio, u.sg_uf
        FROM (SELECT DISTINCT ON (co_entidade) co_entidade, no_entidade, tp_dependencia, co_municipio,
                     no_municipio, sg_uf
                FROM clean.censo_escolas WHERE co_entidade = ?
               ORDER BY co_entidade, nu_ano_censo DESC) u
        JOIN clean.rede_vinculos v
          ON v.gestor_id = ? AND v.revogado_em IS NULL
         AND v.tp_dependencia = u.tp_dependencia AND v.co_municipio = u.co_municipio},
    $cod_inep + 0, ($gestor_id // 0) + 0);
}

# Escolas em atividade das redes da conta (linha mais recente de cada escola
# no Censo; uma escola que mudou de município entra pela situação atual).
sub rede_escolas ($self, $gestor_id) {
  my $rows = $self->_rows(
    q{WITH v AS (
        SELECT tp_dependencia, co_municipio FROM clean.rede_vinculos
         WHERE gestor_id = ? AND revogado_em IS NULL
      ), ult AS (
        SELECT DISTINCT ON (c.co_entidade) c.co_entidade, c.no_entidade, c.tp_dependencia,
               c.co_municipio, c.no_municipio, c.sg_uf, c.tp_situacao_funcionamento
          FROM clean.censo_escolas c
         WHERE c.co_entidade IN (SELECT co_entidade FROM clean.censo_escolas
                                  WHERE co_municipio IN (SELECT co_municipio FROM v))
         ORDER BY c.co_entidade, c.nu_ano_censo DESC
      )
      SELECT u.* FROM ult u
        JOIN v ON v.tp_dependencia = u.tp_dependencia AND v.co_municipio = u.co_municipio
       WHERE COALESCE(u.tp_situacao_funcionamento, 1) = 1
       ORDER BY u.no_municipio, u.no_entidade}, ($gestor_id // 0) + 0);
  return [ map { {
    cod_inep     => $_->{co_entidade} + 0,
    nome         => $_->{no_entidade},
    dependencia  => $DEPENDENCIA{ $_->{tp_dependencia} },
    co_municipio => $_->{co_municipio} + 0,
    municipio    => $_->{no_municipio},
    uf           => $_->{sg_uf},
  } } @$rows ];
}

1;
