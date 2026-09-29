// src/shared/sentry.js
//
// Integração Sentry (sentry.io cloud) de forma opcional: sem DSN tudo é
// no-op silencioso. O SDK é carregado por import dinâmico apenas quando há
// DSN configurado — assim o bundle (e os testes com MSW) não sofrem impacto
// em ambientes sem observabilidade.
//
// Cobertura:
//   - window.onerror / unhandledrejection: integrações padrão do SDK (init).
//   - Erros de componentes Svelte 5: main.js passa `onerror` no mount.
//   - ApiError >= 500: o cliente HTTP emite EVENTS.API_ERROR no eventBus e
//     este módulo captura (desacoplado do SDK).
//
// Privacidade (LGPD): sendDefaultPii desativado e beforeSend redige chaves
// sensíveis (token, CPF, salário...) em qualquer profundidade do evento.

import { eventBus, EVENTS } from "@/shared/events";

const SENSITIVE_KEYS = new Set([
  "authorization",
  "cookie",
  "password",
  "senha",
  "token",
  "access_token",
  "refresh_token",
  "cpf",
  "cnpj",
  "salario",
  "salary",
  "remuneracao",
  "matricula",
]);

let sentry = null; // módulo @sentry/svelte inicializado (null = desativado)

/** Redige chaves sensíveis em qualquer profundidade. */
export function scrub(value, key = "") {
  if (SENSITIVE_KEYS.has(key.toLowerCase())) {
    return typeof value === "string" ? "[redigido]" : undefined;
  }
  if (Array.isArray(value)) return value.map((v) => scrub(v));
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, scrub(v, k)]),
    );
  }
  return value;
}

/** Resolve configuração: overrides > env (VITE_*) > defaults. */
export function resolveConfig(overrides = {}) {
  return {
    dsn: overrides.dsn ?? import.meta.env.VITE_SENTRY_DSN ?? "",
    release: overrides.release ?? import.meta.env.VITE_SENTRY_RELEASE ?? undefined,
    environment:
      overrides.environment ?? import.meta.env.VITE_SENTRY_ENVIRONMENT ?? "development",
  };
}

function subscribeToApiErrors(Sentry) {
  eventBus.on(EVENTS.API_ERROR, (payload = {}) => {
    const err =
      payload.error instanceof Error
        ? payload.error
        : new Error(payload.message ?? "Erro de API");
    Sentry.captureException(err, {
      tags: { kind: "http", http_status: String(payload.status ?? "") },
      contexts: {
        http: { url: payload.url, status_code: payload.status },
      },
    });
  });
}

/**
 * Inicializa o Sentry (idempotente). Retorna o módulo @sentry/svelte quando
 * ativo, ou null quando sem DSN/configuração incompleta.
 */
export async function initSentry(overrides = {}) {
  if (sentry) return sentry;
  const { dsn, release, environment } = resolveConfig(overrides);
  if (!dsn) {
    // Sem DSN (dev/local sem conta sentry.io) → no-op silencioso.
    return null;
  }

  const Sentry = await import("@sentry/svelte");
  Sentry.init({
    dsn,
    environment,
    release,
    sendDefaultPii: false,
    tracesSampleRate: 0, // telemetria/traces ficam p/ fase 2 (fora de escopo)
    beforeSend: (event) => scrub(event),
  });
  Sentry.setTag?.("app", "frontend");

  // registra a ponte api:error → Sentry
  subscribeToApiErrors(Sentry);

  sentry = Sentry;
  return Sentry;
}

/** Acesso ao SDK inicializado (null quando desativado) — p/ main.js e afins. */
export function getSentry() {
  return sentry;
}