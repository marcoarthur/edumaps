package EduMaps::Roles::Business::Gestor::Relatorios;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON ();

# Assistente de Relatório (#219): recorte-padrão da escola do gestor e as
# tabelas de referência usadas para validar o `geotag` ({nivel, codigo}).
# Fonte: clean.censo_escolas (edição mais recente em que a escola aparece).
#
# Fase 3: relatórios salvos (clean.relatorios_salvos) — fotografia do
# ReportResult de um job relatorio_gerar, escopo do gestor da sessão.

requires qw(schema);

# co_regiao do Censo (1..5) -> sigla do contrato do geotag.
our %REGIAO_SIGLA = (1 => 'N', 2 => 'NE', 3 => 'SE', 4 => 'S', 5 => 'CO');

our %REGIAO_NOME = (
  N  => 'Norte',
  NE => 'Nordeste',
  SE => 'Sudeste',
  S  => 'Sul',
  CO => 'Centro-Oeste',
);

our %UF_NOME = (
  AC => 'Acre',             AL => 'Alagoas',            AP => 'Amapá',
  AM => 'Amazonas',         BA => 'Bahia',              CE => 'Ceará',
  DF => 'Distrito Federal', ES => 'Espírito Santo',     GO => 'Goiás',
  MA => 'Maranhão',         MT => 'Mato Grosso',        MS => 'Mato Grosso do Sul',
  MG => 'Minas Gerais',     PA => 'Pará',               PB => 'Paraíba',
  PR => 'Paraná',           PE => 'Pernambuco',         PI => 'Piauí',
  RJ => 'Rio de Janeiro',   RN => 'Rio Grande do Norte', RS => 'Rio Grande do Sul',
  RO => 'Rondônia',         RR => 'Roraima',            SC => 'Santa Catarina',
  SP => 'São Paulo',        SE => 'Sergipe',            TO => 'Tocantins',
);

our @NIVEIS = qw(escola municipio uf regiao);

# Recorte-padrão da escola: escola, município, UF e região. Devolve undef se
# a escola não está no Censo.
sub recorte_padrao($self, $cod_inep) {
  return unless defined $cod_inep && $cod_inep =~ /^\d{8}$/;

  my $row = $self->schema->resultset('CensoEscolas')
    ->search_rs(
      { co_entidade => $cod_inep },
      { order_by => { -desc => 'nu_ano_censo' }, rows => 1 },
    )
    ->columns([qw(co_entidade no_entidade co_municipio no_municipio
                  sg_uf no_uf co_regiao no_regiao)])
    ->as_hash->first;
  return unless $row;

  my $uf     = defined $row->{sg_uf} ? uc $row->{sg_uf} : undef;
  my $regiao = defined $row->{co_regiao} ? $REGIAO_SIGLA{ $row->{co_regiao} } : undef;

  return {
    escola => {
      cod_inep => '' . $row->{co_entidade},
      nome     => $row->{no_entidade},
    },
    municipio => {
      codigo => defined $row->{co_municipio} ? sprintf('%07d', $row->{co_municipio}) : undef,
      nome   => $row->{no_municipio},
    },
    uf => {
      codigo => $uf,
      nome   => $row->{no_uf} // ($uf ? $UF_NOME{$uf} : undef),
    },
    regiao => {
      codigo => $regiao,
      nome   => $row->{no_regiao} // ($regiao ? $REGIAO_NOME{$regiao} : undef),
    },
  };
}

