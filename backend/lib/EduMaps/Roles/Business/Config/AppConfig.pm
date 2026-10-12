package EduMaps::Roles::Business::Config::AppConfig;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(decode_json encode_json);
use Carp qw(croak);
use EduMaps::Bots::Policy::Actions;

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
      {
        key      => 'bot_telegram',
        label    => 'Bot Telegram',
        children => [
          {
            key         => 'integrations.bot_telegram.token',
            label       => 'Token do bot',
            description => 'Token do bot no Telegram (fornecido pelo @BotFather). Guardado cifrado — nunca exibido em claro.',
            example     => '123456789:ABCdefGHI...',
            type        => 'secret',
            sensitive   => 1,
            enabled     => 1,
          },
          {
            key         => 'integrations.bot_telegram.chat_id',
            label       => 'Chat de destino',
            description => 'Identificador do chat onde o bot envia alertas (grupo ou usuário admin).',
            example     => '-1001234567890',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'integrations.bot_telegram.enabled',
            label       => 'Bot ativado',
            description => 'Liga/desliga o envio de mensagens pelo bot. Desligado, nenhum alerta é entregue.',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'integrations.bot_telegram.allowed_actions',
            label       => 'Ações permitidas',
            description => 'Lista de ações autorizadas a disparar mensagem no chat. Apenas as marcadas são enviadas.',
            type        => 'multiselect',
            options     => EduMaps::Bots::Policy::Actions->available,
            sensitive   => 0,
            enabled     => 1,
          },
        ],
      },
    ],
  },
  canais => {
    label    => 'Canais de comunicação',
    children => [
      {
        key      => 'canais_email',
        label    => 'E-mail (SMTP)',
        children => [
          {
            key         => 'canais.email.smtp_host',
            label       => 'Servidor SMTP',
            description => 'Host do servidor de envio de e-mail.',
            example     => 'smtp.exemplo.org',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.email.smtp_port',
            label       => 'Porta SMTP',
            description => 'Porta do servidor SMTP. 587 costuma usar TLS (STARTTLS); 465 usa TLS implícito.',
            example     => '587',
            type        => 'number',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.email.smtp_user',
            label       => 'Usuário SMTP',
            description => 'Usuário de autenticação no servidor SMTP (se exigido).',
            example     => 'nao-responda@exemplo.org',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.email.smtp_password',
            label       => 'Senha SMTP',
            description => 'Senha de autenticação no servidor SMTP. Guardada cifrada — nunca exibida em claro.',
            example     => '••••••••',
            type        => 'secret',
            sensitive   => 1,
            enabled     => 1,
          },
          {
            key         => 'canais.email.smtp_tls',
            label       => 'Usar TLS',
            description => 'Cifra a conexão SMTP (STARTTLS na porta 587, TLS implícito na 465).',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.email.from',
            label       => 'E-mail do remetente',
            description => 'Endereço que aparece como remetente das mensagens.',
            example     => 'nao-responda@exemplo.org',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.email.from_name',
            label       => 'Nome do remetente',
            description => 'Nome exibido junto ao endereço do remetente.',
            example     => 'Rede Municipal de Ensino',
            type        => 'text',
            sensitive   => 0,
            enabled     => 0,
          },
          {
            key         => 'canais.email.enabled',
            label       => 'Canal e-mail ativado',
            description => 'Liga/desliga o envio de e-mail. Desligado, nenhuma mensagem é entregue.',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
        ],
      },
      {
        key      => 'canais_whatsapp',
        label    => 'WhatsApp',
        children => [
          {
            key         => 'canais.whatsapp.provider',
            label       => 'Provedor',
            description => 'link = apenas gera link wa.me (sem envio real); cloud = envio real pela WhatsApp Cloud API.',
            example     => 'link',
            type        => 'select',
            options     => [qw(link cloud)],
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.whatsapp.token',
            label       => 'Token de acesso',
            description => 'Token permanente da WhatsApp Cloud API. Guardado cifrado — nunca exibido em claro.',
            example     => 'EAAG...',
            type        => 'secret',
            sensitive   => 1,
            enabled     => 1,
          },
          {
            key         => 'canais.whatsapp.phone_number_id',
            label       => 'ID do número',
            description => 'Identificador do número no WhatsApp Cloud API (phone_number_id).',
            example     => '123456789012345',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.whatsapp.enabled',
            label       => 'Canal WhatsApp ativado',
            description => 'Liga/desliga o envio pelo WhatsApp. Desligado, nenhuma mensagem é entregue.',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.whatsapp.template_confirmacao',
            label       => 'Template de confirmação',
            description => 'Nome do template de autenticação (aprovado na Meta) usado para enviar o código de confirmação do telefone nas listas com QR. Sem template, o WhatsApp não é oferecido como canal de confirmação.',
            example     => 'edumaps_codigo_confirmacao',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.whatsapp.template_idioma',
            label       => 'Idioma do template',
            description => 'Código de idioma do template de confirmação, como cadastrado na Meta.',
            example     => 'pt_BR',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
        ],
      },
      {
        key      => 'canais_telegram',
        label    => 'Telegram (bot público)',
        children => [
          {
            key         => 'canais.telegram.token',
            label       => 'Token do bot público',
            description => 'Token do bot público do Telegram (fornecido pelo @BotFather), usado para confirmar o telefone dos inscritos nas listas com QR. É um bot DIFERENTE do bot de notificações internas. Guardado cifrado — nunca exibido em claro.',
            example     => '123456789:ABCdefGHI...',
            type        => 'secret',
            sensitive   => 1,
            enabled     => 1,
          },
          {
            key         => 'canais.telegram.bot_username',
            label       => 'Usuário do bot',
            description => 'Nome de usuário do bot público (sem @), usado no link https://t.me/<usuário>?start=<ref>.',
            example     => 'EduMapsConfirmaBot',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.telegram.recebimento',
            label       => 'Modo de recebimento',
            description => 'polling = um worker consulta o Telegram (getUpdates; bom para desenvolvimento); webhook = o Telegram chama o EduMaps por HTTPS público.',
            example     => 'polling',
            type        => 'select',
            options     => [qw(polling webhook)],
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.telegram.webhook_secret',
            label       => 'Segredo do webhook',
            description => 'Valor esperado no header X-Telegram-Bot-Api-Secret-Token (modo webhook). Guardado cifrado — nunca exibido em claro.',
            example     => 'um-segredo-longo-e-aleatorio',
            type        => 'secret',
            sensitive   => 1,
            enabled     => 1,
          },
          {
            key         => 'canais.telegram.enabled',
            label       => 'Bot público ativado',
            description => 'Liga/desliga a confirmação pelo Telegram. Desligado, o Telegram não é oferecido como canal de confirmação.',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
        ],
      },
      {
        key      => 'canais_inscricao',
        label    => 'Autoinscrição por QR',
        children => [
          {
            key         => 'canais.inscricao.enabled',
            label       => 'Autoinscrição ativada',
            description => 'Liga/desliga o endpoint público de autoinscrição (listas com QR). Desligado, o GET/POST público responde 404.',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.inscricao.public_base_url',
            label       => 'URL pública base',
            description => 'Base URL pública usada para montar o link de inscrição do QR (ex.: https://edumaps.exemplo.org).',
            example     => 'https://edumaps.exemplo.org',
            type        => 'text',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.inscricao.rate_max',
            label       => 'Limite de submissões (janela)',
            description => 'Número máximo de submissões públicas por token+IP dentro da janela (antiabuso).',
            example     => '10',
            type        => 'number',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.inscricao.rate_window_seconds',
            label       => 'Janela do limite (segundos)',
            description => 'Tamanho da janela do limite de submissões públicas (antiabuso).',
            example     => '60',
            type        => 'number',
            sensitive   => 0,
            enabled     => 1,
          },
        ],
      },
      {
        # Retenção dos dados das listas com QR (#214, RF-207). Lidas pela
        # task diária `canais_retencao` (retencao_config).
        key      => 'canais_retencao',
        label    => 'Retenção (LGPD)',
        children => [
          {
            key         => 'canais.retencao.enabled',
            label       => 'Expurgo automático ativado',
            description => 'Liga/desliga a rotina diária de retenção (apaga metadados antigos e anonimiza pendentes e membros de listas inativas). Padrão: ligado.',
            type        => 'boolean',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.retencao.metadados_dias',
            label       => 'Metadados da inscrição (dias)',
            description => 'Após este prazo, o IP anonimizado e o navegador (user agent) das inscrições são apagados. Padrão: 90.',
            example     => '90',
            type        => 'number',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.retencao.pendentes_dias',
            label       => 'Inscritos nunca confirmados (dias)',
            description => 'Em listas que exigem confirmação, inscritos que nunca confirmaram nenhum contato são anonimizados após este prazo. Padrão: 180.',
            example     => '180',
            type        => 'number',
            sensitive   => 0,
            enabled     => 1,
          },
          {
            key         => 'canais.retencao.listas_inativas_meses',
            label       => 'Listas desativadas (meses)',
            description => 'Membros de listas desativadas há mais que este prazo são anonimizados (exceto quem está em outra lista ativa da escola). Padrão: 12.',
            example     => '12',
            type        => 'number',
            sensitive   => 0,
            enabled     => 1,
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
  for my $cat (qw/sistema integracoes canais aparencia comportamento outros/) {
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
    return { ok => 1, value => ($value eq 'true' || $value eq '1') ? 1 : 0 };
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
  if ($def->{type} eq 'multiselect') {
    return { error => 'O valor deve ser uma lista de ações.' }
      unless ref $value eq 'ARRAY';
    return { error => 'A lista de ações não pode ser vazia.' }
      unless @$value;
    my %allowed = map { $_ => 1 } @{ $def->{options} // [] };
    my %seen;
    for my $action (@$value) {
      return { error => 'Ação desconhecida na lista.' }
        unless defined $action && !ref $action && $allowed{$action};
      return { error => 'Ação duplicada na lista.' } if $seen{$action}++;
    }
    return { ok => 1, value => [@$value] };
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

# Monta a config efetiva do Bot Telegram para o EduMaps::Bots::Telegram.
# Campos ausentes ficam undef; `enabled` é 0 por omissão (nada é enviado sem
# decisão explícita do admin). O token sai decifrado aqui — nunca é exposto
# por API (a folha sensitive devolve só { set: 0|1 }).
sub bot_telegram_config ($self) {
  my %cfg = (enabled => 0);
  for my $sub (qw/token chat_id enabled allowed_actions/) {
    my $key = "integrations.bot_telegram.$sub";
    my $row = $self->_config_row($key) or next;
    if ($sub eq 'token') {
      next unless $row->{secret} && $row->{secret} ne '';
      my $master_key = $ENV{EDUMAPS_CONFIG_MASTER_KEY};
      next unless $master_key && length $master_key;
      my $plain = eval { $self->_decrypt_secret($row->{secret}, $master_key) };
      next unless defined $plain;
      $cfg{token} = $plain;
    }
    else {
      next unless defined $row->{value};
      $cfg{$sub} = decode_json($row->{value});
    }
  }
  return \%cfg;
}

# ---------------------------------------------------------------------------
# Consumo interno: canais de comunicação
# ---------------------------------------------------------------------------

# Lê um grupo de folhas `canais.<canal>.<sub>` e devolve um hashref pronto para
# o construtor do canal. Segredos saem decifrados; folhas ausentes ficam de
# fora (o canal aplica os próprios defaults).
sub _canais_group_config ($self, $prefix, $subs, $secret_subs) {
  my %secret = map { $_ => 1 } @$secret_subs;
  my %cfg;
  for my $sub (@$subs) {
    my $row = $self->_config_row("$prefix.$sub") or next;
    if ($secret{$sub}) {
      next unless $row->{secret} && $row->{secret} ne '';
      my $master_key = $ENV{EDUMAPS_CONFIG_MASTER_KEY};
      next unless $master_key && length $master_key;
      my $plain = eval { $self->_decrypt_secret($row->{secret}, $master_key) };
      next unless defined $plain;
      $cfg{$sub} = $plain;
    }
    else {
      next unless defined $row->{value};
      $cfg{$sub} = decode_json($row->{value});
    }
  }
  return \%cfg;
}

# Config efetiva do canal de e-mail (canais.email.*). `enabled` é 0 por omissão
# — nada é enviado sem decisão explícita do admin.
sub email_config ($self) {
  my $cfg = $self->_canais_group_config(
    'canais.email',
    [qw/smtp_host smtp_port smtp_user smtp_password smtp_tls from from_name enabled/],
    [qw/smtp_password/],
  );
  $cfg->{enabled} = 0 unless defined $cfg->{enabled};
  return $cfg;
}

# Config efetiva do canal WhatsApp (canais.whatsapp.*). `provider` é 'link' por
# omissão (sem envio real); `enabled` é 0 por omissão.
sub whatsapp_config ($self) {
  my $cfg = $self->_canais_group_config(
    'canais.whatsapp',
    [qw/provider token phone_number_id enabled template_confirmacao template_idioma/],
    [qw/token/],
  );
  $cfg->{provider}        = 'link' unless defined $cfg->{provider};
  $cfg->{enabled}         = 0 unless defined $cfg->{enabled};
  $cfg->{template_idioma} = 'pt_BR' unless defined $cfg->{template_idioma};
  return $cfg;
}

# Config efetiva do canal Telegram — reaproveita a config do bot já existente.
sub telegram_config ($self) {
  my $b = $self->bot_telegram_config;
  return {
    token   => $b->{token},
    chat_id => $b->{chat_id},
    enabled => $b->{enabled} // 0,
  };
}

# Config efetiva do bot PÚBLICO do Telegram (canais.telegram.*), usado na
# confirmação de posse do telefone nas listas com QR (#212). Independente do
# bot de notificações internas (integrations.bot_telegram, ver telegram_config).
# `recebimento` é 'polling' por omissão; `enabled` é 0 por omissão.
# `bot_username` sai sem o '@' inicial (pronto para o link t.me).
sub telegram_publico_config ($self) {
  my $cfg = $self->_canais_group_config(
    'canais.telegram',
    [qw/token bot_username recebimento webhook_secret enabled/],
    [qw/token webhook_secret/],
  );
  $cfg->{bot_username} =~ s/^\@+// if defined $cfg->{bot_username};
  $cfg->{recebimento} = 'polling' unless defined $cfg->{recebimento};
  $cfg->{enabled}     = 0 unless defined $cfg->{enabled};
  return $cfg;
}

# Canais disponíveis para a confirmação de posse do telefone (#212), na ordem
# do contrato (telegram, whatsapp). Só entra o canal ligado E configurado:
#
#   telegram: canais.telegram.enabled + token + bot_username;
#   whatsapp: canais.whatsapp.enabled + provider=cloud + token +
#             phone_number_id + template_confirmacao.
#
# Devolve arrayref de { canal => ..., (bot_username => ... no telegram) }.
sub canais_confirmacao_disponiveis ($self) {
  my @out;
  my $tem = sub ($v) { defined $v && length $v };

  my $tg = $self->telegram_publico_config;
  push @out, { canal => 'telegram', bot_username => $tg->{bot_username} }
    if $tg->{enabled} && $tem->($tg->{token}) && $tem->($tg->{bot_username});

  my $wa = $self->whatsapp_config;
  push @out, { canal => 'whatsapp' }
    if $wa->{enabled} && ($wa->{provider} // '') eq 'cloud'
      && $tem->($wa->{token}) && $tem->($wa->{phone_number_id})
      && $tem->($wa->{template_confirmacao});

  return \@out;
}

# Canal e-mail disponível para a confirmação de posse do e-mail nas listas
# (#214, RF-203): canais.email.enabled + smtp_host + from. Devolve 1/0.
sub email_confirmacao_disponivel ($self) {
  my $cfg = $self->email_config;
  my $tem = sub ($v) { defined $v && !ref $v && length $v };
  return ($cfg->{enabled} && $tem->($cfg->{smtp_host}) && $tem->($cfg->{from})) ? 1 : 0;
}

# Config efetiva da autoinscrição por QR (canais.inscricao.*). `enabled` é 0
# por omissão — o endpoint público responde 404 sem decisão explícita do admin.
# `rate_max`/`rate_window_seconds` alimentam o rate limit em memória.
sub inscricao_config ($self) {
  my $cfg = $self->_canais_group_config(
    'canais.inscricao',
    [qw/enabled public_base_url rate_max rate_window_seconds/],
    [],
  );
  $cfg->{enabled}             = 0 unless defined $cfg->{enabled};
  $cfg->{rate_max}            = 10 unless defined $cfg->{rate_max};
  $cfg->{rate_window_seconds} = 60 unless defined $cfg->{rate_window_seconds};
  return $cfg;
}

# Config efetiva da retenção (canais.retencao.*, #214 RF-207). Defaults:
# enabled 1, metadados 90 dias, pendentes 180 dias, listas inativas 12 meses.
# Prazo ausente ou < 1 vale o default (prazo 0 apagaria tudo de uma vez).
sub retencao_config ($self) {
  my $cfg = $self->_canais_group_config(
    'canais.retencao',
    [qw/enabled metadados_dias pendentes_dias listas_inativas_meses/],
    [],
  );
  my %def = (metadados_dias => 90, pendentes_dias => 180, listas_inativas_meses => 12);
  for my $k (keys %def) {
    my $v = $cfg->{$k};
    $cfg->{$k} = (defined $v && !ref $v && $v =~ /^\d+\z/ && $v >= 1) ? $v + 0 : $def{$k};
  }
  $cfg->{enabled} = defined $cfg->{enabled} ? ($cfg->{enabled} ? 1 : 0) : 1;
  return $cfg;
}

# Config pronta para `EduMaps::Channel->build_from_config($name, ...)`.
sub channel_config ($self, $name) {
  return undef unless defined $name;
  return $self->email_config    if $name eq 'email';
  return $self->whatsapp_config if $name eq 'whatsapp';
  return $self->telegram_config if $name eq 'telegram';
  return undef;
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