package EduMaps::Roles::Business::Config::AppConfig;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(decode_json encode_json);
use Carp qw(croak);

# Configuração global do EduMaps (Painel de Configuração). Fonte de verdade
# da árvore exposta em GET /api/admin/config/tree. Cada folha define: key
# (caminho DNS-like), label, description (tooltip), example, type e se é
# sensitive (guardada cifrada com pgcrypto pgp_sym_encrypt — a master key vem
# de EDUMAPS_CONFIG_MASTER_KEY no ambiente do backend, nunca do banco).
#
# Regras:
#   * sensitive=1  -> o valor vive em `secret` (bytea cifrado); a API devolve
#     apenas { set: 0|1 } + metadados, NUNCA o plaintext nem o ciphertext.
#   * sensitive=0  -> o valor vive em `value` (jsonb) e é devolvido em claro.
#   * `updated_by` guarda quem alterou (identificação do admin logado).

requires qw(schema);

# ---------------------------------------------------------------------------
# Definição da árvore de configuração (fonte de verdade — frontend ⇒ GET tree)
# ---------------------------------------------------------------------------
#
# Estrutura: %TREE -> categoria -> { label, children (grupos ou folhas) }.
# Grupo -> { key, label, children } (sub-seção com folhas).
# Folha  -> { key, label, description, example, type, sensitive, enabled }.
# type: text | secret | number | boolean | select (com options).

my %TREE = (
  sistema => {
    label    => 'Sistema',
    children => [
      {
        key         => 'system.installation_name',
        label       => 'Nome da instalação',
        description => 'Nome exibido no cabeçalho e nos e-mails da plataforma.',
        example     => 'Rede Municipal de Ubatuba',
        type        => 'text',
        sensitive   => 0,
        enabled     => 0,
      },
      {
        key         => 'system.timezone',
        label       => 'Fuso horário',
        description => 'Fuso usado para datas e horários exibidos aos gestores.',
        example     => 'America/Sao_Paulo',
        type        => 'text',
        sensitive   => 0,
        enabled     => 0,
      },
    ],
  },
  integracoes => {
    label    => 'Integrações',
    children => [
      {
        key      => 'assistant_censo',
        label    => 'Assistente do Censo',
        children => [
          {
            key         => 'integrations.assistant_censo.api_key',
            label       => 'Chaves',
            description => 'Chave de API do provedor de linguagem (LLM) usado pelo Assistente do Censo. É a senha da conta que responde às perguntas dos gestores.',
            example     => 'chave secreta fornecida pelo provedor (ex.: gsk_..., AIza... ou sk-...)',
            type        => 'secret',
            sensitive   => 1,
            enabled     => 1,
          },
          {
            key         => 'integrations.assistant_censo.provider',
            label       => 'Provedor',
            description => 'Provedor de linguagem (ollama, gemini, openai ou groq).',
            example     => 'gemini',
            type        => 'select',
            options     => [qw(ollama gemini openai groq)],
            sensitive   => 0,
            enabled     => 0,
          },
          {
            key         => 'integrations.assistant_censo.model',
            label       => 'Modelo',
            description => 'Identificador do modelo de linguagem junto ao provedor.',
            example     => 'gemini-flash-lite-latest',
            type        => 'text',
            sensitive   => 0,
            enabled     => 0,
          },
          {
            key         => 'integrations.assistant_censo.url',
            label       => 'URL da API',
            description => 'Base URL da API do provedor (opcional; o padrão do provedor é usado se vazio).',
            example     => 'https://api.openai.com/v1',
            type        => 'text',
            sensitive   => 0,
            enabled     => 0,
          },
        ],
      },
    ],
  },
  aparencia => {
    label    => 'Aparência',
    children => [
      {
        key         => 'appearance.theme',
        label       => 'Tema',
        description => 'Tema visual padrão da plataforma.',
        example     => 'claro',
        type        => 'select',
        options     => [qw(claro escuro)],
        sensitive   => 0,
        enabled     => 0,
      },
    ],
  },
  comportamento => {
    label    => 'Comportamento',
    children => [
      {
        key         => 'behavior.default_ano',
        label       => 'Ano padrão dos dados',
        description => 'Ano usado por padrão nos painéis e consultas com dados por ano.',
        example     => '2025',
        type        => 'number',
        sensitive   => 0,
        enabled     => 0,
      },
    ],
  },
  outros => {
    label    => 'Outros',
    children => [],
  },
);

