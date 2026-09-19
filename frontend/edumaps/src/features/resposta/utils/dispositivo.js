// src/features/resposta/utils/dispositivo.js
//
// Identificador anônimo do dispositivo do respondente (link público).
// Fase 2 decidida com o usuário: bloqueio "leve" por aparelho — um UUID v4
// gerado uma vez no navegador (localStorage) e enviado a cada resposta.
// Sem PII: não chega ao backend nenhum dado identificável do usuário.
import { uuid } from "@/shared/utils/uuid.js";

const STORAGE_KEY = "edumaps_dispositivo_id";

export function getDispositivoId() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && /^[0-9a-fA-F-]{32,36}$/.test(stored)) return stored;
    const fresh = uuid();
    localStorage.setItem(STORAGE_KEY, fresh);
    return fresh;
  } catch {
    return uuid();
  }
}