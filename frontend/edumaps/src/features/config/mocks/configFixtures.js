// src/features/config/mocks/configFixtures.js
import { CONSENTIMENTO_VIGENTE } from "@/features/gestor/mocks/canaisFixtures.js";
// Fixtures do Painel de Configuração (espelham EduMaps::Roles::Business::Config::AppConfig).

export const CONFIG_TREE = {
  categories: [
    {
      key: "sistema",
      label: "Sistema",
      children: [
        {
          key: "system.installation_name",
          label: "Nome da instalação",
          description: "Nome exibido no cabeçalho e nos e-mails da plataforma.",
          example: "Rede Municipal de Ubatuba",
          type: "text",
          sensitive: 0,
          enabled: 0,
          value: null,
        },
        {
          key: "system.timezone",
          label: "Fuso horário",
          description: "Fuso usado para datas e horários exibidos aos gestores.",
          example: "America/Sao_Paulo",
          type: "text",
          sensitive: 0,
          enabled: 0,
          value: null,
        },
      ],
    },
    {
      key: "integracoes",
      label: "Integrações",
      children: [
        {
          key: "assistant_censo",
          label: "Assistente do Censo",
          children: [
            {
              key: "integrations.assistant_censo.api_key",
              label: "Chaves",
              description:
                "Chave de API do provedor de linguagem (LLM) usado pelo Assistente do Censo. É a senha da conta que responde às perguntas dos gestores.",
              example: "chave secreta fornecida pelo provedor (ex.: gsk_..., AIza... ou sk-...)",
              type: "secret",
              sensitive: 1,
              enabled: 1,
              value: { set: 0 },
            },
            {
              key: "integrations.assistant_censo.provider",
              label: "Provedor",
              description: "Provedor de linguagem (ollama, gemini, openai ou groq).",
              example: "gemini",
              type: "select",
              options: ["ollama", "gemini", "openai", "groq"],
              sensitive: 0,
              enabled: 0,
              value: null,
            },
            {
              key: "integrations.assistant_censo.model",
              label: "Modelo",
              description: "Identificador do modelo de linguagem junto ao provedor.",
              example: "gemini-flash-lite-latest",
              type: "text",
              sensitive: 0,
              enabled: 0,
              value: null,
            },
            {
              key: "integrations.assistant_censo.url",
              label: "URL da API",
              description: "Base URL da API do provedor (opcional; o padrão do provedor é usado se vazio).",
              example: "https://api.openai.com/v1",
              type: "text",
              sensitive: 0,
              enabled: 0,
              value: null,
            },
          ],
        },
        {
          key: "bot_telegram",
          label: "Bot Telegram",
          children: [
            {
              key: "integrations.bot_telegram.token",
              label: "Token do bot",
              description:
                "Token do bot no Telegram (fornecido pelo @BotFather). Guardado cifrado — nunca exibido em claro.",
              example: "123456789:ABCdefGHI...",
              type: "secret",
              sensitive: 1,
              enabled: 1,
              value: { set: 0 },
            },
            {
              key: "integrations.bot_telegram.chat_id",
              label: "Chat de destino",
              description: "Identificador do chat onde o bot envia alertas (grupo ou usuário admin).",
              example: "-1001234567890",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "integrations.bot_telegram.enabled",
              label: "Bot ativado",
              description: "Liga/desliga o envio de mensagens pelo bot. Desligado, nenhum alerta é entregue.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 0,
            },
            {
              key: "integrations.bot_telegram.allowed_actions",
              label: "Ações permitidas",
              description:
                "Lista de ações autorizadas a disparar mensagem no chat. Apenas as marcadas são enviadas.",
              type: "multiselect",
              options: [
                "system_alert",
                "system_info",
                "ingest_stall",
                "ingest_done",
                "ingest_failed",
                "user_notification",
                "admin_notification",
              ],
              sensitive: 0,
              enabled: 1,
              value: [],
            },
          ],
        },
      ],
    },
    {
      key: "canais",
      label: "Canais de comunicação",
      children: [
        {
          key: "canais_email",
          label: "E-mail (SMTP)",
          children: [
            {
              key: "canais.email.smtp_host",
              label: "Servidor SMTP",
              description: "Host do servidor de envio de e-mail.",
              example: "smtp.exemplo.org",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.email.smtp_port",
              label: "Porta SMTP",
              description:
                "Porta do servidor SMTP. 587 costuma usar TLS (STARTTLS); 465 usa TLS implícito.",
              example: "587",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.email.smtp_user",
              label: "Usuário SMTP",
              description: "Usuário de autenticação no servidor SMTP (se exigido).",
              example: "nao-responda@exemplo.org",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.email.smtp_password",
              label: "Senha SMTP",
              description:
                "Senha de autenticação no servidor SMTP. Guardada cifrada — nunca exibida em claro.",
              example: "••••••••",
              type: "secret",
              sensitive: 1,
              enabled: 1,
              value: { set: 0 },
            },
            {
              key: "canais.email.smtp_tls",
              label: "Usar TLS",
              description: "Cifra a conexão SMTP (STARTTLS na porta 587, TLS implícito na 465).",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 0,
            },
            {
              key: "canais.email.from",
              label: "E-mail do remetente",
              description: "Endereço que aparece como remetente das mensagens.",
              example: "nao-responda@exemplo.org",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.email.from_name",
              label: "Nome do remetente",
              description: "Nome exibido junto ao endereço do remetente.",
              example: "Rede Municipal de Ensino",
              type: "text",
              sensitive: 0,
              enabled: 0,
              value: null,
            },
            {
              key: "canais.email.enabled",
              label: "Canal e-mail ativado",
              description: "Liga/desliga o envio de e-mail. Desligado, nenhuma mensagem é entregue.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 0,
            },
          ],
        },
        {
          key: "canais_whatsapp",
          label: "WhatsApp",
          children: [
            {
              key: "canais.whatsapp.provider",
              label: "Provedor",
              description:
                "link = apenas gera link wa.me (sem envio real); cloud = envio real pela WhatsApp Cloud API.",
              example: "link",
              type: "select",
              options: ["link", "cloud"],
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.whatsapp.token",
              label: "Token de acesso",
              description:
                "Token permanente da WhatsApp Cloud API. Guardado cifrado — nunca exibido em claro.",
              example: "EAAG...",
              type: "secret",
              sensitive: 1,
              enabled: 1,
              value: { set: 0 },
            },
            {
              key: "canais.whatsapp.phone_number_id",
              label: "ID do número",
              description: "Identificador do número no WhatsApp Cloud API (phone_number_id).",
              example: "123456789012345",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.whatsapp.enabled",
              label: "Canal WhatsApp ativado",
              description: "Liga/desliga o envio pelo WhatsApp. Desligado, nenhuma mensagem é entregue.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 0,
            },
            {
              key: "canais.whatsapp.template_confirmacao",
              label: "Template de confirmação",
              description:
                "Nome do template de autenticação (aprovado na Meta) usado para enviar o código de confirmação do telefone nas listas com QR. Sem template, o WhatsApp não é oferecido como canal de confirmação.",
              example: "edumaps_codigo_confirmacao",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.whatsapp.template_idioma",
              label: "Idioma do template",
              description: "Código de idioma do template de confirmação, como cadastrado na Meta.",
              example: "pt_BR",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
          ],
        },
        {
          key: "canais_telegram",
          label: "Telegram (bot público)",
          children: [
            {
              key: "canais.telegram.token",
              label: "Token do bot público",
              description:
                "Token do bot público do Telegram (fornecido pelo @BotFather), usado para confirmar o telefone dos inscritos nas listas com QR. É um bot DIFERENTE do bot de notificações internas. Guardado cifrado — nunca exibido em claro.",
              example: "123456789:ABCdefGHI...",
              type: "secret",
              sensitive: 1,
              enabled: 1,
              value: { set: 0 },
            },
            {
              key: "canais.telegram.bot_username",
              label: "Usuário do bot",
              description:
                "Nome de usuário do bot público (sem @), usado no link https://t.me/<usuário>?start=<ref>.",
              example: "EduMapsConfirmaBot",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.telegram.recebimento",
              label: "Modo de recebimento",
              description:
                "polling = um worker consulta o Telegram (getUpdates; bom para desenvolvimento); webhook = o Telegram chama o EduMaps por HTTPS público.",
              example: "polling",
              type: "select",
              options: ["polling", "webhook"],
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.telegram.webhook_secret",
              label: "Segredo do webhook",
              description:
                "Valor esperado no header X-Telegram-Bot-Api-Secret-Token (modo webhook). Guardado cifrado — nunca exibido em claro.",
              example: "um-segredo-longo-e-aleatorio",
              type: "secret",
              sensitive: 1,
              enabled: 1,
              value: { set: 0 },
            },
            {
              key: "canais.telegram.enabled",
              label: "Bot público ativado",
              description:
                "Liga/desliga a confirmação pelo Telegram. Desligado, o Telegram não é oferecido como canal de confirmação.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 0,
            },
          ],
        },
        {
          key: "canais_inscricao",
          label: "Autoinscrição por QR",
          children: [
            {
              key: "canais.inscricao.enabled",
              label: "Autoinscrição ativada",
              description:
                "Liga/desliga o endpoint público de autoinscrição (listas com QR). Desligado, o GET/POST público responde 404.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 0,
            },
            {
              key: "canais.inscricao.public_base_url",
              label: "URL pública base",
              description:
                "Base URL pública usada para montar o link de inscrição do QR (ex.: https://edumaps.exemplo.org).",
              example: "https://edumaps.exemplo.org",
              type: "text",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.inscricao.rate_max",
              label: "Limite de submissões (janela)",
              description:
                "Número máximo de submissões públicas por token+IP dentro da janela (antiabuso).",
              example: "10",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
            {
              key: "canais.inscricao.rate_window_seconds",
              label: "Janela do limite (segundos)",
              description: "Tamanho da janela do limite de submissões públicas (antiabuso).",
              example: "60",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: null,
            },
          ],
        },
        {
          // issue #216 (Fase 3): envio por e-mail para listas
          key: "canais_envio",
          label: "Envios",
          children: [
            {
              key: "canais.envio.enabled",
              label: "Envios por e-mail ativados",
              description:
                "Liga/desliga o envio de e-mails para listas. Desligado, o disparo responde 409 e os envios em andamento ficam parados.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 1,
            },
            {
              key: "canais.envio.ritmo_por_minuto",
              label: "Ritmo (e-mails por minuto)",
              description: "Quantos e-mails cada envio despacha por minuto (1 a 600).",
              example: "60",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: 60,
            },
            {
              key: "canais.envio.cota_diaria_escola",
              label: "Cota diária por escola",
              description:
                "Máximo de e-mails que uma escola envia por dia. Ao esgotar, o envio pausa e retoma no dia seguinte.",
              example: "500",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: 500,
            },
            {
              key: "canais.envio.max_destinatarios",
              label: "Máximo de destinatários por envio",
              description: "Teto de destinatários de um único envio.",
              example: "2000",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: 2000,
            },
          ],
        },
        {
          key: "canais_retencao",
          label: "Retenção (LGPD)",
          children: [
            {
              key: "canais.retencao.enabled",
              label: "Retenção ativada",
              description:
                "Liga/desliga a limpeza automática diária dos dados das listas conforme os prazos abaixo.",
              type: "boolean",
              sensitive: 0,
              enabled: 1,
              value: 1,
            },
            {
              key: "canais.retencao.metadados_dias",
              label: "Metadados técnicos (dias)",
              description:
                "Depois deste prazo, o IP anonimizado e o navegador das inscrições são apagados.",
              example: "90",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: 90,
            },
            {
              key: "canais.retencao.pendentes_dias",
              label: "Inscrições nunca confirmadas (dias)",
              description:
                "Em listas que exigem confirmação, inscritos que nunca confirmaram são removidos após este prazo.",
              example: "180",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: 180,
            },
            {
              key: "canais.retencao.listas_inativas_meses",
              label: "Listas desativadas (meses)",
              description:
                "Os inscritos de listas desativadas há mais que este prazo são removidos (se não estiverem em outra lista ativa).",
              example: "12",
              type: "number",
              sensitive: 0,
              enabled: 1,
              value: 12,
            },
          ],
        },
      ],
    },
    {
      key: "aparencia",
      label: "Aparência",
      children: [
        {
          key: "appearance.theme",
          label: "Tema",
          description: "Tema visual padrão da plataforma.",
          example: "claro",
          type: "select",
          options: ["claro", "escuro"],
          sensitive: 0,
          enabled: 0,
          value: null,
        },
      ],
    },
    {
      key: "comportamento",
      label: "Comportamento",
      children: [
        {
          key: "behavior.default_ano",
          label: "Ano padrão dos dados",
          description: "Ano usado por padrão nos painéis e consultas com dados por ano.",
          example: "2025",
          type: "number",
          sensitive: 0,
          enabled: 0,
          value: null,
        },
      ],
    },
    {
      key: "outros",
      label: "Outros",
      children: [],
    },
  ],
};

export const CONFIG_KEY_API = "integrations.assistant_censo.api_key";

export const CONFIG_SAVED_ITEM = {
  key: CONFIG_KEY_API,
  label: "Chaves",
  description: CONFIG_TREE.categories[1].children[0].children[0].description,
  example: CONFIG_TREE.categories[1].children[0].children[0].example,
  type: "secret",
  sensitive: 1,
  enabled: 1,
  value: { set: 1 },
  updated_by: "marina@edu.gov.br",
  updated_at: "2026-09-25T12:00:00",
};
// Status do bot público do Telegram (GET /api/admin/canais/telegram/status).
export const TELEGRAM_STATUS_POLLING = {
  enabled: 1,
  recebimento: "polling",
  bot_username: "EduMapsConfirmaBot",
  polling: { ativo: 0, offset: 0 },
};

export const TELEGRAM_STATUS_WEBHOOK = {
  enabled: 1,
  recebimento: "webhook",
  bot_username: "EduMapsConfirmaBot",
  webhook: { url: "", pending_update_count: 0, last_error_message: null },
  polling: { ativo: 0, offset: 0 },
};

export const TELEGRAM_WEBHOOK_URL = "https://edumaps.exemplo.org/api/canais/telegram/webhook";

// Status da retenção (GET /api/admin/canais/retencao, issue #214).
export const RETENCAO_STATUS = {
  enabled: 1,
  metadados_dias: 90,
  pendentes_dias: 180,
  listas_inativas_meses: 12,
  ultima_execucao: {
    em: "2026-10-11T03:00:00",
    metadados: 4,
    pendentes: 2,
    listas_inativas: 0,
  },
  agendado: 1,
};

export const RETENCAO_JOB_ID = 5151;

// Versões do texto de consentimento (GET /api/admin/consentimento/versoes).
export const CONSENTIMENTO_VERSOES = [
  {
    id: 1,
    versao: "1.0",
    texto: CONSENTIMENTO_VIGENTE.texto,
    texto_hash: "3f1c0a1e9b2d4c5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6",
    status: "vigente",
    publicada_em: "2026-10-12T00:00:00Z",
    created_at: "2026-10-12T00:00:00Z",
  },
  {
    id: 2,
    versao: "1.1",
    texto:
      "Ao se inscrever, você autoriza a **escola** a guardar seu nome, telefone e e-mail.\n\n" +
      "Usamos esses dados para:\n\n- avisos da escola;\n- convites para reuniões.",
    texto_hash: "9a8b7c6d5e4f30211203f4e5d6c7b8a99a8b7c6d5e4f30211203f4e5d6c7b8a9",
    status: "rascunho",
    publicada_em: null,
    created_at: "2026-10-12T10:00:00Z",
  },
];

// Painel admin de envios (GET /api/admin/canais/envios, issue #216, onda 2).
// Ordenadas por enviados_30d desc; a última só aparece por estar suspensa.
export const ENVIOS_ADMIN = {
  limites: {
    enabled: 1,
    ritmo_por_minuto: 60,
    cota_diaria: 500,
    max_destinatarios: 2000,
    smtp_disponivel: 1,
  },
  escolas: [
    {
      cod_inep: 11000040,
      escola_nome: "Escola Estadual Professora Maria de Lourdes",
      enviados_hoje: 12,
      enviados_30d: 340,
      falhas_30d: 4,
      optouts_30d: 2,
      envios_em_curso: 2,
      suspensao: null,
    },
    {
      cod_inep: 35038751,
      escola_nome: "EMEF Jardim das Flores",
      enviados_hoje: 0,
      enviados_30d: 120,
      falhas_30d: 31,
      optouts_30d: 9,
      envios_em_curso: 1,
      suspensao: {
        id: 7,
        motivo: "Muitas falhas de entrega",
        suspenso_em: "2026-10-11T18:00:00Z",
        suspenso_por: 1,
      },
    },
  ],
};