# ---------------------------------------------------------------------------
# Árvore pública (GET /api/admin/config/tree)
# ---------------------------------------------------------------------------

sub config_tree ($self) {
  my @out;
  for my $cat (qw/sistema integracoes aparencia comportamento outros/) {
    my $c = $TREE{$cat} or next;
    push @out, {
      key      => $cat,
      label    => $c->{label},
      children => [ map { $self->_tree_node($_) } @{ $c->{children} } ],
    };
  }
  return { categories => \@out };
}

sub _tree_node ($self, $node) {
  if ($node->{children}) {
    return {
      key      => $node->{key},
      label    => $node->{label},
      children => [ map { $self->_tree_node($_) } @{ $node->{children} } ],
    };
  }
  return $self->config_item($node->{key});
}

sub _def_for ($self, $key) {
  for my $cat (values %TREE) {
    for my $node (@{ $cat->{children} }) {
      for my $leaf ($node->{children} ? @{ $node->{children} } : ($node)) {
        return $leaf if $leaf->{key} eq $key;
      }
    }
  }
  return;
}

sub is_config_key ($self, $key) {
  return $self->_def_for($key) ? 1 : 0;
}

# ---------------------------------------------------------------------------
# Leitura de um item (folhas) — exposto pela API
# ---------------------------------------------------------------------------

# Detalhe de uma folha: metadados + estado do valor. Segredos são mascarados
# (apenas `set`), nunca expostos.
sub config_item ($self, $key) {
  my $def = $self->_def_for($key) or return;
  my $row = $self->_config_row($key);

  my %item = (
    key        => $key,
    label      => $def->{label},
    description => $def->{description},
    example    => $def->{example},
    type       => $def->{type},
    sensitive  => $def->{sensitive} ? 1 : 0,
    enabled    => $def->{enabled}   ? 1 : 0,
  );
  $item{options} = $def->{options} if $def->{options} && @{ $def->{options} };

  if ($def->{sensitive}) {
    $item{value} = { set => ($row && $row->{secret} ne '') ? 1 : 0 };
  }
  else {
    $item{value} = $row && defined $row->{value} ? decode_json($row->{value}) : undef;
  }
  $item{updated_by} = $row->{updated_by} if $row && defined $row->{updated_by};
  $item{updated_at} = $row->{updated_at} if $row && defined $row->{updated_at};
  return \%item;
}

sub _config_row ($self, $key) {
  return $self->_row(
    'SELECT value, ENCODE(secret, \'hex\') AS secret, updated_by, updated_at
       FROM app_config.items WHERE key = ?',
    $key,
  );
}

# ---------------------------------------------------------------------------
# Gravação
# ---------------------------------------------------------------------------