# Valida o geotag {nivel, codigo} contra o contrato. `escola` só é aceito
# para o INEP do próprio gestor. Devolve ({nivel, codigo}, undef) normalizado
# ou (undef, mensagem de erro).
sub geotag_valido($self, $geotag, $cod_inep_gestor) {
  return (undef, 'geotag deve ser um objeto {nivel, codigo}')
    unless ref $geotag eq 'HASH';

  my $nivel  = $geotag->{nivel}  // '';
  my $codigo = $geotag->{codigo} // '';
  return (undef, 'geotag.nivel inválido (use escola, municipio, uf ou regiao)')
    unless !ref $nivel && grep { $_ eq $nivel } @NIVEIS;
  return (undef, 'geotag.codigo inválido') if ref $codigo;
  $codigo = "$codigo";

  if ($nivel eq 'municipio') {
    return (undef, 'geotag.codigo do município deve ter 7 dígitos')
      unless $codigo =~ /^\d{7}\z/;
  }
  elsif ($nivel eq 'uf') {
    return (undef, 'geotag.codigo da UF deve ser uma sigla válida (ex.: SP)')
      unless $codigo =~ /^[A-Z]{2}\z/ && exists $UF_NOME{$codigo};
  }
  elsif ($nivel eq 'regiao') {
    return (undef, 'geotag.codigo da região deve ser N, NE, SE, S ou CO')
      unless exists $REGIAO_NOME{$codigo};
  }
  else {    # escola
    return (undef, 'Relatórios por escola só são permitidos para a sua própria escola.')
      unless $codigo =~ /^\d{8}\z/ && $codigo eq ('' . ($cod_inep_gestor // ''));
  }

  return ({ nivel => $nivel, codigo => $codigo }, undef);
}

# ---------------------------------------------------------------------------
# Relatórios salvos (Fase 3)
# ---------------------------------------------------------------------------

# Colunas do resumo, com as datas já em ISO 8601 UTC ("...Z").
my $COLS_RESUMO = q{
  id, titulo, tema_id, tema_titulo, nivel, codigo, recorte_nome,
  opcoes::text AS opcoes,
  to_char(gerado_em  AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS gerado_em,
  to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS salvo_em
};

# Plumber pode serializar escalares como arrays de 1 elemento.
sub _escalar ($v) {
  return $v->[0] if ref $v eq 'ARRAY' && @$v == 1;
  return $v;
}

sub _texto ($v) {
  $v = _escalar($v);
  return undef if !defined $v || ref $v;
  $v = "$v";
  return length $v ? $v : undef;
}

# jsonb lido do banco: o DBD::Pg devolve caracteres (UTF-8 já decodificado).
sub _json_do_banco ($s) {
  return undef unless defined $s;
  return utf8::is_utf8($s) ? Mojo::JSON::from_json($s) : Mojo::JSON::decode_json($s);
}

sub _salvo_resumo ($r) {
  return {
    id      => $r->{id} + 0,
    titulo  => $r->{titulo},
    tema    => { id => $r->{tema_id}, titulo => $r->{tema_titulo} },
    recorte => { nivel => $r->{nivel}, codigo => $r->{codigo}, nome => $r->{recorte_nome} },
    opcoes    => _json_do_banco($r->{opcoes}) // {},
    gerado_em => $r->{gerado_em},
    salvo_em  => $r->{salvo_em},
  };
}

# Salva a fotografia de um job relatorio_gerar terminado. $info é o
# `minion->job($id)->info` (já validado pelo controller: task, posse e
# state finished). O conteúdo vem SEMPRE do resultado do job — nunca do
# cliente. Devolve ($resumo, $novo) ou () se o resultado do job é inválido.
# Idempotente por (gestor_id, job_id).
sub salvar_relatorio ($self, $gestor_id, $cod_inep, $job_id, $info) {
  my $args   = ref $info->{args} eq 'ARRAY' ? $info->{args}[0] : undef;
  my $result = $info->{result};
  return unless ref $args eq 'HASH' && ref $result eq 'HASH';

  my $geotag = ref $args->{geotag} eq 'HASH' ? $args->{geotag} : {};
  my $nivel  = _texto($geotag->{nivel});
  my $codigo = _texto($geotag->{codigo});
  my $tema_id = _texto($args->{tema});
  return unless $nivel && (grep { $_ eq $nivel } @NIVEIS) && defined $codigo && defined $tema_id;

  my $opcoes = ref $args->{opcoes} eq 'HASH' ? $args->{opcoes} : {};

  my $tema_res    = ref $result->{tema} eq 'HASH' ? $result->{tema} : {};
  my $recorte_res = ref $result->{recorte} eq 'HASH' ? $result->{recorte} : {};
  my $tema_titulo = _texto($tema_res->{titulo}) // $tema_id;
  my $titulo      = _texto($result->{titulo}) // $tema_titulo;
  my $recorte_nome = _texto($recorte_res->{nome});

  # gerado_em do ReportResult (ISO 8601); sem ele (ou malformado), o fim do
  # job — a coluna é NOT NULL e a fotografia precisa de uma data.
  my $gerado_em = _texto($result->{gerado_em});
  undef $gerado_em
    unless defined $gerado_em && $gerado_em =~ /^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}(:?\d{2})?)?\z/;
  my $finished = $info->{finished} // time;

  # A fotografia não guarda o cache_hit (é metadado da entrega, não do relatório).
  my %conteudo = %$result;
  delete $conteudo{cache_hit};

  my $novo = $self->_row(
    qq{INSERT INTO clean.relatorios_salvos
         (gestor_id, cod_inep, job_id, tema_id, tema_titulo, nivel, codigo,
          recorte_nome, opcoes, titulo, conteudo, gerado_em)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb, ?, ?::jsonb,
               COALESCE(?::timestamptz, to_timestamp(?)))
       ON CONFLICT (gestor_id, job_id) DO NOTHING
       RETURNING $COLS_RESUMO},
    $gestor_id, $cod_inep, $job_id, $tema_id, $tema_titulo, $nivel, $codigo,
    $recorte_nome, Mojo::JSON::to_json($opcoes), $titulo,
    Mojo::JSON::to_json(\%conteudo), $gerado_em, $finished,
  );
  return (_salvo_resumo($novo), 1) if $novo;

  # Já salvo antes (mesmo gestor e job): devolve o existente.
  my $existente = $self->_row(
    "SELECT $COLS_RESUMO FROM clean.relatorios_salvos WHERE gestor_id = ? AND job_id = ?",
    $gestor_id, $job_id,
  ) or return;
  return (_salvo_resumo($existente), 0);
}

