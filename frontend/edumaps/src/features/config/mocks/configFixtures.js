// src/features/config/mocks/configFixtures.js
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