# Valida um valor contra a definição da folha (sem gravar).
sub config_validate ($self, $key, $value) {
  my $def = $self->_def_for($key) or return { error => 'Chave de configuração desconhecida.' };

  if ($def->{type} eq 'boolean') {
    return { error => 'O valor deve ser "true" ou "false".' }
      unless $value eq 'true' || $value eq 'false' || $value == 0 || $value == 1;
    return { ok => 1, value => ($value eq 'true' || $value == 1) ? 1 : 0 };
  }
  if ($def->{type} eq 'number') {
    return { error => 'O valor deve ser um número inteiro.' }
      unless defined $value && $value =~ /^\d+$/;
    return { ok => 1, value => $value + 0 };
  }
  if ($def->{type} eq 'select') {
    my $ok = grep { $_ eq $value } @{ $def->{options} // [] };
    return { error => 'Opção inválida para este item.' } unless $ok;
    return { ok => 1, value => $value };
  }
  if ($def->{type} eq 'secret') {
    $value //= '';
    $value =~ s/^\s+|\s+$//g;
    return { error => 'A chave não pode ser vazia.' } unless length $value >= 8;
    return { error => 'A chave excede 2048 caracteres.' } if length $value > 2048;
    return { ok => 1, value => $value };
  }
  # text
  $value //= '';
  $value =~ s/^\s+|\s+$//g;
  return { error => 'O valor não pode ser vazio.' } unless length $value >= 1;
  return { error => 'O valor excede 500 caracteres.' } if length $value > 500;
  return { ok => 1, value => $value };
}

# Grava/atualiza um item. `updated_by` é a identificação do admin logado.
sub config_put ($self, $key, $value, $updated_by = undef) {
  my $def = $self->_def_for($key) or croak 'Chave de configuração desconhecida';
  my $v = $self->config_validate($key, $value);
  croak $v->{error} if $v->{error};

  if ($def->{sensitive}) {
    my $master_key = $ENV{EDUMAPS_CONFIG_MASTER_KEY};
    croak 'EDUMAPS_CONFIG_MASTER_KEY não definida — não é possível cifrar segredos.'
      unless $master_key && length $master_key;
    my $cipher = $self->_encrypt_secret($v->{value}, $master_key);
    return $self->_upsert_secret($key, $cipher, $updated_by);
  }

  my $json = encode_json($v->{value});
  return $self->_upsert_value($key, $json, $updated_by);
}

sub _encrypt_secret ($self, $plain, $master_key) {
  # Ciphertrai em hex (ENCODE) no wire: DBD::Pg re-encoda bytea com flag
  # UTF-8 e corrompe bytes altos. Hex é ascii puro — roundtrip seguro.
  return $self->_row(
    'SELECT ENCODE(pgp_sym_encrypt(?, ?), \'hex\') AS secret',
    $plain, $master_key,
  )->{secret};
}

sub _decrypt_secret ($self, $cipher, $master_key) {
  return $self->_row(
    'SELECT pgp_sym_decrypt(DECODE(?, \'hex\'), ?) AS plain',
    $cipher, $master_key,
  )->{plain};
}

sub _upsert_secret ($self, $key, $cipher_hex, $updated_by) {
  $self->_rows(
    'INSERT INTO app_config.items (key, secret, sensitive, secret_key_version, updated_by, updated_at)
     VALUES (?, DECODE(?, \'hex\'), TRUE, 1, ?, NOW())
     ON CONFLICT (key) DO UPDATE SET
       secret             = EXCLUDED.secret,
       sensitive          = TRUE,
       secret_key_version = EXCLUDED.secret_key_version,
       updated_by         = EXCLUDED.updated_by,
       updated_at         = NOW()',
    $key, $cipher_hex, $updated_by,
  );
  return 1;
}

sub _upsert_value ($self, $key, $json, $updated_by) {
  $self->_rows(
    'INSERT INTO app_config.items (key, value, sensitive, updated_by, updated_at)
     VALUES (?::text, ?::jsonb, FALSE, ?, NOW())
     ON CONFLICT (key) DO UPDATE SET
       value      = EXCLUDED.value,
       sensitive  = FALSE,
       secret     = NULL,
       updated_by = EXCLUDED.updated_by,
       updated_at = NOW()',
    $key, $json, $updated_by,
  );
  return 1;
}

# ---------------------------------------------------------------------------
# Consumo interno (job do Assistente do Censo)
# ---------------------------------------------------------------------------

# Monta a config efetiva do Assistente do Censo para o R: campos marcados na
# AppConfig sobrepõem os defaults (que continuam vindo de env destes). Campos
# não definidos na AppConfig ficam undef — o R usa o próprio default.
sub chat_llm_config ($self) {
  my %cfg;
  for my $sub (qw/api_key provider model url/) {
    my $key = "integrations.assistant_censo.$sub";
    my $row = $self->_config_row($key);
    my $value;
    if ($row) {
      if ($key eq 'integrations.assistant_censo.api_key') {
        next unless $row->{secret} ne '';
        my $master_key = $ENV{EDUMAPS_CONFIG_MASTER_KEY};
        next unless $master_key && length $master_key;
        $value = eval { $self->_decrypt_secret($row->{secret}, $master_key) };
        next unless defined $value;
      }
      else {
        next unless defined $row->{value};
        $value = decode_json($row->{value});
      }
    }
    $cfg{$sub} = $value if defined $value;
  }
  return \%cfg;
}

# ---------------------------------------------------------------------------
# Helpers SQL (padrão das roles de negócio)
# ---------------------------------------------------------------------------

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