# Lista paginada dos salvos do gestor (mais recentes primeiro).
sub listar_relatorios_salvos ($self, $gestor_id, $page = 1, $per_page = 20) {
  my $total = $self->_row(
    'SELECT count(*) AS n FROM clean.relatorios_salvos WHERE gestor_id = ?', $gestor_id,
  )->{n};
  my $rows = $self->_rows(
    "SELECT $COLS_RESUMO FROM clean.relatorios_salvos
      WHERE gestor_id = ?
      ORDER BY created_at DESC, id DESC
      LIMIT ? OFFSET ?",
    $gestor_id, $per_page, ($page - 1) * $per_page,
  );
  return {
    items    => [ map { _salvo_resumo($_) } @$rows ],
    total    => $total + 0,
    page     => $page + 0,
    per_page => $per_page + 0,
  };
}

# Detalhe: resumo + `relatorio` (o ReportResult gravado). undef se não é do gestor.
sub relatorio_salvo ($self, $gestor_id, $id) {
  my $r = $self->_row(
    "SELECT $COLS_RESUMO, conteudo::text AS conteudo
       FROM clean.relatorios_salvos WHERE id = ? AND gestor_id = ?",
    $id, $gestor_id,
  ) or return;
  my $salvo = _salvo_resumo($r);
  $salvo->{relatorio} = _json_do_banco($r->{conteudo});
  return $salvo;
}

# Exclui um salvo do gestor. 1 se excluiu, 0 se não existe/não é dele.
sub excluir_relatorio_salvo ($self, $gestor_id, $id) {
  my $r = $self->_row(
    'DELETE FROM clean.relatorios_salvos WHERE id = ? AND gestor_id = ? RETURNING id',
    $id, $gestor_id,
  );
  return $r ? 1 : 0;
}

sub _rows ($self, $sql, @binds) {
  my $rows;
  $self->schema->storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0];
}

1;
