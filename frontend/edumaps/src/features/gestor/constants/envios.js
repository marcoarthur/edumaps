// src/features/gestor/constants/envios.js
//
// Rótulos e mensagens do envio por e-mail para listas (issue #216, Fase 3).
// Fonte dos valores: contrato congelado da onda 1
// (docs/specs/2026-10-12-envio-email-listas-qr.execucao.md).
import { ApiError } from "@/shared/api/client.js";

/** Operações (motivo do envio), na ordem do seletor. */
export const OPERACOES = [
  { valor: "aviso", rotulo: "Aviso" },
  { valor: "informacao", rotulo: "Informação" },
  { valor: "pedido", rotulo: "Pedido" },
  { valor: "convite", rotulo: "Convite" },
  { valor: "lembrete", rotulo: "Lembrete" },
  { valor: "alerta", rotulo: "Alerta" },
];

export const rotuloOperacao = (valor) =>
  OPERACOES.find((o) => o.valor === valor)?.rotulo ?? valor ?? "—";

/** Estados do envio → selo (texto + classes). */
export const ESTADOS_ENVIO = {
  rascunho: { rotulo: "Rascunho", classe: "bg-gray-100 text-gray-700" },
  agendado: { rotulo: "Agendado", classe: "bg-blue-100 text-blue-700" },
  enviando: { rotulo: "Enviando", classe: "bg-indigo-100 text-indigo-700" },
  pausado_cota: { rotulo: "Pausado (cota do dia)", classe: "bg-amber-100 text-amber-800" },
  suspenso: { rotulo: "Suspenso", classe: "bg-red-100 text-red-700" },
  concluido: { rotulo: "Concluído", classe: "bg-green-100 text-green-700" },
  cancelado: { rotulo: "Cancelado", classe: "bg-gray-200 text-gray-600" },
};

export const seloEnvio = (status) =>
  ESTADOS_ENVIO[status] ?? { rotulo: status ?? "—", classe: "bg-gray-100 text-gray-700" };

/** Estados em que o detalhe faz polling (contadores ao vivo). */
export const ESTADOS_AO_VIVO = new Set(["agendado", "enviando"]);

/** Estados em que o envio ainda pode ser cancelado. */
export const ESTADOS_CANCELAVEIS = new Set(["agendado", "enviando", "pausado_cota", "suspenso"]);

/** Estados de um destinatário (filtro do detalhe). */
export const ESTADOS_DESTINATARIO = [
  { valor: "", rotulo: "Todos" },
  { valor: "pendente", rotulo: "Pendentes" },
  { valor: "enviado", rotulo: "Enviados" },
  { valor: "falhou", rotulo: "Falharam" },
  { valor: "cancelado", rotulo: "Cancelados" },
  { valor: "ignorado_optout", rotulo: "Saíram da lista" },
  { valor: "ignorado_anonimizado", rotulo: "Dados removidos" },
];

export const rotuloDestinatario = (status) =>
  ({
    pendente: "Pendente",
    enviado: "Enviado",
    falhou: "Falhou",
    cancelado: "Cancelado",
    ignorado_optout: "Saiu da lista",
    ignorado_anonimizado: "Dados removidos",
  })[status] ?? status;

/** Estados de membro aceitos no critério de uma lista dinâmica. */
export const ESTADOS_MEMBRO = [
  { valor: "pendente", rotulo: "Pendente" },
  { valor: "parcial", rotulo: "Parcial" },
  { valor: "confirmado", rotulo: "Confirmado" },
  { valor: "nao_exigida", rotulo: "Confirmação não exigida" },
];

export const LIMITES_TEXTO = { assunto: 200, corpo: 20000 };

/**
 * Mensagem em PT-BR para o `motivo` de um 409 (disparo/teste).
 * @param {{motivo?: string, saldo?: number, teto?: number}|null} data
 */
export function mensagemMotivo(data) {
  const motivo = data?.motivo;
  switch (motivo) {
    case "status":
      return "Este envio não está mais em rascunho. Recarregue a página.";
    case "smtp_indisponivel":
      return "O e-mail da plataforma não está configurado agora. Tente mais tarde.";
    case "envio_desligado":
      return "O envio de e-mails está desligado pela administração da plataforma.";
    case "escola_suspensa":
      return "Os envios desta escola estão suspensos. Fale com a administração da plataforma.";
    case "alvo_inexistente":
      return "A lista escolhida não existe mais. Escolha outra lista.";
    case "sem_destinatarios":
      return "Ninguém nesta lista tem e-mail para receber o envio.";
    case "acima_do_teto":
      return data?.teto != null
        ? `O envio passa do máximo de ${data.teto} destinatários por envio.`
        : "O envio passa do máximo de destinatários por envio.";
    case "cota_insuficiente":
      return data?.saldo != null
        ? `A cota de hoje não basta: restam ${data.saldo} e-mail(s). Agende para outro dia.`
        : "A cota de hoje não basta. Agende para outro dia.";
    case "sem_email_gestor":
      return "Sua conta de gestor não tem e-mail cadastrado para receber o teste.";
    default:
      return null;
  }
}

/**
 * Mensagem para um erro das ações de envio (409 por motivo, 429, 502, 400).
 * Devolve null para 401 (quem chama volta ao login).
 */
export function mensagemErroEnvio(err, padrao = "Não foi possível concluir a ação.") {
  if (!(err instanceof ApiError)) return padrao;
  if (err.status === 401) return null;
  if (err.status === 409) return mensagemMotivo(err.data) ?? err.message ?? padrao;
  if (err.status === 429) return "Limite de testes deste envio atingido (5). Envie o e-mail de verdade ou crie outro rascunho.";
  if (err.status === 502) return "O servidor de e-mail recusou a mensagem. Tente de novo em instantes.";
  return err.message || padrao;
}

/** "YYYY-MM-DDTHH:mm" (input datetime-local, hora local) → ISO UTC com Z. */
export function localParaIsoUtc(valor) {
  if (!valor) return null;
  const d = new Date(valor);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function formatarDataHora(iso) {
  return iso ? new Date(iso).toLocaleString("pt-BR") : "—";
}
